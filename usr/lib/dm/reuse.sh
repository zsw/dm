#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }


usage() {

    cat << EOF

usage: $0

This script flags a mod for reuse and then displays a todo list.

OPTIONS:

   -h      Print this help message.

NOTES:

    Positional parameters are passed on to reuse_mod.sh. See that script
    for more details.
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

# Default to current mod if not provided
[[ "$#" -eq "0" ]] && set -- $(cat $HOME/.dm/mod)

reply=
while :
do
    read -p "Reuse mod(s) $@? (Y/n): " reply

    [[ -z "$reply" ]] && reply=y
    reply=$(echo $reply | tr "[:upper:]" "[:lower:]")

    [[ "$reply" == "y" ]] || [[ "$reply" == "n" ]] && break
done

[[ "$reply" == "n" ]] && exit 0

$DM_BIN/reuse_mod.sh "$@"
