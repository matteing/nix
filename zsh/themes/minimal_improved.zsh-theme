LCHAR_WIDTH=%1G
LCHAR='$'

PROMPT='%{$fg[cyan]%}%c %{$fg[white]%}%{$LCHAR$LCHAR_WIDTH%} %{$reset_color%}'

if [ $SHLVL -gt 1 ]; then
  RPROMPT='%F{magenta}(↳ subshell)%{$reset_color%}'
else
  # RPROMPT='$(git_prompt_info)'
  RPROMPT=''
fi

ZSH_THEME_GIT_PROMPT_PREFIX="%{$reset_color%}%{$fg[green]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%}*"
