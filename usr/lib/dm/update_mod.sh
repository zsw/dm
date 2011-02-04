#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }


usage() {

    cat << EOF

usage: $0 options

This script is used to do any or all of these tasks for a mod

    * Postpone a mod
    * Set how alerts will be notified
    * Move the mod to a specific dependency tree
    * Assign the mod to a different person

OPTIONS:

    -b METHOD   Remind by jabber|email|pager
    -m ID       Id of mod.
    -p TIME     Postpone time.
    -t FILE     Tree file to move mod to.
    -q          Quiet. Suppress printing messages to stdout.
    -w WHO      Who to assign mod to.

    -h  Print this help message.

EXAMPLES:

    $0 -b "jabber pager"        # Remind by jabber and pager
    $0 -m 11111 -p tomorrow     # Postpone mod 11111 until tomorrow
    $0 -m 22222 -t \$HOME/dm/trees/main  # Move mod 22222 to the main tree
    $0 -m 33333 -w jimk         # Assign mod 33333 to person with username jimk

    # Postpone mod 44444 until Oct 19 at 11am, remind by pager, move mod
    # to main tree, and assign to SB
    $0 -m 44444 -p "2008-10-19 11:00" -b pager -t \$HOME/dm/trees/main -w SB

NOTES:

    If the -m options is not provided, the mod updated is the current one,
    ie. one indicated in \$HOME/.dm/mod

    All arguments for the -b option are passed along to remind_by.sh.
    See that script for option syntax.

    All arguments for the -p option are passed along to postpone.sh. See
    that script for option syntax.

    All arguments for the -t option are passed along to
    mv_mod_to_tree.sh. See that script for option syntax.

    All arguments for the -w option are passed along to assign_mod.sh.
    See that script for option syntax.
EOF
}

mod_id=$(cat $HOME/.dm/mod);
by=
time=
quiet=false
tree=
who=

while getopts "hb:m:p:qt:w:" options; do
  case $options in

    b ) by=$OPTARG;;
    m ) mod_id=$OPTARG;;
    p ) time=$OPTARG;;
    q ) quiet=true;;
    t ) tree=$OPTARG;;
    w ) who=$OPTARG;;
    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

#  Decrements the argument pointer so it points to next argument.
#  $1 now references the first non option item supplied on the command line
#+ if one exists.
shift $(($OPTIND - 1))

if [[ -z $mod_id ]]; then

    echo 'ERROR: Unable to determine mod id.' >&2
    exit 1
fi

if [[ -n "$by" ]]; then
    $quiet || echo "Setting mod $mod_id to remind by $by."
    $DM_BIN/remind_by.sh -m $mod_id $by
fi

if [[ -n "$tree" ]]; then
    $quiet || echo "Moving mod $mod_id to $tree tree."
    # Capture results in a var so they are not echoed to stdout
    res=$($DM_BIN/mv_mod_to_tree.sh $mod_id $tree)
fi

if [[ -n "$time" ]]; then
    $quiet || echo "Postponing mod $mod_id for $time."
    $DM_BIN/postpone.sh -m $mod_id $time
fi

if [[ -n "$who" ]]; then
    $quiet || echo "Assigning mod $mod_id to $who."
    $DM_BIN/assign_mod.sh -m $mod_id $who
fi
