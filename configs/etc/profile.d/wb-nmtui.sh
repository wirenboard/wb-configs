# Enable wrapper only for interactive shells; avoid errors in non-interactive /bin/sh
case "$-" in *i*) ;; *) return ;; esac

# Enable only for common interactive shells
[ -n "${BASH_VERSION:-}" ] || [ -n "${ZSH_VERSION:-}" ] || return

# Alias to use Wiren Board's nmtui wrapper
alias nmtui='nmtui-wb'

