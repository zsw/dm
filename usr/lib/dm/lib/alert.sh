#!/bin/bash

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_hold 2>/dev/null || source $DM_ROOT/lib/hold.sh

#
# alert.sh
#
# Library of functions related to alerting.
#

#
# __create_alert
#
# Sent: who - initials of person alert is for, eg JK
#       mod_id - id of the mod the alert relates to
# Return: nothing
# Purpose:
#
#   Create an alert for the indicate person regarding the indicated mod.
#
__create_alert() {

    local who mod_id username alert_dir alert_file date status
    who=$1
    mod_id=$2

    [[ ! $who ]] && return
    [[ ! $mod_id ]] && return

    ## Test if JK == JK return
    mod_who=$(__attribute "$mod_id" 'who')
    [[ $who == $mod_who ]] && return

    ## Test if mod is on_hold
    status=$(__hold_status "$mod_id" | awk '{print $5}')
    [[ $status =~ on_hold|expired ]] && return

    ## Test if mod is done
    mod_dir=$(__mod_dir "$mod_id")
    [[ ! $mod_dir ]] && return
    [[ $mod_dir == $DM_ARCHIVE/$mod_id ]] && return

    ## Test if mod is reusable
    username=$(__person_attribute username initials "$mod_who")
    grep -q "$mod_id" "$DM_ROOT/users/$username/reusable_ids" && return

    username=$(__person_attribute username initials "$who")
    alert_dir=$DM_USERS/alerts
    mkdir -p "$alert_dir"
    alert_file=$alert_dir/$username
    date=$(date "+%s")
    echo "$date $mod_id" >> "$alert_file"

    return
}


# This function indicates this file has been sourced.
__loaded_alert() {
    return 0
}

# Export all functions to any script sourcing this library file.
while read -r function; do
    export -f "${function%%(*}"         # strip '()'
done < <(awk '/^__*()/ {print $1}' "$DM_ROOT"/lib/alert.sh)
