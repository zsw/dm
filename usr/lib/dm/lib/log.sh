#!/bin/bash

#
# log.sh
#
# Library of functions related to logging.
#

# Log levels
#
# NOTE: Although these values are integers, the LOG_LEVEL variable is a string,
# eg 'error', 'warn', etc. The __logger_level function converts the string to an
# integer.

LOG_LEVEL_DEBUG=1
LOG_LEVEL_INFO=2
LOG_LEVEL_WARN=3
LOG_LEVEL_ERROR=4
LOG_LEVEL_FATAL=5
LOG_LEVEL_OFF=6

[[ ! $LOG_LEVEL ]] && LOG_LEVEL=off

# Log format

LOG_FORMAT_DATE=1
LOG_FORMAT_FILE=1
LOG_FORMAT_LEVEL=1
LOG_FORMAT_MESSAGE=1

# Log locations

# Do not initialize these or else values set within the environment are
# overwritten.
#LOG_TO_STDERR=
#LOG_TO_STDOUT=


__logger_level() {

    case "${LOG_LEVEL^^}" in
        DEBUG)  echo "$LOG_LEVEL_DEBUG" ;;
         INFO)  echo "$LOG_LEVEL_INFO"  ;;
         WARN)  echo "$LOG_LEVEL_WARN"  ;;
        ERROR)  echo "$LOG_LEVEL_ERROR" ;;
        FATAL)  echo "$LOG_LEVEL_FATAL" ;;
          OFF)  echo "$LOG_LEVEL_OFF"   ;;
    esac
}


__logger_log() {
    local level log prefix syslog facility facility_level

    level=$1
    shift

    prefix=${DM_LOG%:*}
    if [[ $prefix == syslog ]]; then
        syslog=1
        facility=${DM_LOG#*:}
    fi

    if [[ $syslog ]]; then
        [[ $LOG_FORMAT_LEVEL ]] && log+=" [$level]"
        [[ $LOG_FORMAT_MESSAGE ]] && log+=" $*"
    else
        [[ $LOG_FORMAT_DATE ]] && log+=" $(date '+%Y-%m-%d %H:%M:%S')"
        [[ $LOG_FORMAT_LEVEL ]] && log+=" [$level]"
        [[ $LOG_FORMAT_MESSAGE ]] && log+=" $*"
        [[ $LOG_FORMAT_FILE ]] && log+=", $0"
    fi

    read -r log <<< "$log"  ## trim whitespace

    if [[ $syslog ]]; then
        # ${var,,}" convert variable to lower case
        #logger -i -t dm -p local7.info -- "$log"
        logger -i -t dm -p "$facility.${level,,}" -- "$log"
    else
        [[ $DM_LOG ]] && echo "$log" >> "$DM_LOG"
    fi

    [[ $LOG_TO_STDERR ]] && echo "$log" >&2
    [[ $LOG_TO_STDOUT ]] && echo "$log" >&1
}

__logger_debug() {
    local log_level

    log_level=$(__logger_level)

    [[ ! $log_level ]] && return
    (( $log_level > $LOG_LEVEL_DEBUG )) && return

    __logger_log 'DEBUG' "$*"
}

__logger_info() {
    local log_level

    log_level=$(__logger_level)

    [[ ! $log_level ]] && return
    (( $log_level > $LOG_LEVEL_INFO )) && return

    __logger_log 'INFO' "$*"
}

__logger_warn() {
    local log_level

    log_level=$(__logger_level)

    [[ ! $log_level ]] && return
    (( $log_level > $LOG_LEVEL_WARN )) && return

    __logger_log 'WARN' "$*"
}

__logger_error() {
    local log_level

    log_level=$(__logger_level)

    [[ ! $log_level ]] && return
    (( $log_level > $LOG_LEVEL_ERROR )) && return

    __logger_log 'ERROR' "$*"
}

__logger_fatal() {
    local log_level

    log_level=$(__logger_level)

    [[ ! $log_level ]] && return
    (( $log_level > $LOG_LEVEL_FATAL )) && return

    __logger_log 'FATAL' "$*"
    exit 1
}

# This function indicates this file has been sourced.
__loaded_log() {
    echo "_loaded_log BASH_SOURCE ${BASH_SOURCE[0]}" >&2
    return 0
}

# Export all functions to any script sourcing this library file.
while read -r function; do
    export -f "${function%%(*}"         # strip '()'
done < <(awk '/^__*()/ {print $1}' "$DM_ROOT"/lib/log.sh)
