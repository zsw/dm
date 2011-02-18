#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

script=${0##*/}
_u() {

    cat << EOF
usage: $0 [mod_id]

Print a message suitable for git commit.

OPTIONS:

    -h      Print this help message.

NOTES:

    If a mod_id is not provided, the mod used is the current one,
    ie. one indicated in \$DM_USERS/current_mod
EOF
}

while getopts "h" options; do
  case $options in

    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

mod_id=$1
if [[ ! $mod_id ]]; then
    mod_id=$(< $DM_USERS/current_mod)
fi

echo "$mod_id" | $DM_BIN/format_mod.sh "Mod %i - %d"
