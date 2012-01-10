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
    local MOD_ID_1 MOD_ID_2 WHO_INITIALS WHO_USERNAME WHO_ALERT_INIT WHO_ALERT_USERNAME replaced safe
    local ALERT_FILE username timestamp digits_only digits_only id records

    MOD_ID_1=11111
    MOD_ID_2=22222
    WHO_INITIALS=DE
    WHO_USERNAME=ddee
    WHO_ALERT_INIT=ABC
    WHO_ALERT_USERNAME=aabbcc
    ALERT_FILE="$DM_USERS/alerts/$WHO_USERNAME"

    # die quickly if DM_USERS is not defined properly.
    # DM_USERS should not be a subdirectory of DM_ROOT or tests could
    # clobber live data.
    replaced=${DM_USERS/$DM_ROOT/}
    safe=no
    [[ $replaced == $DM_USERS ]] && safe=yes

    tst "$safe" "yes" "DM_USERS is safe"
    [[ $safe == no ]] && return

    replaced=${DM_PEOPLE/$DM_ROOT/}
    safe=no
    [[ $replaced == $DM_PEOPLE ]] && safe=yes

    tst "$safe" "yes" "DM_PEOPLE is safe"
    [[ $safe == no ]] && return

    mkdir -p "$DM_MODS/$MOD_ID_1" && touch "$DM_MODS/$MOD_ID_1/description"
    mkdir -p "$DM_MODS/$MOD_ID_2" && touch "$DM_MODS/$MOD_ID_2/description"
    mkdir -p "$DM_ROOT/users/$WHO_ALERT_USERNAME" && touch "$DM_ROOT/users/$WHO_ALERT_USERNAME/reusable_ids"

    rm "$ALERT_FILE" 2>/dev/null

    cat <<EOT >> "$DM_PEOPLE"
id,initials,username, name
1, ABC, aabbcc, Aaa Cccccc
2,  DE, ddee,   Dddd Eeeeeeee
3, FGH, ffgghh, Fffff Gggggggggg
EOT

    username=$(__person_attribute username initials "$WHO_INITIALS")
    tst "$username" "$WHO_USERNAME" "correct username from initials"

    __create_alert
    find "$ALERT_FILE" 2>/dev/null
    tst "$?" "1" "no who provided, fails"

    __create_alert "$WHO_INITIALS"
    find "$ALERT_FILE" 2>/dev/null
    tst "$?" "1" "no mod_id provided, fails"

    __create_alert "$WHO_INITIALS" "$MOD_ID_1"
    timestamp=$(awk '{print $1}' "$ALERT_FILE" 2>/dev/null)
    digits_only=$(tr -d -c '[:digit:]' <<< "$timestamp")
    tst "$digits_only" "$timestamp" "alert has all digit timestamp"
    id=$(awk '{print $2}' "$ALERT_FILE" 2>/dev/null)

    tst "$id" "$MOD_ID_1" "alert is for correct mod"
    records=$(wc -l < "$ALERT_FILE")
    tst "$records" "1" "alert file has one record"

    __create_alert "$WHO_INITIALS" "$MOD_ID_2"
    records=$(wc -l < "$ALERT_FILE")
    tst "$records" "2" "alert file has two records"
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
