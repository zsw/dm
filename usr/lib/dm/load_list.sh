#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }


usage() {

    cat << EOF

usage: $0

This script creates the list.txt file.

OPTIONS:

   -h      Print this help message.

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

find $DM_MODS $DM_ARCHIVE | $DM_BIN/filter_mod.pl | $DM_BIN/format_mod.sh | sort > $DM_ROOT/list.txt
