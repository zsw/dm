_dm_um()
{
    local cur prev by_opts action_opts trees usernames
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ ${prev} == 'at' ]] ; then
        return 0
    fi

    if [[ ${prev} == 'by' ]] ; then
        by_opts="email jabber pager"
        COMPREPLY=( $(compgen -W "${by_opts}" -- ${cur}) )
        return 0
    fi

    if [[ ${prev} == 'in' ]] ; then
        trees=$(find $DM_ROOT/trees $DM_ROOT/trees/$USERNAME -maxdepth 1 -type f -exec basename '{}' \; | sort -u)
        COMPREPLY=( $(compgen -W "${trees}" -- ${cur}) )
        return 0
    fi

    if [[ ${prev} == 'to' ]] ; then
        usernames=$(awk -F, 'NR>1 {print $2 "\n" $3}' $DM_ROOT/users/people)
        COMPREPLY=( $(compgen -W "${usernames}" -- ${cur}) )
        return 0
    fi

    action_opts="at by in to"
    COMPREPLY=( $(compgen -W "${action_opts}" -- ${cur}) )
    return 0

}

complete -F _dm_um um.sh
complete -F _dm_um um
