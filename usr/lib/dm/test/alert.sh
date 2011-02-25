#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/weechat.sh functions.
#

source $DM_ROOT/test/test.sh
__loaded_alert 2>/dev/null || source $DM_ROOT/lib/alert.sh
__loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh

#
# tst_create_alert
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on __create_alert function.
#
tst_create_alert() {

    MOD_ID_1=11111
    MOD_ID_2=22222
    WHO_INITIALS='DE'
    WHO_USERNAME='ddee'

    # die quickly if DM_USERS is not defined properly.
    # DM_USERS should not be a subdirectory of DM_ROOT or tests could
    # clobber live data.
    local replaced=${DM_USERS/$DM_ROOT/}
    local safe='no'
    if [[ "$replaced" == "$DM_USERS" ]]; then
        safe='yes'
    fi

    tst "$safe" "yes" "DM_USERS is safe"
    if [[ $safe == 'no' ]]; then
        return
    fi

    local replaced=${DM_PEOPLE/$DM_ROOT/}
    local safe='no'
    if [[ "$replaced" == "$DM_PEOPLE" ]]; then
        safe='yes'
    fi

    tst "$safe" "yes" "DM_PEOPLE is safe"
    if [[ $safe == 'no' ]]; then
        return
    fi

    ALERT_FILE="$DM_USERS/alerts/$WHO_USERNAME"
    rm $ALERT_FILE 2>/dev/null

    cat <<EOT >> $DM_PEOPLE
id,initials,username, name
1, ABC, aabbcc, Aaa Cccccc
2,  DE, ddee,   Dddd Eeeeeeee
3, FGH, ffgghh, Fffff Gggggggggg
EOT

    local username=$(__person_attribute username initials $WHO_INITIALS)
    tst "$username" "$WHO_USERNAME" "correct username from initials"

    __create_alert
    find $ALERT_FILE 2>/dev/null
    tst "$?" "1" "no who provided, fails"

    __create_alert $WHO_INITIALS
    find $ALERT_FILE 2>/dev/null
    tst "$?" "1" "no mod_id provided, fails"

    __create_alert $WHO_INITIALS $MOD_ID_1
    local timestamp=$(awk '{print $1}' $ALERT_FILE 2>/dev/null)
    local digits_only=$(echo $timestamp | tr -d -c '[:digit:]')
    tst "$digits_only" "$timestamp" "alert has all digit timestamp"
    local id=$(awk '{print $2}' $ALERT_FILE 2>/dev/null)
    tst "$id" "$MOD_ID_1" "alert is for correct mod"
    local records=$(cat $ALERT_FILE | wc -l)
    tst "$records" "1" "alert file has one record"

    __create_alert $WHO_INITIALS $MOD_ID_2
    records=$(cat $ALERT_FILE | wc -l)
    tst "$records" "2" "alert file has two records"

    return
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
