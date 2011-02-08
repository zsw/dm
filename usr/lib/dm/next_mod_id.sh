#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh
_loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh

usage() { cat << EOF
usage: $0

This script prints the next mod id to use for creating a new mod, and
increments the next mod id counter.

OPTIONS:
    -d      Dry run. Next mod id is not incremented.
    -h      Print this help message.

NOTES:

    See: $DM_ROOT/doc/mods for an explanation of the design of mod ids.

    Blocks of ids assigned to the user are determiend by reading the
    $DM_ROOT/users/ids file.

    The script will replace the value of the next mod id with the person's
    start_mod_id if the current value of the next mod id is not within the
    block of ids assigned to the person.

    If on incrementing, the next mod id counter outside the block of ids
    assigned to the person, the script aborts with an error message.

    A warning message is printed to stderr if there are less than 10 ids left
    in the block of ids assigned the user.
EOF
}


#
# exit_with_message
#
# Sent: message
# Return: nothing
# Purpose:
#
#   Exit script with message.
#
function exit_with_message {

    msg=$1

    echo "$msg" >&2
    rm $LOCK_FILE
    exit 1
}


dryrun=false
while getopts "hd" options; do
  case $options in

    d ) dryrun=true;;
    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
         exit 1;;

  esac
done

shift $(($OPTIND - 1))

# Two instances of this script running concurrently can create foo. If
# the first instance does not increment the counter before the second
# instance reads the counter, they will both retrieve the same mod id
# resulting in two mods with the same id. The solution is to create a lock
# file. As long as the lock file exists, the script must wait before
# processing. This way the first instance will be completed before the
# second instance starts.

tmpdir=$(tmp_dir)
mkdir -p $tmpdir
LOCK_FILE="${tmpdir}/next_mod_id.LOCK"

TRIES=300       # Approximately 5 minutes


count=0
while : ; do
    ! test -e $LOCK_FILE && break
    count=$(($count+1))
    [[ "$count" -ge "$TRIES" ]] && break
    sleep 1
done

if [[ -e $LOCK_FILE ]]; then
    echo "Unable to determine next mod id due to lock file: $LOCK_FILE" >&2
    exit 1
fi

echo $$ > $LOCK_FILE

$dryrun && logger_debug "**Dry run on. Next mod id is not incremented."

WARN_AT=10                      # Warn when only this many ids remain

if [[ -z "$DM_PERSON_ID" ]]; then
    exit_with_message "Unable to determine person id."
fi

logger_debug "Person id: $DM_PERSON_ID"


start_mod_id=$(cat $DM_IDS | awk -v pid=$DM_PERSON_ID 'BEGIN { FS = ",[ \t]*"} !/^#/ && $3 == pid {print $1}' | sed 's/^0*\([0-9]\+\)/\1/')

if [[ -z "$start_mod_id" ]]; then
    exit_with_message "Unable to determine start of block of ids for person id $DM_PERSON_ID."
fi

logger_debug "Start mod id: $start_mod_id"


end_mod_id=$(cat $DM_IDS | awk -v pid=$DM_PERSON_ID 'BEGIN { FS = ",[ \t]*"} !/^#/ && $3 == pid {print $2}' | sed 's/^0*\([0-9]\+\)/\1/')

if [[ -z "$end_mod_id" ]]; then
    exit_with_message "Unable to determine end of block of ids for person id $DM_PERSON_ID."
fi

logger_debug "End mod id: $end_mod_id"

last_mod_id=$(sed 's/^0*\([0-9]\+\)/\1/' "$DM_USERS/mod_counter")            # Strip leading zeros

if [[ -z "$last_mod_id" ]]; then
    exit_with_message "Unable to determine last mod id for person id $DM_PERSON_ID."
fi

logger_debug "Last mod id: $last_mod_id"

last_in_range=$(echo $last_mod_id | awk -v min=$start_mod_id -v max=$end_mod_id 'min <= $1 && $1 <= max')

next_mod_id=0

if [[ -n $last_in_range ]]; then
    #Increment
    next_mod_id=$(($last_mod_id + 1))
else
    # Assume a new block has been assigned
    next_mod_id=$start_mod_id
fi

logger_debug "Next mod id: $next_mod_id"


next_in_range=$(echo $next_mod_id | awk -v min=$start_mod_id -v max=$end_mod_id 'min <= $1 && $1 <= max')

if [[ -z $next_in_range ]]; then
    echo "No mod ids remaining for person $DM_PERSON_ID." >&2
    exit_with_message "Assign the person a new block of ids in the $DM_IDS file"
fi


warn_min=$(($end_mod_id - $WARN_AT))

warn=$(echo $next_mod_id | awk -v min=$warn_min -v max=$end_mod_id 'min <= $1 && $1 <= max')

if [[ -n $warn ]]; then
    remaining=$(( $end_mod_id - $next_mod_id ))
    echo "Warning: $remaining mod ids remaining for person $DM_PERSON_ID." >&2
    echo "Consider assigning the person a new block of ids in the $DM_IDS file" >&2
fi


printf %05d $next_mod_id

$dryrun && logger_debug "Next mod id is not incremented."
! $dryrun && printf %05d $next_mod_id > "$DM_USERS/mod_counter"

rm $LOCK_FILE

exit 0

