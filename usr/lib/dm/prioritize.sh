#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

script=${0##*/}
_u() { cat << EOF
usage: $script [ <tree> <tree> ]

This script creates a todo list from dependency trees.
    -h  Print this help message.

EXAMPLES:
    $script jimk/reminders main

NOTES:
    Use tree names relative to the $DM_ROOT/trees directory.

    The order of the trees is important. Mods from the first tree are
    prioritized first, then mods from the second tree, etc.

    If no trees are provided, a list of trees from the local file,
    $DM_USERS/current_trees, is used.
EOF
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

    __mi "Current branch is $current_branch, not master.
        Switching to master..."

    git checkout -q master ||
        __me "git checkout master failed.
            Refusing to prioritize in case data is corrupted.
            Run 'git checkout master' at prompt and review messages"
fi

trees="${args[@]}"

[[ ! $trees ]] && trees=$(< "$DM_USERS/current_trees")

# The call to tree.sh will convert tree names to tree files preserving the
# order of the trees.
tree_files=$("$DM_BIN/tree.sh" "$trees" | tr "\n" " ")

[[ ! $tree_files ]] && __me 'No tree files to prioritize.'

cat $tree_files | "$DM_BIN/dependency_schema.pl" --available "$DM_ROOT" | "$DM_BIN/format_mod.sh" "%i %w %t %d" > "$DM_USERS/todo"

cd "$DM_ROOT"
git add -A .
git commit --dry-run >/dev/null &&
    git commit -q -a -m "Re-prioritize" &&
    { git remote | grep -q public; } &&
    git push -q public &

exit 0
