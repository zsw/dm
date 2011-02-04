_dm_pull()
{
    local cur prev git_dir i
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    git_dir=
    for i in $(seq 1 ${#COMP_WORDS[@]} ); do
        if [[ "${COMP_WORDS[$i]}" == "-g" ]]; then
            git_dir=${COMP_WORDS[ $(( $i + 1)) ]}
        fi
    done

    if [[ -z "$git_dir" && -e ".git/config" ]]; then
        git_dir=$(pwd)
    fi

    if [[ ${prev} == '-g' ]] ; then
        local paths=$(/usr/bin/locate .git/config | sort | sed -e "s@/\.git/config\$@@")
        COMPREPLY=( $(compgen -W "${paths}" -- ${cur}) )
        return 0
    fi

    if [[ -n "$git_dir" ]]; then
        local remotes=$(cd $git_dir; git remote show 2> /dev/null)
        COMPREPLY=( $(compgen -W "${remotes}" -- ${cur}) )
        return 0
    fi

}
complete -F _dm_pull pull.sh
