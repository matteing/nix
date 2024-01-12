if [ $SHLVL -gt 1 ]; then
  PROMPT='%F{green}(↳ subshell) %{$fg_bold[magenta]%}▲ $(get_pwd) %{$reset_color%}'
else
  PROMPT='%{$fg_bold[magenta]%}▲ $(get_pwd) %{$reset_color%}'
fi

function get_pwd() {
  echo "${PWD/$HOME/~}"
}