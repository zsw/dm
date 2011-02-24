#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1


script=${0##*/}
_u() {

    cat << EOF

usage: $0 PATTERN

This script searches for pattern in mods.

OPTIONS:

   -f      Options passed to find.*
   -g      Options passed to grep.*

   -h      Print this help message.

   * Double quote multiple options.

EXAMPLES:

    $0 pattern
    $0 -g "-i" pattern              # Search case insensitive, same as grep -i
    $0 -f "-mtime -10" pattern      # Search files modified in last 10 days, same as find -mtime -10

NOTES:

    If the pattern contains no regex symbols, fgrep is used to improve performance.
EOF
}

find_opt=
grep_opt=

while getopts "hf:g:" options; do
  case $options in

    f ) find_opt=$OPTARG
        ;;
    g ) grep_opt=$OPTARG
        ;;
    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

if [[ ! "$1" ]]; then
    _u
    exit 1
fi

#
# fgrep is faster than grep
# Use only if pattern is not a regex.
#
GREP='fgrep'
echo "$1" | grep -q '[^[:alnum:]]' && GREP='grep'


files=$(find ${DM_ROOT}/ $find_opt \( -path "$DM_MODS/*" -o -path "$DM_ARCHIVE/*" \) -exec $GREP -H $grep_opt "$1" '{}' \; | sed -e "s@\($DM_ROOT/\)\(archive\|mods\)/\([0-9]\+\)\(.*\)@\1\2/\3@" | sort | uniq -c | sort -nr | awk '{print $2}')

for file in $files; do
    echo -en "\033[1m"              # Turn bold on
    echo $file | $DM_BIN/format_mod.sh "%i %t %l %d"
    echo -en "\033[0m"              # Turn bold off

    # Display some context
    # sed removes blank lines
    $GREP -srh -C 3 $grep_opt "$1" $file/* | sed '/^$/d' | head -6

    echo ""
done
