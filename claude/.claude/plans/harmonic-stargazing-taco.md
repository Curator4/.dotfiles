# Implementation Plan: Conversation Lifecycle Tracking & AI-Driven Actions

## Overview

Add conversation lifecycle tracking and AI-driven actions (reactions) to the Io assistant, keeping the unary gRPC pattern.

**Key Features:**
1. Track when conversations start/end - notify client in responses
2. AI can dynamically trigger reactions using OpenAI tool calling
3. `/clear` command to explicitly end conversations
4. Everything stays in request-response cycle (no streaming)

## Architecture

**Current Flow:**
```
User → Discord → SendMessage gRPC → Backend → AI → Response
                                         ↓
                              Track conversation lifecycle
```

**New Flow:**
```
User → Discord → SendMessage gRPC → Backend → AI (with tools) → Response + Actions + Lifecycle
                                         ↓                              ↓
                              Track conversation lifecycle    Discord executes actions
```

## Critical Files to Modify

1. **`/home/curator/workspace/ai/io/proto/io.proto`** - Add Action, ConversationLifecycle messages; update responses
2. **`/home/curator/workspace/ai/io/backend/internal/core/conversation.go`** - Track conversation creation
3. **`/home/curator/workspace/ai/io/backend/internal/core/core.go`** - Return lifecycle info in handlers
4. **`/home/curator/workspace/ai/io/backend/internal/llm/openai.go`** - Add tool calling for actions
5. **`/home/curator/workspace/ai/io/backend/internal/domain/models.go`** - Add Action and Lifecycle types
6. **`/home/curator/workspace/ai/io/backend/internal/grpc/server.go`** - Update RPC handlers, add ClearConversation
7. **`/home/curator/workspace/ai/io/discord/src/handlers/message.ts`** - Handle lifecycle UI, execute actions, detect commands
8. **`/home/curator/workspace/ai/io/discord/src/grpc/client.ts`** - Add clearConversation method

## Implementation Phases

### Phase 1: Proto Changes (Foundation)

**File: `proto/io.proto`**

Add after MessageContent (line ~27):
```protobuf
// Action types that the AI can trigger
message Action {
  oneof action_type {
    ReactionAction reaction = 1;
  }
}

message ReactionAction {
  string emoji = 1;
}

// Conversation lifecycle info
message ConversationLifecycle {
  bool is_new_conversation = 1;
  string conversation_id = 2;
  string conversation_name = 3;
  google.protobuf.Timestamp started_at = 4;
}
```

Update responses (lines 75-86):
```protobuf
message SendMessageResponse {
  MessageContent content = 1;
  repeated Action actions = 2;
  ConversationLifecycle lifecycle = 3;
}

message StoreMessageResponse {
  bool success = 1;
  ConversationLifecycle lifecycle = 2;
}
```

Add new RPC (after line 155):
```protobuf
message ClearConversationRequest {
  string user_id = 1;
}

message ClearConversationResponse {
  bool success = 1;
}

service IOService {
  // ... existing RPCs ...
  rpc ClearConversation(ClearConversationRequest) returns (ClearConversationResponse);
}
```

**Action: Regenerate proto code**
```bash
cd /home/curator/workspace/ai/io
# Run whatever command regenerates protos (likely `make proto` or similar)
```

### Phase 2: Backend Domain Models

**File: `backend/internal/domain/models.go`**

Add after existing types (~line 93):
```go
// Action types for AI-driven behaviors
type Action struct {
	Type     ActionType
	Reaction *ReactionAction
}

type ActionType string

const (
	ActionTypeReaction ActionType = "reaction"
)

type ReactionAction struct {
	Emoji string
}

// ConversationLifecycle tracks conversation state changes
type ConversationLifecycle struct {
	IsNewConversation bool
	ConversationID    uuid.UUID
	ConversationName  string
	StartedAt         time.Time
}

// LLMResponse encapsulates both content and actions from the LLM
type LLMResponse struct {
	Content MessageContent
	Actions []Action
}
```

**File: `backend/internal/domain/to_pb.go`**

Add converters:
```go
func ActionToPb(a Action) *pb.Action {
	action := &pb.Action{}
	if a.Type == ActionTypeReaction && a.Reaction != nil {
		action.ActionType = &pb.Action_Reaction{
			Reaction: &pb.ReactionAction{
				Emoji: a.Reaction.Emoji,
			},
		}
	}
	return action
}

func ConversationLifecycleToPb(lc ConversationLifecycle) *pb.ConversationLifecycle {
	return &pb.ConversationLifecycle{
		IsNewConversation: lc.IsNewConversation,
		ConversationId:    lc.ConversationID.String(),
		ConversationName:  lc.ConversationName,
		StartedAt:         timestamppb.New(lc.StartedAt),
	}
}
```

### Phase 3: Conversation Lifecycle Tracking

**File: `backend/internal/core/conversation.go`**

Update `getOrCreateActiveConversation` (~line 42) to return `isNew` boolean:
```go
func (c *Core) getOrCreateActiveConversation(ctx context.Context) (conv *domain.Conversation, isNew bool, err error) {
	c.mu.RLock()
	activeConv := c.session.ActiveConversation
	lastActivity := c.session.LastActivity
	c.mu.RUnlock()

	// check if there is active conversation (checks < 30 min)
	if activeConv != nil && time.Since(lastActivity) < 30*time.Minute {
		return activeConv, false, nil
	}

	// create new conversation
	conversationName := time.Now().Format("Jan 2, 2006 15:04")
	newConv, err := c.createConversation(ctx, conversationName)
	if err != nil {
		return nil, false, err
	}

	// set as active
	c.mu.Lock()
	c.session.ActiveConversation = &newConv
	c.mu.Unlock()

	// update last_used_at in db
	if err := c.db.UpdateConversationLastUsed(ctx, newConv.ID); err != nil {
		return nil, false, fmt.Errorf("failed to updated conversation last used: %w", err)
	}

	return &newConv, true, nil
}
```

Add new method:
```go
func (c *Core) clearActiveConversation() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.session.ActiveConversation = nil
	c.session.LastActivity = time.Time{}
}
```

**File: `backend/internal/core/core.go`**

Update `prepareAndStoreUserMessage` (~line 37) to return lifecycle:
```go
func (c *Core) prepareAndStoreUserMessage(
	ctx context.Context,
	content domain.MessageContent,
	username string,
) (user domain.User, lifecycle domain.ConversationLifecycle, err error) {
	// 1. get/create user
	user, err = c.getOrCreateUser(ctx, username)
	if err != nil {
		err = fmt.Errorf("failed to get or create user: %w", err)
		return
	}

	// 2. get/create conversation and track if new
	conv, isNew, err := c.getOrCreateActiveConversation(ctx)
	if err != nil {
		err = fmt.Errorf("failed to get or create active conversation: %w", err)
		return
	}

	// 3. build lifecycle info
	lifecycle = domain.ConversationLifecycle{
		IsNewConversation: isNew,
		ConversationID:    conv.ID,
		ConversationName:  conv.Name,
		StartedAt:         conv.CreatedAt,
	}

	// 4. add user as conversation participant
	if err = c.addParticipantIfNeeded(ctx, conv, user); err != nil {
		err = fmt.Errorf("failed to add participant: %w", err)
		return
	}

	// 5. store message in db
	_, err = c.storeMessage(ctx, conv.ID, &user, domain.RoleUser, content)
	if err != nil {
		err = fmt.Errorf("failed to store user message: %w", err)
		return
	}

	return
}
```

Update `HandleStoreMessage` (~line 147):
```go
func (c *Core) HandleStoreMessage(
	ctx context.Context,
	content domain.MessageContent,
	username string,
) (lifecycle domain.ConversationLifecycle, err error) {
	_, lifecycle, err = c.prepareAndStoreUserMessage(ctx, content, username)
	if err != nil {
		return
	}

	c.mu.Lock()
	c.session.LastActivity = time.Now()
	c.mu.Unlock()

	return
}
```

Add new handler:
```go
func (c *Core) HandleClearConversation(
	ctx context.Context,
	username string,
) error {
	_, err := c.getOrCreateUser(ctx, username)
	if err != nil {
		return fmt.Errorf("failed to get user: %w", err)
	}

	c.clearActiveConversation()
	log.Printf("Cleared active conversation for user: %s", username)
	return nil
}
```

### Phase 4: AI Actions - OpenAI Tool Calling

**File: `backend/internal/llm/provider.go`**

Update interface (~line 9):
```go
type Provider interface {
	SendMessage(ctx context.Context, messages []domain.Message, config domain.AIConfig) (domain.LLMResponse, error)
}
```

**File: `backend/internal/llm/openai.go`**

Update `SendMessage` (~line 34) to add tools and extract actions:
```go
func (p OpenAIProvider) SendMessage(ctx context.Context, messages []domain.Message, config domain.AIConfig) (domain.LLMResponse, error) {
	model, ok := supportedModels[config.Model.Name]
	if !ok {
		return domain.LLMResponse{}, fmt.Errorf("unknown or unsupported model: %s", config.Model.Name)
	}

	input := responses.ResponseNewParamsInputUnion{
		OfInputItemList: messagesToOpenAIInput(messages),
	}

	params := responses.ResponseNewParams{
		Model:        model,
		Instructions: openai.String(config.SystemPrompt),
		Input:        input,
		Tools:        defineTools(),
		Reasoning: openai.ReasoningParam{
			Effort: openai.ReasoningEffortLow,
		},
	}

	resp, err := p.client.Responses.New(ctx, params)
	if err != nil {
		return domain.LLMResponse{}, fmt.Errorf("openai api error: %w", err)
	}

	actions := extractActionsFromResponse(resp)

	return domain.LLMResponse{
		Content: domain.MessageContent{
			Text: resp.OutputText(),
		},
		Actions: actions,
	}, nil
}
```

Add helper functions:
```go
func defineTools() responses.ResponseNewParamsToolsUnion {
	reactionTool := responses.ResponseNewParamsToolsFunctionToolDefinitionParam{
		Type: "function",
		Function: responses.ResponseFunctionToolDefinitionParam{
			Name:        openai.String("add_reaction"),
			Description: openai.String("Add an emoji reaction to the current message. Use this to express emotion, agreement, or emphasis."),
			Parameters: openai.F(map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"emoji": map[string]interface{}{
						"type":        "string",
						"description": "The emoji to react with (e.g., '👍', '❤️', '🎉', '🤔')",
					},
				},
				"required": []string{"emoji"},
			}),
		},
	}

	return responses.ResponseNewParamsToolsUnion{
		OfFunctionToolDefinitionArray: []responses.ResponseNewParamsToolsFunctionToolDefinitionParam{
			reactionTool,
		},
	}
}

func extractActionsFromResponse(resp *responses.Response) []domain.Action {
	actions := make([]domain.Action, 0)

	if resp.Output == nil {
		return actions
	}

	for _, item := range resp.Output {
		if item.Type == "function_call" && item.Name != nil && *item.Name == "add_reaction" {
			if args, ok := item.Arguments.(map[string]interface{}); ok {
				if emoji, ok := args["emoji"].(string); ok {
					actions = append(actions, domain.Action{
						Type: domain.ActionTypeReaction,
						Reaction: &domain.ReactionAction{
							Emoji: emoji,
						},
					})
				}
			}
		}
	}

	return actions
}
```

Update `HandleSendMessage` in `core.go` (~line 72):
```go
func (c *Core) HandleSendMessage(
	ctx context.Context,
	content domain.MessageContent,
	username string,
) (llmResponse domain.LLMResponse, lifecycle domain.ConversationLifecycle, err error) {
	start := time.Now()
	log.Printf("[TIMING] HandleSendMessage started for user: %s", username)

	// 1-5. prepare and store user message, get lifecycle
	stepStart := time.Now()
	_, lifecycle, err = c.prepareAndStoreUserMessage(ctx, content, username)
	if err != nil {
		return
	}
	log.Printf("[TIMING] prepareAndStoreUserMessage: %v", time.Since(stepStart))

	// 6. get conversation history
	stepStart = time.Now()
	history, err := c.getConversationHistory(ctx, lifecycle.ConversationID)
	if err != nil {
		err = fmt.Errorf("failed to get conversation history: %w", err)
		return
	}
	log.Printf("[TIMING] getConversationHistory: %v", time.Since(stepStart))

	// 7. get active ai config
	stepStart = time.Now()
	config, err := c.getActiveConfig(ctx)
	if err != nil {
		err = fmt.Errorf("failed to get active config: %w", err)
		return
	}
	log.Printf("[TIMING] getActiveConfig: %v", time.Since(stepStart))

	// 8. get llm provider
	stepStart = time.Now()
	provider, ok := c.llmProviders[config.Model.Provider.Name]
	if !ok {
		err = fmt.Errorf("%w: %s", ErrProviderNotFound, config.Model.Provider.Name)
		return
	}
	log.Printf("[TIMING] get llm provider: %v", time.Since(stepStart))

	// 9. call llm (now returns LLMResponse with content + actions)
	stepStart = time.Now()
	llmResponse, err = provider.SendMessage(ctx, history, *config)
	if err != nil {
		err = fmt.Errorf("%w: %v", ErrLLMUnavailable, err)
		return
	}
	log.Printf("[TIMING] LLM API call: %v", time.Since(stepStart))

	// 10. store assistant message
	stepStart = time.Now()
	_, err = c.storeMessage(ctx,
		lifecycle.ConversationID,
		nil,
		domain.RoleAssistant,
		llmResponse.Content,
	)
	if err != nil {
		err = fmt.Errorf("failed to store assistant message: %w", err)
		return
	}
	log.Printf("[TIMING] store assistant message: %v", time.Since(stepStart))

	// 11. update session
	c.mu.Lock()
	c.session.LastActivity = time.Now()
	c.mu.Unlock()

	log.Printf("[TIMING] HandleSendMessage TOTAL: %v", time.Since(start))
	return
}
```

### Phase 5: gRPC Server Handlers

**File: `backend/internal/grpc/server.go`**

Update `SendMessage` (~line 27):
```go
func (s *Server) SendMessage(ctx context.Context, req *pb.SendMessageRequest) (*pb.SendMessageResponse, error) {
	content := domain.MessageContentFromPb(req.Content)

	llmResponse, lifecycle, err := s.core.HandleSendMessage(ctx, content, req.Username)
	if err != nil {
		log.Printf("SendMessage error for user %s: %v", req.Username, err)
		return nil, toGRPCError(err)
	}

	responseContentPb := domain.MessageContentToPb(llmResponse.Content)

	actionsPb := make([]*pb.Action, len(llmResponse.Actions))
	for i, action := range llmResponse.Actions {
		actionsPb[i] = domain.ActionToPb(action)
	}

	lifecyclePb := domain.ConversationLifecycleToPb(lifecycle)

	return &pb.SendMessageResponse{
		Content:   responseContentPb,
		Actions:   actionsPb,
		Lifecycle: lifecyclePb,
	}, nil
}
```

Update `StoreMessage` (~line 49):
```go
func (s *Server) StoreMessage(ctx context.Context, req *pb.StoreMessageRequest) (*pb.StoreMessageResponse, error) {
	content := domain.MessageContentFromPb(req.Content)

	lifecycle, err := s.core.HandleStoreMessage(ctx, content, req.Username)
	if err != nil {
		log.Printf("StoreMessage error for user %s: %v", req.Username, err)
		return nil, toGRPCError(err)
	}

	lifecyclePb := domain.ConversationLifecycleToPb(lifecycle)

	return &pb.StoreMessageResponse{
		Success:   true,
		Lifecycle: lifecyclePb,
	}, nil
}
```

Add new handler:
```go
func (s *Server) ClearConversation(ctx context.Context, req *pb.ClearConversationRequest) (*pb.ClearConversationResponse, error) {
	err := s.core.HandleClearConversation(ctx, req.UserId)
	if err != nil {
		log.Printf("ClearConversation error for user %s: %v", req.UserId, err)
		return nil, toGRPCError(err)
	}

	return &pb.ClearConversationResponse{
		Success: true,
	}, nil
}
```

### Phase 6: Discord Frontend

**File: `discord/src/grpc/client.ts`**

Add import and method:
```typescript
import {
  // ... existing imports ...
  ClearConversationRequest,
  ClearConversationResponse,
} from './generated/io.js';

// In GrpcClient class:
async clearConversation(request: ClearConversationRequest): Promise<ClearConversationResponse> {
  return new Promise((resolve, reject) => {
    this.client.clearConversation(request, (error, response) => {
      if (error) reject(error);
      else resolve(response);
    });
  });
}
```

**File: `discord/src/handlers/message.ts`**

Add imports:
```typescript
import {
  SendMessageRequest,
  StoreMessageRequest,
  ClearConversationRequest,
  Action,
  ConversationLifecycle,
} from '../grpc/generated/io.js';
```

Add helper functions:
```typescript
const detectCommand = (message: Message): string | null => {
  const text = message.content.trim().toLowerCase();
  if (text === '/clear' || text === 'io clear' || text === '/reset') {
    return 'clear';
  }
  return null;
};

const executeActions = async (message: Message, actions: Action[] | undefined): Promise<void> => {
  if (!actions || actions.length === 0) return;

  for (const action of actions) {
    try {
      if (action.reaction) {
        await message.react(action.reaction.emoji);
      }
    } catch (error) {
      console.error('Failed to execute action:', action, error);
    }
  }
};

const formatLifecycleMessage = (lifecycle: ConversationLifecycle | undefined): string | null => {
  if (!lifecycle || !lifecycle.isNewConversation) {
    return null;
  }
  return `_Starting new conversation: ${lifecycle.conversationName}_`;
};

const clearConversation = async (message: Message, grpcClient: GrpcClient): Promise<void> => {
  const request: ClearConversationRequest = {
    userId: message.author.username,
  };

  await grpcClient.clearConversation(request);
  await message.reply('Conversation cleared. Your next message will start a new conversation.');
};
```

Update `sendMessage`:
```typescript
const sendMessage = async (message: Message, grpcClient: GrpcClient): Promise<void> => {
  if ('sendTyping' in message.channel) {
    await message.channel.sendTyping();
  }

  const request: SendMessageRequest = {
    content: { text: message.content, media: [] },
    username: message.author.username,
  };

  const response = await grpcClient.sendMessage(request);

  const lifecycleMsg = formatLifecycleMessage(response.lifecycle);

  let text = response.content?.text || 'No response';

  if (text.length > 2000) {
    text = text.substring(0, 1997) + '...';
  }

  if (lifecycleMsg) {
    text = lifecycleMsg + '\n\n' + text;
  }

  await message.reply(text);
  await executeActions(message, response.actions);
};
```

Update `storeMessage`:
```typescript
const storeMessage = async (message: Message, grpcClient: GrpcClient): Promise<void> => {
  const request: StoreMessageRequest = {
    content: { text: message.content, media: [] },
    username: message.author.username,
  };

  const response = await grpcClient.storeMessage(request);

  if (response.lifecycle?.isNewConversation) {
    console.log(`New conversation started: ${response.lifecycle.conversationName}`);
  }
};
```

Update `handleMessage`:
```typescript
export const handleMessage = async (message: Message, grpcClient: GrpcClient): Promise<void> => {
  if (message.author.bot) return;

  try {
    const command = detectCommand(message);

    if (command === 'clear') {
      await clearConversation(message, grpcClient);
      return;
    }

    if (warrantsResponse(message)) {
      await sendMessage(message, grpcClient);
    } else {
      await storeMessage(message, grpcClient);
    }
  } catch (error) {
    console.error('error handling message:', error);

    const errorMessage = error instanceof Error ? `Error: ${error.message}` : `Unknown error occurred`;
    try {
      await message.reply(`failed, ${errorMessage}`);
    } catch (replyError) {
      console.error('failed to send error msg to discord:', replyError);
    }
  }
};
```

## Testing Plan

### After Each Phase

1. **Phase 1**: Verify proto code generates without errors
2. **Phase 3**: Test conversation lifecycle tracking manually
3. **Phase 4**: Test AI tool calling with prompts that should trigger reactions
4. **Phase 6**: Test full integration: /clear command, lifecycle messages, reactions

### Test Scenarios

1. Send message → see "Starting new conversation: [timestamp]"
2. Continue conversation → no lifecycle message
3. Type `/clear` → see confirmation, next message starts new conversation
4. Send message that should trigger reaction (e.g., "That's amazing!") → AI adds 🎉 reaction
5. Wait 30 minutes → next message starts new conversation

## Notes

- All changes maintain backward compatibility at the database level
- Proto changes are additive (new fields, not removing/changing existing)
- Actions are extensible - future action types can be added easily
- Error handling: If action execution fails, log but continue (don't break response flow)
