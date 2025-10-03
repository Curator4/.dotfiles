alias copy='wl-copy'
alias paste='wl-paste'
alias dots='cd ~/.dotfiles'
alias ls='eza -l --icons --color=auto --group-directories-first'
alias ll='eza -l --icons --color=auto --group-directories-first'
alias la='eza -la --icons --color=auto --group-directories-first'
alias lt='eza -T --icons --color=auto --group-directories-first'
alias y='yazi'
alias themis='~/bin/journal-node'

# Paru wrapper to change message
paru() {
  command paru "$@" | sed 's/there is nothing to do/there is nothing we can do/g'
}

eval "$(starship init zsh)"
