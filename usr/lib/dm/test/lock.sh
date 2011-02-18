#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/lock.sh functions.
#

source $DM_ROOT/test/test.sh
_loaded_lock 2>/dev/null || source $DM_ROOT/lib/lock.sh


#
# tst_is_locked
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on is_locked function.
#
function tst_is_locked {

    value=$(is_locked)
    expect="false"
    # Note: this assumes the dm system hasn't created a lock file
    tst "$value" "$expect" "no file, not locked"

    file='/tmp/tst_lock_sh.txt'
    rm $file 2>/dev/null

    value=$(is_locked $file)
    expect="false"
    tst "$value" "$expect" "custom file, not exist, not locked"

    touch $file
    value=$(is_locked $file)
    expect="true"
    tst "$value" "$expect" "custom file, exists, locked"

    rm $file 2>/dev/null

    return
}

#
# tst_lock_alert
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on lock_alert function.
#
function tst_lock_alert {

    to='iiijjjiii@gmail.com'
    file='/tmp/tst_lock_sh.txt'
    rm $file 2>/dev/null


    value=$(lock_alert)
    expect='false'
    tst "$value" "$expect" "no to email, returned false"

    value=$(lock_alert $to)
    expect='false'
    tst "$value" "$expect" "no lock file, returned false"

    value=$(lock_alert $to $file)
    expect='false'
    tst "$value" "$expect" "lock file does not exist, returned false"

    lock_create $file

    value=$(lock_alert $to $file)
    expect='true'
    tst "$value" "$expect" "lock file exists, returned true"

    rm $file 2>/dev/null

    return
}


#
# tst_lock_create
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on lock_create function.
#
function tst_lock_create {

    file='/tmp/tst_lock_sh.txt'
    rm $file 2>/dev/null

    result=$(lock_create $file)
    expect='true'
    tst "$result" "$expect" "lock success"

    exists='false'
    [[ -r $file ]] && exists='true'
    expect='true'
    tst "$exists" "$expect" "creates file"

    value=$(grep --count '^script: ' $file)
    expect=1
    tst "$value" "$expect" "one script line found"

    value=$(grep --count '^created_on: ' $file)
    expect=1
    tst "$value" "$expect" "one created_on line found"

    result=$(lock_create $file)
    expect='false'
    tst "$result" "$expect" "second lock fails"

    rm $file 2>/dev/null

    # Test where the lock file is in a none existent subdirectory

    file='/tmp/_tst_lock/tst_lock_sh.txt'
    [[ -d /tmp/_tst_lock ]] && rm -r /tmp/_tst_lock

    result=$(lock_create $file)
    expect='true'
    tst "$result" "$expect" "subdirectory test, lock succeeds"

    exists='false'
    [[ -r $file ]] && exists='true'
    expect='true'
    tst "$exists" "$expect" "creates file"

    rm $file 2>/dev/null
    [[ -d /tmp/_tst_lock ]] && rm -r /tmp/_tst_lock
    return
}


#
# tst_lock_file
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on lock_file function.
#
function tst_lock_file {

    save_DM_TMP=DM_TMP
    DM_TMP=/tmp/dm_testing
    got=$(lock_file)
    expect="${DM_TMP}/LOCK"
    tst "$got" "$expect" 'returned expected'
    DM_TMP=$save_DM_TMP
}


#
# tst_lock_file_key_value
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on lock_file_key_value function.
#
function tst_lock_file_key_value {

    file='/tmp/tst_lock_sh.txt'
    rm $file 2>/dev/null

    value=$(lock_file_key_value)
    expect=''
    tst "$value" "$expect" "no key, returned nothing"

    value=$(lock_file_key_value script $file)
    expect=''
    tst "$value" "$expect" "no lock file, returned nothing"

    script_file=$0
    [[ ${0:0:1} != '/' ]] && script_file="$PWD/${0#./}"

    echo "script: $script_file" >> $file

    value=$(lock_file_key_value script $file)
    expect=$script_file
    tst "$value" "$expect" "script attribute returned"

    fake_attr='fake_attr'
    fake_val='some value'
    fake_val2='another value'
    value=$(lock_file_key_value $fake_attr $file)
    expect=''
    tst "$value" "$expect" "no fake_attr, returned nothing"

    echo "$fake_attr: $fake_val" >> $file

    value=$(lock_file_key_value $fake_attr $file)
    expect=$fake_val
    tst "$value" "$expect" "fake attribute returned"

    echo "$fake_attr: $fake_val2" >> $file

    value=$(lock_file_key_value $fake_attr $file)
    expect=$fake_val2
    tst "$value" "$expect" "multiple fake attributes, returns last"

    rm $file 2>/dev/null

    return
}


#
# tst_lock_is_alertable
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on lock_is_alertable function.
#
function tst_lock_is_alertable {

    file='/tmp/tst_lock_sh.txt'
    rm $file 2>/dev/null

    value=$(lock_is_alertable '' $file)
    expect='false'
    tst "$value" "$expect" "lock file not exist, returns false"

    lock_create $file

    value=$(lock_is_alertable '' $file)
    expect='true'
    tst "$value" "$expect" "file exist, no age, returns true"

    created_on=$(date --date="now - 20 minutes" "+%F %T")
    echo "created_on: $created_on" >> $file

    value=$(lock_is_alertable '30 minutes' $file)
    expect='false'
    tst "$value" "$expect" "not past age, returns false"

    value=$(lock_is_alertable '10 minutes' $file)
    expect='true'
    tst "$value" "$expect" "past age, returns true"

    rm $file 2>/dev/null

    return
}


#
# tst_lock_remove
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on lock_remove function.
#
function tst_lock_remove {

    file='/tmp/tst_lock_sh.txt'
    rm $file 2>/dev/null

    lock_create $file

    value=$(is_locked $file)
    expect='true'
    tst "$value" "$expect" "Control - lock file exists"

    lock_remove $file

    value=$(is_locked $file)
    expect='false'
    tst "$value" "$expect" "lock file no longer exists"

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
