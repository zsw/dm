#!/bin/bash

__loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh

#
# attributes.sh
#
# Library of functions related to mod attributes and attribute files.
#
# Attributes include description, hold, notes and who.
#

#
# __attr_file_name
#
# Sent: mod id ( eg 12345)
#       attr   ( eg 'description', 'who', 'hold' )
# Return: nothing (echo's attribute file name including path to stdout)
# Purpose:
#
#   Determine the attribute file name from the mod id.
#
# Usage:
#   mod=12345
#   file_name=$(__attr_file $mod 'hold')
#
# Note:
#   The routine does not attempt to determine if the file exists or not.
#   Use __attr_file for that.
#
__attr_file_name() {
    local mod attr dir

    mod=$1
    attr=$2

    dir=$(__mod_dir "$mod")

    [[ ! $dir ]] && return

    echo "$dir/$attr"
}


#
# __attr_file
#
# Sent: mod id ( eg 12345)
#       attr   ( eg 'description', 'who', 'hold' )
# Return: nothing (echo's attribute file name including path to stdout)
#
# Purpose:
#   Determine the attribute file from the mod id. If the file exists the
#   name of the file is printed to stdout. If the file does not exist,
#   nothing is printed.
#
# Usage:
#   mod=12345
#   file_name=$(__attr_file $mod 'hold')
#
__attr_file() {
    local mod attr file_name

    mod=$1
    attr=$2

    file_name=$(__attr_file_name "$mod" "$attr")

    [[ ! $file_name ]] && return
    [[ ! -e $file_name ]] && return

    echo "$file_name"
}


#
# attribute
#
# Sent: mod id ( eg 12345)
#       attr   ( attribute name eg 'description', 'who', 'hold' )
# Return: nothing (echo's attribute value to stdout)
#
# Purpose:
#   Determine the attribute from the mod id. The attribute is the
#   contents of the attribute file.
#
# Usage:
#   mod=12345
#   who=$(__attribute $mod 'who')
#
# Notes:
#   Nothing is echo'd if the attribute file does not exist.
#
__attribute() {
    local mod attr file

    mod=$1
    attr=$2

    file=$(__attr_file "$mod" "$attr")

    [[ ! $file ]] && return

    cat "$file"
}


#
# __has_conflict_markers
#
# Sent: file_name (Eg /path/to/file)
# Return: 0 = has, 1 = does not have, conflict markers
# Purpose:
#
#   Determine if the file has conflict markers.
#
__has_conflict_markers() {
    local file

    file=$1

    [[ ! -e $file ]] && return 1
    grep -qE '^(<<<<<<<|=======|>>>>>>>)$' "$file"
}


#
# mod_dir
#
# Sent: mod id ( eg 12345)
# Return: nothing (echo's directory path to stdout)
#
# Purpose:
#   Determine the directory of the mod from the mod id.
#
# Usage:
#   mod=12345
#   dir=$(__mod_dir $mod)
#
__mod_dir() {
    local mod=$1

    [[ ! $mod ]] && return 1

    if [[ -d $DM_MODS/$mod ]]; then
        echo "$DM_MODS/$mod"
    elif [[ -d $DM_ARCHIVE/$mod ]]; then
        echo "$DM_ARCHIVE/$mod"
    else
        return 1
    fi
}

#
# __original_who_id
#
# Sent: mod_id  - id of mod
# Return: person_id
#
# Purpose:
#   Return the person_id of the original owner of a mod.
#
__original_who_id() {
    local initials mod_id person_id

    mod_id=$1
    [[ ! $mod_id ]] && return 1

    # Determine the person_id associated with the mod by looking up in
    # the range of ids in the ids table.

    # Command explanation
    # Line 1: Filter lines beginning with digit, ie screen out comments and
    #         header lines
    # Line 2: If the mod id is within the range...
    # Line 3: ... print the third column, ie the person id
    # Line 4: Exit immediately to restrict to one result of output.
    # Line 6: Filter ids file.
    # Line 7: Completed id ranges are indicated with an x prefix on the
    #         person id. Remove the x.
    person_id=$(awk -F',' -v mod="$mod_id" '/^[0-9]/ {
            if (mod >= $1 && mod <= $2) {
                print $3;
                exit;
            }
        }' "$DM_IDS" | tr -d 'x')

    [[ ! $person_id ]] && return 1

    echo "$person_id"
}

# This function indicates this file has been sourced.
__loaded_attributes() {
    return 0
}

# Export all functions to any script sourcing this library file.
while read -r function; do
    export -f "${function%%(*}"         # strip '()'
done < <(awk '/^__*()/ {print $1}' "$DM_ROOT/lib/attributes.sh")
