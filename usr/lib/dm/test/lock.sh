#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/lock.sh functions.
#

source $DM_ROOT/test/test.sh
__loaded_lock 2>/dev/null || source $DM_ROOT/lib/lock.sh


#
# tst_is_locked
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __is_locked function.
#
tst_is_locked() {
    local expect value file

    __is_locked && value=0 || value=1
    expect=1
    # Note: this assumes the dm system hasn't created a lock file
    tst "$value" "$expect" "no file, not locked"

    file=/tmp/tst_lock_sh.txt
    rm "$file" 2>/dev/null
    __is_locked "$file" && value=0 || value=1
    expect=1
    tst "$value" "$expect" "custom file, not exist, not locked"

    touch "$file"
    __is_locked "$file" && value=0 || value=1
    expect=0
    tst "$value" "$expect" "custom file, exists, locked"

    rm "$file" 2>/dev/null
}

#
# tst_lock_alert
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __lock_alert function.
#
tst_lock_alert() {
    local to file value expect

    to=iiijjjiii@gmail.com
    file=/tmp/tst_lock_sh.txt
    rm "$file" 2>/dev/null


    __lock_alert && value=0 || value=1
    expect=1
    tst "$value" "$expect" "no to email, returned 1"

    __lock_alert "$to" && value=0 || value=1
    expect=1
    tst "$value" "$expect" "no lock file, returned 1"

    __lock_alert "$to" "$file" && value=0 || value=1
    expect=1
    tst "$value" "$expect" "lock file does not exist, returned 1"

    __lock_create "$file"

    __lock_alert "$to" "$file" && value=0 || value=1
    expect=0
    tst "$value" "$expect" "lock file exists, returned 0"

    rm "$file" 2>/dev/null
}


#
# tst_lock_create
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __lock_create function.
#
tst_lock_create() {
    local file value expect

    file=/tmp/tst_lock_sh.txt
    rm "$file" 2>/dev/null

    __lock_create "$file" && value=0 || value=1
    expect=0
    tst "$value" "$expect" "lock success"

    [[ -r $file ]] && value=0 || value=1
    expect=0
    tst "$value" "$expect" "creates file"

    value=$(grep -c '^script: ' "$file")
    expect=1
    tst "$value" "$expect" "one script line found"

    value=$(grep -c '^created_on: ' "$file")
    expect=1
    tst "$value" "$expect" "one created_on line found"

    __lock_create "$file" && value=0 || value=1
    expect=1
    tst "$value" "$expect" "second lock fails"

    rm "$file" 2>/dev/null

    # Test where the lock file is in a none existent subdirectory
    file=/tmp/_tst_lock/tst_lock_sh.txt
    [[ -d /tmp/_tst_lock ]] && rm -r /tmp/_tst_lock

    __lock_create "$file" && value=0 || value=1
    expect=0
    tst "$value" "$expect" "subdirectory test, lock succeeds"

    [[ -r $file ]] && value=0 || value=1
    expect=0
    tst "$value" "$expect" "creates file"

    rm "$file" 2>/dev/null
    [[ -d /tmp/_tst_lock ]] && rm -r /tmp/_tst_lock
}


#
# tst_lock_file
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on lock_file function.
#
tst_lock_file() {
    local save_DM_TMP expect

    save_DM_TMP=DM_TMP
    DM_TMP=/tmp/dm_testing
    got=$(__lock_file)
    expect=${DM_TMP}/LOCK
    tst "$got" "$expect" 'returned expected'
    DM_TMP=$save_DM_TMP
}


#
# tst_lock_file_key_value
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __lock_file_key_value function.
#
tst_lock_file_key_value() {
    local file value expect fake_attr fake_val fake_val2

    file=/tmp/tst_lock_sh.txt
    rm "$file" 2>/dev/null

    value=$(__lock_file_key_value)
    expect=''
    tst "$value" "$expect" "no key, returned nothing"

    value=$(__lock_file_key_value script "$file")
    expect=''
    tst "$value" "$expect" "no lock file, returned nothing"

    script_file=$0
    [[ ${0:0:1} != '/' ]] && script_file="$PWD/${0#./}"

    echo "script: $script_file" >> "$file"

    value=$(__lock_file_key_value script "$file")
    expect=$script_file
    tst "$value" "$expect" "script attribute returned"

    fake_attr='fake_attr'
    fake_val='some value'
    fake_val2='another value'
    value=$(__lock_file_key_value "$fake_attr" "$file")
    expect=''
    tst "$value" "$expect" "no fake_attr, returned nothing"

    echo "$fake_attr: $fake_val" >> "$file"

    value=$(__lock_file_key_value "$fake_attr" "$file")
    expect=$fake_val
    tst "$value" "$expect" "fake attribute returned"

    echo "$fake_attr: $fake_val2" >> "$file"

    value=$(__lock_file_key_value "$fake_attr" "$file")
    expect=$fake_val2
    tst "$value" "$expect" "multiple fake attributes, returns last"

    rm "$file" 2>/dev/null
}


#
# tst_lock_is_alertable
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __lock_is_alertable function.
#
tst_lock_is_alertable() {
    local file value expect created_on

    file=/tmp/tst_lock_sh.txt
    rm "$file" 2>/dev/null

    __lock_is_alertable '' "$file" && value=0 || value=1
    expect=1
    tst "$value" "$expect" "lock file not exist, returns false"

    __lock_create "$file"

    __lock_is_alertable '' "$file" && value=0 || value=1
    expect=0
    tst "$value" "$expect" "file exist, no age, returns true"

    created_on=$(date --date="now - 20 minutes" "+%F %T")
    echo "created_on: $created_on" >> "$file"

    __lock_is_alertable '30 minutes' "$file" && value=0 || value=1
    expect=1
    tst "$value" "$expect" "not past age, returns false"

    __lock_is_alertable '10 minutes' "$file" && value=0 || value=1
    expect=0
    tst "$value" "$expect" "past age, returns true"

    rm "$file" 2>/dev/null
}


#
# tst_lock_remove
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __lock_remove function.
#
tst_lock_remove() {
    local file expect value

    file=/tmp/tst_lock_sh.txt
    rm "$file" 2>/dev/null

    __lock_create "$file"

    __is_locked "$file" && value=0 || value=1
    expect=0
    tst "$value" "$expect" "Control - lock file exists"

    __lock_remove "$file"

    __is_locked "$file" && value=0 || value=1
    expect=1
    tst "$value" "$expect" "lock file no longer exists"
}


functions=$(awk '/^tst_/ {print $1}' $0)

[[ $1 ]] && functions="$*"

for function in  $functions; do
    function=${function%%(*}        # strip '()'
    if ! declare -f "$function" &>/dev/null; then
        __mi "Function not found: $function" >&2
        continue
    fi

    "$function"
done
