#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_files 2>/dev/null || source $DM_ROOT/lib/files.sh

script=${0##*/}
_u() { cat << EOF
usage: $script mod_id

This script assembles content of attribute files of a dev mod and prints to
STDOUT.
    -h      Print this help message

EXAMPLE:
    $script 12345 > /tmp/file.txt

NOTES:
    If the mods is in the unsorted tree, a notice is added to the top with sort
    instructions.
EOF
}

_options() {
    args=()

    while [[ $1 ]]; do
        case "$1" in
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} != 1 )) && { _u; exit 1; }
    mod=${args[0]}
}

_options "$@"

mod_dir=$(__mod_dir "$mod")
[[ ! -d $mod_dir ]] && __me "assemble_mod.sh $mod: No such directory"

# Set the sections indexes so sections are ordered properly and
# consistently. Files not explicitly indicated are appended to the end
# of the array. The 'notes' section is not added to the sections array
# until after the for loop to guarantee it will be the last section.
sections=()
unset notes
indx=6          # One more than index of last section hard coded below
shopt -s globstar
for file in "$mod_dir"/** ; do
    if [[ -f $file ]]; then
        file=${file/$mod_dir\//}
        [[ $file == description ]] && sections[0]=$file && continue
        [[ $file == who ]]         && sections[1]=$file && continue
        [[ $file == hold ]]        && sections[2]=$file && continue
        [[ $file == remind ]]      && sections[3]=$file && continue
        [[ $file == specs ]]       && sections[4]=$file && continue
        [[ $file == spec ]]        && sections[5]=$file && continue
        [[ $file == notes ]]       && notes='notes'     && continue
        ((indx += 1))
        sections[$indx]=$file
    fi
done

[[ $notes ]] && sections+=($notes)
shopt -u globstar

for section in ${sections[@]}; do
    echo "--------------------------------------------- $section ---"
    echo
    __is_text "$mod_dir/$section" && cat "$mod_dir/$section"
    echo
done
