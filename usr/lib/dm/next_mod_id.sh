#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh
__loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh

script=${0##*/}
_u() { cat << EOF
usage: $script

This script prints the next mod id to use for creating a new mod, and
increments the next mod id counter.
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


_options() {
    # set defaults
    args=()

    while [[ $1 ]]; do
        case "$1" in
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} != 0 )) && { _u; exit 1; }
}

_options "$@"


# Two instances of this script running concurrently can create foo. If
# the first instance does not increment the counter before the second
# instance reads the counter, they will both retrieve the same mod id
# resulting in two mods with the same id. The solution is to create a lock
# file. As long as the lock file exists, the script must wait before
# processing. This way the first instance will be completed before the
# second instance starts.

tmpdir=$(__tmp_dir)
mkdir -p $tmpdir
lock_file=$tmpdir/next_mod_id.LOCK

trap 'rm $lock_file; exit;' EXIT SIGINT

tries=300       # Approximately 5 minutes
count=0

while true; do
    [[ ! -e $lock_file ]] && break
    ((count += 1))
    (( $count > $tries )) && break
    sleep 1
done

[[ -e $lock_file ]] && __me "Unable to determine next mod id due to lock file: $lock_file"

echo $$ > "$lock_file"  ## Store PID

warn_at=10                      # Warn when only this many ids remain

[[ ! $DM_PERSON_ID ]] && __me "Unable to determine person id."

# Check for reusable mods
if [[ -s $DM_USERS/reusable_ids ]]; then
    dupes=$(sort $DM_USERS/reusable_ids | uniq -d | tr "\n" " ")
    [[ $dupes ]] && __me "Duplicate IDs in reusable_ids file: $dupes"
    next_mod_id=$(head -1 "$DM_USERS/reusable_ids")
    sed -i '1d' "$DM_USERS/reusable_ids"    ## Remove first line from file
    echo "$next_mod_id"
    exit 0
fi


# $ cat ids
# 10000,29999,1
# 30000,49999,2
# 50000,99949,0
# 99950,99999,4

# gsub strips leading zeros.
start_mod_id=$(awk -v p_id="$DM_PERSON_ID" -F",[ \t]*" '!/^#/ && $3 == p_id {gsub(/^0*/,"",$1); print $1}' "$DM_IDS")
[[ ! $start_mod_id ]] && __me "Unable to determine start of block of ids for person id $DM_PERSON_ID."

end_mod_id=$(awk -v p_id="$DM_PERSON_ID" -F",[ \t]*" '!/^#/ && $3 == p_id {gsub(/^0*/,"",$2); print $2}' "$DM_IDS")
[[ ! $end_mod_id ]] && __me "Unable to determine end of block of ids for person id $DM_PERSON_ID."

last_mod_id=$(sed 's/^0*\([0-9]\+\)/\1/' "$DM_USERS/mod_counter")            # Strip leading zeros
[[ ! $last_mod_id ]] && __me "Unable to determine last mod id for person id $DM_PERSON_ID."

next_mod_id=0

# Normally the next_mod_id is just the last_mod_id incremented. However, there
# is one exception. When a range of ids is completed, a user will be assigned
# to a new range. The last_mod_id will still point to the old range and there
# is no guarantee incrementing it will return a mod in the new range. A check
# for that condition should be made and handled.

last_id_is_in_range=$(awk -v min="$start_mod_id" -v max="$end_mod_id" 'min <= $1 && $1 <= max' <<< "$last_mod_id")
if [[ $last_id_is_in_range ]]; then
    #Increment
    next_mod_id=$(($last_mod_id + 1))
else
    # Assume a new block has been assigned
    next_mod_id=$start_mod_id
fi

next_in_range=$(awk -v min="$start_mod_id" -v max="$end_mod_id" 'min <= $1 && $1 <= max' <<< "$next_mod_id")

if [[ ! $next_in_range ]]; then
    __me "No mod ids remaining for person $DM_PERSON_ID.
        Assign the person a new block of ids in the $DM_IDS file"
fi

warn_min=$(( $end_mod_id - $warn_at ))

warn=$(awk -v min="$warn_min" -v max="$end_mod_id" 'min <= $1 && $1 <= max' <<< "$next_mod_id")

if [[ $warn ]]; then
    remaining=$(( $end_mod_id - $next_mod_id ))
    __mi "Warning: $remaining mod ids remaining for person $DM_PERSON_ID.
        Consider assigning the person a new block of ids in the $DM_IDS file" >&2
fi

printf %05d "$next_mod_id" | tee "$DM_USERS/mod_counter"

exit 0
