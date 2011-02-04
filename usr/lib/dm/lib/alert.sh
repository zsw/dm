#!/bin/bash

#
# alert.sh
#
# Library of functions related to alerting.
#

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

#
# create_alert
#
# Sent: who - initials of person alert is for, eg JK
#       mod_id - id of the mod the alert relates to
# Return: nothing
# Purpose:
#
#   Create an alert for the indicate person regarding the indicated mod.
#
function create_alert {

    local who=$1
    local mod_id=$2

    if [[ -z $who ]]; then
        logger_error "Unable to create alert. No initials provided."
        return
    fi

    if [[ -z $mod_id ]]; then
        logger_error "Unable to create alert. No mod id provided."
        return
    fi

    local username=$(person_attribute username initials $who)
    local alert_dir="$DM_VAR/alerts"
    mkdir -p "$alert_dir"
    local alert_file="$alert_dir/$username"
    local date=$(date "+%s")
    echo "$date $mod_id" >> $alert_file

    return
}

# This function indicates this file has been sourced.
function _loaded_alert {
    return 0
}

# Export all functions to any script sourcing this library file.
for function in $(awk '/^function / { print $2}' $DM_ROOT/lib/alert.sh); do
    export -f $function
done
