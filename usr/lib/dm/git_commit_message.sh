#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

usage() {

    cat << EOF
usage: $0 [mod_id]

Print a message suitable for git commit.

OPTIONS:

    -h      Print this help message.

NOTES:

    If a mod_id is not provided, the mod used is the current one,
    ie. one indicated in \$HOME/.dm/mod
EOF
}

while getopts "h" options; do
  case $options in

    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

mod_id=$1
if [[ -z $mod_id ]]; then
    mod_id=$(cat $HOME/.dm/mod)
fi

echo "$mod_id" | $DM_BIN/format_mod.sh "Mod %i - %d"
