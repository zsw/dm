#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

usage() {

    cat << EOF

usage: $0 [ <tree> <tree> ]

This script creates a todo list from dependency trees.

OPTIONS:

    -v  Verbose.

    -h  Print this help message.

EXAMPLES:

    $0 jimk/reminders main

NOTES:

    Use tree names relative to the $DM_ROOT/trees directory.

    The order of the trees is important. Mods from the first tree are
    prioritized first, then mods from the second tree, etc.

    If no trees are provided, a list of trees from the local file,
    $HOME/.dm/trees, is used.
EOF
}

verbose=

while getopts "hv" options; do
  case $options in

    v ) verbose=1;;
    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

[[ -n $verbose ]] && LOG_LEVEL=debug
[[ -n $verbose ]] && LOG_TO_STDERR=1

cd $DM_ROOT

# Double check that we are on the correct branch
current_branch=$(git branch | grep '^\* ' | awk '{print $2}')
if [[ "$current_branch" != "master" ]]; then
    echo "WARNING: Current branch is $current_branch, not master." >&2
    echo "Switching to master..."
    checkout_failed=
    git checkout master || checkout_failed=1
    if [[ -n $checkout_failed ]]; then
        echo "ERROR: git checkout master failed." >&2
        echo "Refusing to prioritize in case data is corrupted." >&2
        echo "Run 'git checkout master' at prompt and review messages" >&2
        exit 1
    fi
fi

logger_debug "Expanding tree file names"
trees="$@"

if [[ -z "$trees" ]]; then
    trees=$(cat $HOME/.dm/trees | tr "\n" " ")
fi

# The call to tree.sh will convert tree names to tree files preserving the order of the trees.

tree_files=$($DM_BIN/tree.sh $trees | tr "\n" " ")

if [[ -z "$tree_files" ]]; then
    echo 'No tree files prioritize.'
    exit 0
fi

logger_debug "Backing up todo file: $DM_TODO."
cp $DM_TODO ${DM_TODO}.bak

logger_debug "Prioritizing mods using dependency tree."
cat $tree_files | $DM_BIN/dependency_schema.pl --available $DM_ROOT | awk -v root=$DM_ROOT '{print root"/mods/"$1}' | $DM_BIN/format_mod.sh "%i %w %t %d" > $DM_TODO

logger_debug "Committing changes if necessary."
cd $DM_ROOT
git add -u && git add .
$DM_BIN/set_alerts.sh
git status -s
git commit --dry-run > /dev/null && git commit -a -m "Re-prioritize" && git push public

exit 0
