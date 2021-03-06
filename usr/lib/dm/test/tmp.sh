#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/tmp.sh functions.
#

source $DM_ROOT/test/test.sh
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh


#
# tst_tmp_dir
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on tmp_dir function.
#
tst_tmp_dir() {
    local save_DM_TMP value expect save_USERNAME

    save_DM_TMP=DM_TMP
    DM_TMP=/tmp/dm_testing

    # Should use DM_TMP
    value=$(__tmp_dir)
    expect=/tmp/dm_testing
    tst "$value" "$expect" "provided username returned expected"

    unset DM_TMP

    # Provide username
    value=$(__tmp_dir test_user_1)
    expect=/tmp/dm_test_user_1
    tst "$value" "$expect" "provided username returned expected"

    save_USERNAME=$USERNAME
    # Set USERNAME
    USERNAME=test_user_2
    value=$(__tmp_dir)
    expect=/tmp/dm_test_user_2
    tst "$value" "$expect" "no args, set USERNAME, returned expected"

    # Unset USERNAME
    unset USERNAME
    value=$(__tmp_dir)
    # Expect /tmp/dm_Cz3LTel7FVhH
    expect=$(grep "/tmp/dm_[a-zA-Z0-9]\{10\}" <<< "$value")
    tst "$value" "$expect" "no args, unset USERNAME, returned expected"

    USERNAME=$save_USERNAME
    DM_TMP=$save_DM_TMP
}


#
# tst_tmp_file
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on tmp_file function.
#
tst_tmp_file() {
    local save_DM_TMP subdir value expect

    # Provide directory
    save_DM_TMP=DM_TMP
    DM_TMP=/tmp/dm_username
    subdir=dm_username
    [[ -d /tmp/$subdir ]] && rm -r "/tmp/$subdir"
    value=$(__tmp_file "/tmp/$subdir")
    # Expect eg: /tmp/dm_username/tmp.Cz3LTel7FVhH
    expect=$(grep '/tmp/dm_username/tmp.[a-zA-Z0-9]\{10\}' <<< "$value")
    tst "$value" "$expect" "provided directory returned expected"

    [[ -d /tmp/$subdir ]]
    tst "$?" "0" "temp directory created"

    # Cleanup
    [[ -d /tmp/$subdir ]] && rm -r "/tmp/$subdir"

    unset DM_TMP
    save_USERNAME=$USERNAME

    # No directory set username
    USERNAME=test_user_3
    subdir=dm_$USERNAME
    [[ -d /tmp/$subdir ]] && rm -r "/tmp/$subdir"
    value=$(__tmp_file)
    expect=$(grep '/tmp/dm_test_user_3/tmp.[a-zA-Z0-9]\{10\}' <<< "$value")
    tst "$value" "$expect" "no args, set USERNAME, returned expected"

    # Cleanup
    [[ -d /tmp/$subdir ]] && rm -r "/tmp/$subdir"

    # No directory unset username
    unset USERNAME
    value=$(__tmp_file)
    expect=$(grep '/tmp/dm_[a-zA-Z0-9]\{12\}/tmp.[a-zA-Z0-9]\{10\}' <<< "$value")
    tst "$value" "$expect" "no args, unset USERNAME, returned expected"

    # Cleanup
    subdir=$(grep -o 'dm_\([a-zA-Z0-9]\{12\}\)' <<< "$value")
    [[ $subdir ]] && rm -rf "/tmp/$subdir"

    USERNAME=$save_USERNAME
    DM_TMP=$save_DM_TMP
}


functions=$(awk '/^tst_/ {print $1}' "$0")

[[ $1 ]] && functions="$*"

for function in  $functions; do
    function=${function%%(*}        # strip '()'
    if ! declare -f "$function" &>/dev/null; then
        __mi "Function not found: $function" >&2
        continue
    fi

    "$function"
done
