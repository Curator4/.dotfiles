alias copy='wl-copy'
alias paste='wl-paste'
alias dots='cd ~/.dotfiles'
alias home='cd ~/'
alias hypr='cd ~/.dotfiles/hypr/.config/hypr/'
alias ls='eza -l --icons --color=auto --group-directories-first'
alias ll='eza -l --icons --color=auto --group-directories-first'
alias la='eza -la --icons --color=auto --group-directories-first'
alias lt='eza -T --icons --color=auto --group-directories-first'
alias y='yazi'
alias gs='git status'
alias themis='~/.bin/themis-entry'
alias gb='gator browse'
alias cdb="cd ~/workspace/bootdev/"
alias cdw="cd ~/workspace/"
alias cdp="cd ~/workspace/pnc/"
alias cdd="cd ~/.dotfiles"
alias cdh="cd ~/"
alias cda="cd ~/workspace/ai/"
alias cdio="cd ~/workspace/ai/io"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias rc='pkill -9 -f "claude-desktop-native" && claude-desktop &'

# Paru wrapper to change message
paru() {
  command paru "$@" | sed 's/there is nothing to do/there is nothing we can do/g'
}

# functions
cover () {
    local t=$(mktemp)
    go test $COVERFLAGS -coverprofile=$t $@ \
        && go tool cover -func=$t \
        && unlink $t
}

eval "$(starship init zsh)"

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"


# path
export PATH="$HOME/.bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"
export EDITOR="nvim"

# Auto-start gator RSS aggregator in background (scrapes feeds every 1m)
# To disable: comment out or remove this line
# To stop running instance: pkill -f "gator agg"
if ! pgrep -f "gator agg" > /dev/null; then
  nohup gator agg 1m > /dev/null 2>&1 &
fi

alias claude="/home/curator/.claude/local/claude"


# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/curator/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/home/curator/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/curator/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/curator/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

# Turso
export PATH="$PATH:/home/curator/.turso"
