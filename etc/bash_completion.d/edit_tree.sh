_dm_et()
{
    local cur prev trees
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    trees=$(find $DM_ROOT/trees $DM_ROOT/trees/$USERNAME -maxdepth 1 -type f -exec basename '{}' \; | sort -u)
    COMPREPLY=( $(compgen -W "${trees}" -- ${cur}) )
    return 0

}

complete -F _dm_et edit_tree.sh
complete -F _dm_et et
