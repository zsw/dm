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

[[ $(id -u -n) != dm_test ]] && __me "Only run this script as user 'dm_test'"

_options "$@"


#for i in ${args[@]}; do
#    echo "$i"
#done
#
#exit

for i in ${args[@]}; do
    # loop through a list of undone mods and run
    #   undone_mod.sh -f mod_id
    #   [ ] 30001 foo
    undone=( $(grep -hrE '^[ ]*\[ \] [[:digit:]]+ ' "$i" |grep -Eo ' [[:digit:]]+ ') )
    for j in ${undone[@]}; do
        [[ -d $DM_MODS/$j ]] && continue
        undone_mod.sh -f "$j"
    done


    # loop through a list of done mods and run
    #   done_mod.sh mod_id
    #   [x] 30004 foo
    dun=( $(grep -ihrE '^[ ]*\[x\] [[:digit:]]+ ' "$i" |grep -Eo ' [[:digit:]]+ ') )
    for k in ${dun[@]}; do
        [[ -d $DM_ARCHIVE/$j ]] && continue
        done_mod.sh "$k"
    done


    n=${i%tree} n=${n##*/}
    __mi "$n $(head -1 $i)"
#    d=$(diff -u <(pri.sh $i 2>&1) $DM_ROOT/test/trees/${n}output)
    d=$(diff -u <(cat $i | "$DM_BIN/dependency_schema.pl" --available "$DM_ROOT" | "$DM_BIN/format_mod.sh" "%i") $DM_ROOT/test/trees/${n}output)
    [[ $d ]] && while read -r line; do __mw "$line"; done <<< "$d" && echo
done

exit 0
