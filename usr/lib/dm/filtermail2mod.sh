#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

usage() {

    cat << EOF

usage: $0 /path/to/maildir_file

This script processes a mail file and updates the dm system according.

OPTIONS:

   -h      Print this help message.

EXAMPLE:

    $0 ~/.mail/inbox/cur/1231774030.26974_0.dtjimk:2,S

NOTES:

    The path can be absolute or relative.

    The following processes are done.

    * If the mail file has a X-DM-Mod-Id label, the mod is taken off
    hold.
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

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

file=$1;

if [[ ! -r "$file" ]]; then
    echo "Unable to read file $file" >&2
    exit 1
fi

for mod in $(grep '^X-DM-Mod-Id' $file | awk '{ print $2}')
do
    logger_debug "Mod: $mod"
    $DM_BIN/take_off_hold.sh -f $mod
done
