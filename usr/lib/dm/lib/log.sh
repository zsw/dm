#!/bin/bash

#
# log.sh
#
# Library of functions related to logging.
#

# Log levels
#
# NOTE: Although these values are integers, the LOG_LEVEL variable is a string,
# eg 'error', 'warn', etc. The logger_level function converts the string to an
# integer.

LOG_LEVEL_DEBUG=1
LOG_LEVEL_INFO=2
LOG_LEVEL_WARN=3
LOG_LEVEL_ERROR=4
LOG_LEVEL_FATAL=5
LOG_LEVEL_OFF=6

[[ -z $LOG_LEVEL ]] && LOG_LEVEL='off'

# Log format

LOG_FORMAT_DATE=1
LOG_FORMAT_FILE=1
LOG_FORMAT_LEVEL=1
LOG_FORMAT_MESSAGE=1

# Log locations

# Do not initialize these or else values set within the environment are
# overwritten.
# LOG_TO_FILE=/var/log/dm.log        # Define this in .dm/dmrc
#LOG_TO_STDERR=
#LOG_TO_STDOUT=


function logger_level {

    eval "expr \$LOG_LEVEL_`echo $LOG_LEVEL | tr '[:lower:]' '[:upper:]'` 2>/dev/null"
}


function logger_log {

    level=$1
    shift

    log=

    [[ -n $LOG_FORMAT_DATE ]] && log="$log $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n $LOG_FORMAT_LEVEL ]] && log="$log [$level]"
    [[ -n $LOG_FORMAT_MESSAGE ]] && log="$log $*"
    [[ -n $LOG_FORMAT_FILE ]] && log="$log, $0"

    log=$(echo "$log" | sed 's/^[ \t]*//')

    [[ -n $LOG_TO_FILE ]] && echo "$log" >> $LOG_TO_FILE
    [[ -n $LOG_TO_STDERR ]] && echo "$log" >&2
    #[[ -n $LOG_TO_STDOUT ]] && [[ -t 1 ]] && echo "$log" >&1    # -t 1 tests stdout
    [[ -n $LOG_TO_STDOUT ]] && echo "$log" >&1    # -t 1 tests stdout
}

function logger_debug {

    log_level=$(logger_level)

    [[ -z $log_level ]] && return
    [[ $log_level -gt $LOG_LEVEL_DEBUG ]] && return

    logger_log 'DEBUG' "$*"
}

function logger_info {

    log_level=$(logger_level)

    [[ -z $log_level ]] && return
    [[ $log_level -gt $LOG_LEVEL_INFO ]] && return

    logger_log 'INFO' "$*"
}

function logger_warn {

    log_level=$(logger_level)

    [[ -z $log_level ]] && return
    [[ $log_level -gt $LOG_LEVEL_WARN ]] && return

    logger_log 'WARN' "$*"
}

function logger_error {

    log_level=$(logger_level)

    [[ -z $log_level ]] && return
    [[ $log_level -gt $LOG_LEVEL_ERROR ]] && return

    logger_log 'ERROR' "$*"
}

function logger_fatal {

    log_level=$(logger_level)

    [[ -z $log_level ]] && return
    [[ $log_level -gt $LOG_LEVEL_FATAL ]] && return

    logger_log 'FATAL' "$*"
    exit 1
}

# This function indicates this file has been sourced.
function _loaded_log {
    echo "_loaded_log BASH_SOURCE ${BASH_SOURCE[0]}" >&2
    return 0
}

# Export all functions to any script sourcing this library file.
for function in $(awk '/^function / { print $2}' $DM_ROOT/lib/log.sh); do
    export -f $function
done
