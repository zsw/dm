#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

usage() {

    cat << EOF

usage: $0 message

This script will display a message using OSD. Useful for testing.

OPTIONS:

   -h      Print this help message.

EXAMPLE:

    $0 "This is a message."
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

tmpdir=$(tmp_dir)
pipe_dir="${tmpdir}/pipes"
osd_pipe="$pipe_dir/osd"

echo "$*" > $osd_pipe
