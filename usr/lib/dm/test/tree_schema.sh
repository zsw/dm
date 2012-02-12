#!/bin/bash

__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1


script="${0##*/}"
_u() { cat << EOF
usage: $script [-t 01|02|...]
short
    -t
    -h  Print this help message

long_description
EOF
}



_options() {
    args=()
    unset var

    while [[ $1 ]]; do
        case "$1" in
    [0-9][0-9]) args+=( "$DM_ROOT/test/trees/${1}tree" ) ;;
            -h) _u; exit 0        ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0        ;;
             *) _u; exit ;;
        esac
        shift
    done

    [[ ${#args[@]} == 0 ]] && args+=( $DM_ROOT/test/trees/*tree )
}

_options "$@"


#for i in ${args[@]}; do
#    echo "$i"
#done
#
#exit

for i in ${args[@]}; do
    n=${i%tree} n=${n##*/}
    __mi "$n $(head -1 $i)"
    d=$(diff -u <(prioritize.sh $i 2>&1) $DM_ROOT/test/trees/${n}output)
    [[ $d ]] && while read -r line; do __mw "$line"; done <<< "$d" && echo
done

exit 0
