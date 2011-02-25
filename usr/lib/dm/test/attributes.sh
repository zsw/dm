#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/attributes.sh functions.
#

__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

source $DM_ROOT/test/test.sh
__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh

#
# tst_attr_file_name
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on __attr_file_name function.
#
tst_attr_file_name() {

    mod=11111
    mod_dir="$DM_MODS/$mod"

    zzz_file_name=$(__attr_file_name $mod 'zzz')

    tst "$zzz_file_name" '' 'mod directory does not exist - returns nothing'


    mkdir -p $mod_dir

    zzz_file_name=$(__attr_file_name $mod 'zzz')

    tst "$zzz_file_name" "$mod_dir/zzz" 'zzz file name correct'
}


#
# tst_attr_file
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on __attr_file function.
#
tst_attr_file() {

    mod=22222
    mod_dir="$DM_MODS/$mod"

    yyy_file=$(__attr_file $mod 'yyy')

    tst "$yyy_file" '' 'mod directory does not exist - returns nothing'


    mkdir -p $mod_dir

    yyy_file=$(__attr_file $mod 'yyy')

    tst "$yyy_file" '' 'yyy file does not exist - returns nothing'


    touch $mod_dir/yyy

    yyy_file=$(__attr_file $mod 'yyy')

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
tst_attribute() {

    mod=33333
    mod_dir="$DM_MODS/$mod"

    xxx=$(__attribute $mod 'xxx')

    tst "$xxx" '' 'mod directory does not exist - returns nothing'


    mkdir -p $mod_dir

    xxx=$(__attribute $mod 'xxx')

    tst "$xxx" '' 'xxx file does not exist - returns nothing'


    touch $mod_dir/xxx

    xxx=$(__attribute $mod 'xxx')

    tst "$xxx" '' 'empty xxx file - returns nothing'


    echo 'aaabbbccc' > $mod_dir/xxx

    xxx=$(__attribute $mod 'xxx')

    tst "$xxx" "aaabbbccc" 'attribute returns contents correctly'
}


#
# tst_has_conflict_markers
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on __has_conflict_markers function.
#
tst_has_conflict_markers() {

    file=$(__tmp_file)

    __has_conflict_markers $file
    tst "$?" "1"  'file does not exist, returns false'


    touch $file

    __has_conflict_markers $file
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

        __has_conflict_markers $file
        tst "$?" "${arr[1]}" "single line ${arr[2]}"

        echo 'some line of text' > $file
        eval echo ${arr[0]} >> $file
        echo 'another line of text' >> $file

        __has_conflict_markers $file
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
tst_mod_dir() {

    dir=$(__mod_dir)
    tst "$dir" '' 'no mod provided - returns nothing'

    mod=44444
    mod_dir="$DM_MODS/$mod"
    archive_dir="$DM_ARCHIVE/$mod"

    mkdir -p $DM_MODS
    mkdir -p $DM_ARCHIVE

    dir=$(__mod_dir $mod)
    tst "$dir" '' 'mod directory does not exist - returns nothing'


    mkdir -p $mod_dir

    dir=$(__mod_dir $mod)
    tst "$dir" "$mod_dir" 'returns correct mod directory'


    mv $mod_dir $DM_ARCHIVE

    dir=$(__mod_dir $mod)
    tst "$dir" "$archive_dir" 'returns correct archive directory'
}

functions=$(awk '/^tst_/ {print $1}' $0)

[[ $1 ]] && functions="$*"

for function in  $functions; do
    function=${function%%(*}        # strip '()'
    if [[ ! $(declare -f "$function") ]]; then
        echo "Function not found: $function"
        continue
    fi

    "$function"
done
