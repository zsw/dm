_dm_mod()
{
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    [[ "$COMP_CWORD" -gt "1" ]] && return 0

    local todo=$($DM_ROOT/bin/todo.sh -u $USERNAME)
    echo ""
    echo "Todo list:"
    echo "$todo"
    echo ""
    echo -n "$BOLD[${USER}@${HOSTNAME} ${PWD##*/}]$COLOUROFF# "
    echo -n ${COMP_WORDS[@]}
    [[ -z $cur ]] && echo -n " "
    local mods=$($DM_ROOT/bin/todo.sh -u $USERNAME | awk '{print $1}')
    COMPREPLY=( $(compgen -W "${mods}" -- ${cur}) )
    return 0
}
complete -F _dm_mod edit_mod.sh
complete -F _dm_mod em
complete -F _dm_mod mairix_mod.sh
complete -F _dm_mod mm
complete -F _dm_mod reuse_mod.sh
complete -F _dm_mod reuse
complete -F _dm_mod set_mod.sh
complete -F _dm_mod sm
