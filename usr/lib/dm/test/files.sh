#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/files.sh functions.
#

source $DM_ROOT/test/test.sh
_loaded_files 2>/dev/null || source $DM_ROOT/lib/files.sh


#
# tst_filename_from_section
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on filename_from_section function.
#
function tst_filename_from_section {

    mod=12345
    mod_dir="$DM_MODS/$mod"
    mkdir -p $mod_dir

    file=$(filename_from_section)
    tst "$file" '' 'no mod - returns nothing'

    file=$(filename_from_section "$mod")
    tst "$file" '' 'no section - returns nothing'

    file=$(filename_from_section  "$mod" '')
    tst "$file" '' 'blank section - returns nothing'

    file=$(filename_from_section "$mod" 'who')
    tst "$file" "$mod_dir/who" 'who section - returns correct path'

    file=$(filename_from_section "$mod" 'files/jimk/test.txt')
    tst "$file" "$mod_dir/files/jimk/test.txt" 'attachment file section - returns correct path'

    file=$(filename_from_section "$mod" 'path/to/file')
    tst "$file" "$mod_dir/path/to/file" 'incorrect attachment section - returns correct path'

    return
}


#
# tst_is_text
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on is_text function.
#
function tst_is_text {

    type=$(is_text)
    tst "$type" '' 'no file - returns nothing'

    type=$(is_text '')
    tst "$type" '' 'blank file - returns nothing'

    type=$(is_text '/fake/file/dot.txt')
    tst "$type" '' 'non-existent file - returns nothing'

    type=$(is_text $0)
    tst "$type" 'text' 'this script - returns text'

    type=$(is_text '/bin/true')
    tst "$type" '' '/bin/true - returns non-text'
}


#
# tst_section_name
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on section_name function.
#
function tst_section_name {


    section=$(section_name)
    tst "$section" '' 'no section - returns nothing'

    section=$(section_name '')
    tst "$section" '' 'blank section - returns nothing'

    section=$(section_name 'who')
    tst "$section" "who" 'who section - returns unchanged'

    section=$(section_name 'files/jimk/test.txt')
    tst "$section" "files/jimk/test.txt" 'attachment file section - returns unchanged'

    section=$(section_name 'path/to/file')
    tst "$section" "files/path/to/file" 'incorrect attachment section - returns correct name'

    return
}


#
# tst_section_name_from_filename
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on section_name_from_filename function.
#
function tst_section_name_from_filename {

    mod=12345
    mod_dir="$DM_MODS/$mod"
    mkdir -p $mod_dir

    section=$(section_name_from_file)
    tst "$section" '' 'no mod - returns nothing'

    section=$(section_name_from_file "$mod")
    tst "$section" '' 'no file - returns nothing'

    section=$(section_name_from_file  "$mod" '')
    tst "$section" '' 'blank file - returns nothing'

    section=$(section_name_from_file "$mod" '/path/to/file')
    tst "$section" '' 'wtf file - returns nothing'

    section=$(section_name_from_file "$mod" "$mod_dir/who")
    tst "$section" 'who' 'who file - returns correct section'

    section=$(section_name_from_file "$mod" "$mod_dir/files/jimk/test.txt")
    tst "$section" "files/jimk/test.txt" 'attachment file - returns correct section'

    return
}


functions=$(cat $0 | grep '^function ' | awk '{ print $2}')

[[ "$1" ]] && functions="$*"

for function in  $functions; do
    if [[ ! $(declare -f $function) ]]; then
        echo "Function not found: $function"
        continue
    fi

    $function
done

