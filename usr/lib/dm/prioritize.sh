#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

script=${0##*/}
_u() { cat << EOF
usage: $script [ /path/to/tree /path/to/tree ]

This script creates a todo list from dependency trees.
    -h  Print this help message.

EXAMPLES:
    $script $DM_TREES/reminders $DM_TREES/main

NOTES:
    Use tree names relative to the $DM_ROOT/trees directory.

    The order of the trees is important. Mods from the first tree are
    prioritized first, then mods from the second tree, etc.

    If no trees are provided, a list of trees from the local file,
    $DM_USERS/current_trees, is used.
EOF
}

_end() {
    [[ ! $g ]] && p=$s   ## an undone mod will unset $g, so treat 'end' like a parent

    (( ${#group[@]} == 0 )) && __me "Group missing 'group' header."

    ## Indentation of 'end' must equal indentation of previous group.  Values
    ## are stored in the 'group' array).
    ##
    ## if true remove previous group element from 'group array'
    ## if false then send error message
    (( $s == group[${#group[@]}-1] )) && unset group[${#group[@]}-1] ||
        __me "Indentation is incorrect: group ${group[${#group[@]}-1]} spaces" \
            "Indentation is incorrect: end $s spaces"
}

_plt() {
    ## Previous line tests
    (( $s - $ps >= 8 )) &&
        __me "Indendation of a dependent mod is greater than eight spaces." \
            "$pline" \
            "$line"

    [[ ! $pline ]] && (( $s != 0 )) &&
        __me "The first line of a tree file must not be indented." \
            "$line"

    [[ $pline =~ $r1 ]] && [[ ! $line =~ $r1 ]] && (( $s != $ps )) &&
        __me "Mod must be aligned with group header." \
            "$pline" \
            "$line"

    pline=$line
    ps=$s
}

_options() {
    args=()

    while [[ $1 ]]; do
        case "$1" in
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done
}

_options "$@"


cd "$DM_ROOT"

# Double check that we are on the correct branch
current_branch=$(git branch | awk '/^\* / {print $2}')
if [[ $current_branch != master ]]; then

    __mi "Current branch is $current_branch, not master." \
        "Switching to master..."

    git checkout -q master ||
        __me 'git checkout master failed.' \
            'Refusing to prioritize in case data is corrupted.' \
            'Run 'git checkout master' at prompt and review messages'
fi

trees=${args[@]}

# The call to tree.sh will convert tree names to tree files preserving the
# order of the trees.
[[ ! $trees ]] && trees=$(< "$DM_USERS/current_trees") && trees=$("$DM_BIN/tree.sh" "$trees" | tr "\n" " ")
[[ ! $trees ]] && __me 'No tree files to prioritize.'

p=          ## set to $s if undone mod or end header is a parent
g=          ## boolean var -- for group header
s=0         ## number of indentation spaces for current line
ps=0        ## number of indentation spaces for previous line
group=()    ## number of indentation spaces for group header
parent=()   ## undone, parent mods

r1="^[[:blank:]]*group [[:digit:]]+"
r2="^[[:blank:]]*end$"
r3="^[[:blank:]]*\[x\] [[:digit:]]+"
r4="^[[:blank:]]*\[ \] [[:digit:]]+"

for tree in $trees; do
    unset pline     ## unset previous line so dependent mod at BOF fails check

    while IFS= read -r line; do
        s=${line%%[^ ]*} s=${#s}
        (( $s % 4 != 0 )) && __me "Indentation is incorrect." "$line"
        [[ $g ]] && (( $s < $g )) &&
            __me "Indentation must not be less than group header." "$line"

        _plt    ## Previous line tests

        [[ $p ]] && (( $p >= $s )) && p=
#        echo "$ps $s $p $g $line"       ## debug
        [[ $line =~ $r3 ]] && continue
        [[ $line =~ $r4 && ! $p ]] && g= p=$s && parent+=( "$line" ) && continue
        [[ $line =~ $r4 ]] && continue
        [[ $line =~ $r1 ]] &&         g=$s    && group+=( "$s" )     && continue
        [[ $line =~ $r2 ]] && _end && g=                             && continue
        [[ $line == * ]]   && __mw "No match for line: $line"        && continue

    done < <(grep -hrvP '^[ ]*#|^$' "$tree")  ## exclude comments and blank lines
done

## group array should be empty
(( ${#group[@]} != 0 )) && __me "Group missing 'end' header."

## determind on-hold mods and clean up parent array
parent=( "${parent[@]#*] }" )  parent=( "${parent[@]%% *}" )
readarray -t hold < <(grep -lvP '^#' "$DM_MODS"/*/hold)
hold=( "${hold[@]%/*}" ) hold=( "${hold[@]##*/}" )

for i in "${!hold[@]}"; do
    for j in "${!parent[@]}"; do
        [[ "${hold[$i]}" == "${parent[$j]}" ]] && unset parent[j] && break
    done
done

## print parent mod ids but remove hold-on mods from list
[[ ! ${parent[@]} ]] && __me "No mods to prioritize"

printf "%s\n" "${parent[@]}"
e=$?

( cd "$DM_ROOT"
git add -A .
git commit --dry-run >/dev/null &&
    git commit -a -m "Re-prioritize" >/dev/null &&
    git remote | grep -q public &&
    git push -q public ) 2>&1 |grep -v 'Unpacking objects' &

exit "$e"
