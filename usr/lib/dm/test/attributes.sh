#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/attributes.sh functions.
#

_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

source $DM_ROOT/test/test.sh
_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh

#
# tst_attr_file_name
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on attr_file_name function.
#
function tst_attr_file_name {

    mod=11111
    mod_dir="$DM_MODS/$mod"

    zzz_file_name=$(attr_file_name $mod 'zzz')

    tst "$zzz_file_name" '' 'mod directory does not exist - returns nothing'


    mkdir -p $mod_dir

    zzz_file_name=$(attr_file_name $mod 'zzz')

    tst "$zzz_file_name" "$mod_dir/zzz" 'zzz file name correct'
}


#
# tst_attr_file
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on attr_file function.
#
function tst_attr_file {

    mod=22222
    mod_dir="$DM_MODS/$mod"

    yyy_file=$(attr_file $mod 'yyy')

    tst "$yyy_file" '' 'mod directory does not exist - returns nothing'


    mkdir -p $mod_dir

    yyy_file=$(attr_file $mod 'yyy')

    tst "$yyy_file" '' 'yyy file does not exist - returns nothing'


    touch $mod_dir/yyy

    yyy_file=$(attr_file $mod 'yyy')

    tst "$yyy_file" "$mod_dir/yyy" 'yyy file name correct'
}


#
# tst_attribute
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on attribute function.
#
function tst_attribute {

    mod=33333
    mod_dir="$DM_MODS/$mod"

    xxx=$(attribute $mod 'xxx')

    tst "$xxx" '' 'mod directory does not exist - returns nothing'


    mkdir -p $mod_dir

    xxx=$(attribute $mod 'xxx')

    tst "$xxx" '' 'xxx file does not exist - returns nothing'


    touch $mod_dir/xxx

    xxx=$(attribute $mod 'xxx')

    tst "$xxx" '' 'empty xxx file - returns nothing'


    echo 'aaabbbccc' > $mod_dir/xxx

    xxx=$(attribute $mod 'xxx')

    tst "$xxx" "aaabbbccc" 'attribute returns contents correctly'
}


#
# tst_has_conflict_markers
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on has_conflict_markers function.
#
function tst_has_conflict_markers {

    file=$(tmp_file)

    has_conflict_markers $file
    tst "$?" "1"  'file does not exist, returns false'


    touch $file

    has_conflict_markers $file
    tst "$?" "1"  'empty file, returns false'

    while read line
    do
        line=$(echo $line | sed -e "s/\,\s\+/\,/g")

        saveIFS=$IFS
        IFS=","
        set -- $line
        arr=( $line )
        IFS=$saveIFS

        eval echo ${arr[0]} > $file

        has_conflict_markers $file
        tst "$?" "${arr[1]}" "single line ${arr[2]}"

        echo 'some line of text' > $file
        eval echo ${arr[0]} >> $file
        echo 'another line of text' >> $file

        has_conflict_markers $file
        tst "$?" "${arr[1]}" "multi  line ${arr[2]}"

    done <<EOT
    'a non-marker line', 1, no markers returns false
    '   >>>>>>>',        1, indented marker returns false
    '#>>>>>>>',          1, commented marker returns false
    '>>>>>>',            1, truncated marker returns false
    '>>>>>>>>',          1, extended marker returns false
    '<<<<<<<',           0, start marker returns true
    '=======',           0, middle marker returns true
    '>>>>>>>',           0, end marker returns true
EOT
    return
}


#
# tst_mod_dir
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on mod_dir function.
#
function tst_mod_dir {

    dir=$(mod_dir)
    tst "$dir" '' 'no mod provided - returns nothing'

    mod=44444
    mod_dir="$DM_MODS/$mod"
    archive_dir="$DM_ARCHIVE/$mod"

    mkdir -p $DM_MODS
    mkdir -p $DM_ARCHIVE

    dir=$(mod_dir $mod)
    tst "$dir" '' 'mod directory does not exist - returns nothing'


    mkdir -p $mod_dir

    dir=$(mod_dir $mod)
    tst "$dir" "$mod_dir" 'returns correct mod directory'


    mv $mod_dir $DM_ARCHIVE

    dir=$(mod_dir $mod)
    tst "$dir" "$archive_dir" 'returns correct archive directory'
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
