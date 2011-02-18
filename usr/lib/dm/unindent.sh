#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 FILE [FILE]...
       echo "lines of text" | $0 -

Unindent a file. Remove leading spaces from all lines in a file.

OPTIONS:
    -i      Unindent in place.
    -n N    Unindent at most N columns.
    -h      Print this help message.

EXAMPLES:
     $ cat /path/to/file
        line 1
            line 2
                line 3
     $ $0 /path/to/file
     $ cat /path/to/file
     line 1
        line 2
            line 3

    # Unindent input from stdin
    cat /path/to/file | $0 -

NOTES:
    With the exception of blank lines, the same number of spaces are
    removed from every line.
EOF
}

#
# unindent
#
# Sent: file - name of file
# Return: nothing
# Purpose:
#
#   Remove the leading spaces from the lines of a file.
#
function unindent {

    local file=$1

    # If the file is empty, nothing to do, return
    wc=$(cat $file | wc -l)
    if [[ "$wc" == "0" ]]; then
        return
    fi

    local removed=0
    while : ; do

        # If there exists one line with no leading spaces, exit loop
        local found=$(cat $file | awk '!/^[ ]+/')
        if [[ "$found" ]]; then
            break
        fi

        # Remove one leading space
        sed -i -e 's/^[ ]//' $file
        let removed++

        # If the max_column is reached, exit loop
        if [[ $removed -ge $max_columns ]]; then
            break
        fi
    done
    return
}


in_place=
max_columns=9999

while getopts "hin:" options; do
  case $options in

    i ) in_place=1;;
    n ) max_columns=$OPTARG;;
    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

if [[ "$#" == "0" ]]; then
    echo "ERROR: File to unindent required." >&2
    _u
    exit 1
fi

# Validate max_columns option. Must be all digits.
count=$(echo "$max_columns" | grep -c '[^0-9]')
if [[ $count != "0" ]]; then
    echo "ERROR: Invalid -n option value, $max_columns. Digits only." >&2
    _u
    exit 1
fi

tmp=$(tmp_file)

while [[ ! "$#" -eq "0" ]]; do
    if [ "$1" == "-" ]; then
        # eg echo "some text" | unindent.sh -
        cat >> $tmp
    else
        cp $1 $tmp
        if [[ "$?" != "0" ]]; then
            exit 1
        fi
    fi
    unindent $tmp
    if [[ $in_place && "$1" != "-" ]]; then
        cp $tmp $1
    else
        cat $tmp
    fi
    shift
done
