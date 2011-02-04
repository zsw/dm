#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }


usage() {

    cat << EOF

usage: $0 subdir1[:subdir2:subdir3...] [grep options] keyword

This script simplifies greps on multiple dm subdirectories.

OPTIONS:

   -h      Print this help message.

EXAMPLES:

    # Search mods
    $ $0 mods keywords

    # Search mods and archive
    $ $0 mods:archive keywords

    # Search code
    $ $0 test:lib:bin keywords

    # Search all files
    $ $0 '' keywords

    # Search case insensitive
    $ $0 test:lib:bin -i keywords

NOTES:
    At least one subdirectory is required. At least one keyword is
    required.

    Any options directly after the script name are interpreted as
    options to this script. Any options after the subdirectories list
    are interpreted as options to grep.

    Keywords do not need to be quoted on the command line but will be
    passed to grep in quotes.

    Subdirectories are searched in order.

    Suggested aliases:
    alias grm="~/dm/bin/grep_dm.sh archive:mods"
    alias grc="~/dm/bin/grep_dm.sh test:lib:bin"
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

if [[ "$#" -lt "2" ]]; then
    exit
fi
dirs=$1
shift

grep_opts=
keywords=

while [[ ! "$#" -eq "0" ]]; do
    case $1 in
        -*) grep_opts="$grep_opts $1";;
         *) keywords="$@"
            break;;
    esac
    shift
done

for i in ${dirs//:/ }; do
    grep -sr $grep_opts "$keywords" $HOME/dm/$i
done

