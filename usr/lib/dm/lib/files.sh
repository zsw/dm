#!/bin/bash

#
# files.sh
#
# Library of functions related to attachment files.
#

_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh

#
# filename_from_section
#
# Sent: mod          - eg 12345
#       section name - eg 'who', 'files/attachment.txt'
# Return: filename - eg '/root/dm/mods/12345/who' '/root/dm/mods/12345/files/attachment.txt'
# Purpose:
#
#   Return the full file name the section should be associated with.
#
function filename_from_section {

    mod=$1
    section=$2

    [[ -z $mod ]] && return
    [[ -z $section ]] && return

    mod_dir=$(mod_dir $mod)

    echo "$mod_dir/$section"

    return
}


#
# is_text
#
# Sent: file
# Return: echo file type if file is text
# Purpose:
#
#   Determine if file is a text file.
#
function is_text {

    file=$1

    [[ -z $file ]] && return

    [[ ! -r $file ]] && return

    logger_debug "file -b \$(readlink -f $file)"


    # Any file with a 'c' in the first column followed by a space or tab in
    # the first 100 lines file interprets as fortran, prints 'FORTRAN
    # program'. Convert that to 'text'.
    text=$(file -b $(readlink -f $file) | sed -e 's/FORTRAN program/text/' | grep -o text)
    logger_debug "File type: $text"

    echo $text
}


#
# section_name
#
# Sent: section name
# Return: section name
# Purpose:
#
#   Return a properly formatted section name.
#
function section_name {

    section=$1

    [[ -z $section ]] && return

    attachment=$(echo $section | grep -o "^files/")

    attr=$(echo $section | grep -v "/")

    if [[ -z "$attachment" && -z "$attr" ]]; then

        # If the section is not a attribute or attachment then it's foo
        # We're going to assume it's an attachment and configure it as so.
        # Prepend the section with files.

        section="files/$section"
    fi

    echo "$section"

    return
}


#
# section_name_from_file
#
# Sent: mod - eg 12345
#       file name - eg '/root/dm/mods/12345/who' '/root/dm/mods/12345/files/attach.txt'
# Return: section name - eg 'who', 'files/attach.txt'
# Purpose:
#
#   Return the section name associated with the given file.
#
function section_name_from_file {

    mod=$1
    file=$2

    [[ -z $mod ]] && return
    [[ -z $file ]] && return

    mod_dir=$(mod_dir $mod)

    found=$(echo $file | grep -o "^$mod_dir")

    [[ -z $found ]] && return

    section=${file/$mod_dir\//}

    echo $section

    return
}


# This function indicates this file has been sourced.
function _loaded_files {
    return 0
}

# Export all functions to any script sourcing this library file.
for function in $(awk '/^function / { print $2}' $DM_ROOT/lib/files.sh); do
    export -f $function
done
