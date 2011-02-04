#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_files 2>/dev/null || source $DM_ROOT/lib/files.sh

usage() { cat << EOF

usage: $0 mod_id

This script assembles content of attribute files of a dev mod and prints to
STDOUT

OPTIONS:

    -v      Verbose.

    -h      Print this help message.

EXAMPLE:

    $0 12345 > /tmp/file.txt

NOTES:

    If the mods is in the unsorted tree, a notice is added to the top with sort instructions.
EOF
}


#
# section_index
#
# Sent: section name
# Return: integer section index
# Purpose:
#
#   Return the section index indicating the order of the section for the given
#   section name.
#
function section_index {

    section=$1

    for i in ${!section_order[@]}; do
        if [[ "$section" == "${section_order[$i]}" ]]; then
            echo $i
            break
        fi
    done

    return
}


verbose=

while getopts "hv" options; do
  case $options in

    v ) verbose=1;;
    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

[[ -n $verbose ]] && LOG_LEVEL=debug
[[ -n $verbose ]] && LOG_TO_STDERR=1

declare -a list
declare -a other
declare -a a_notes

# These variables determine the order of the mod sections in the list
# array. Each must have unique values. The names of the variables match
# names of mod directory files. Any filename not matched will be
# appended to the end. The 'notes' section is always the very last file
# appended.


section_order=( \
    description \
    who \
    hold \
    remind \
    spec \
    notes \
);


description=1
who=2
hold=3
remind=4
spec=5

notes=999

if [ $# -ne 1 ]; then

    usage
    exit 1;
fi

mod=$1
mod_dir=$(mod_dir $mod)

if [ ! -e $mod_dir ]; then

    echo "assemble_mod.sh $mod: No such directory $mod_dir." >&2
    exit 1;
fi

count=0

for file in $(find $mod_dir -type f -o -type l | sort); do

    section=$(section_name_from_file "$mod" "$file")

    attachment=$(echo $section | grep -o "^files/")

    index=$(section_index $section )

    if [[ -n $attachment || -z "$index" ]]; then

        other[$count]=$section
        count=$(($count + 1))

    elif [[ "$section" == "notes" ]]; then

        a_notes[0]=$section
    else

        list[$index]=$section
    fi
done

for section in ${list[@]} ${other[@]} ${a_notes[@]}; do

    echo "--------------------------------------------- $section ---"
    echo

    file=$mod_dir/$section

    text=$(is_text $file)

    if [[ -n "$text" ]]; then
        cat $file
    fi

    echo
done

