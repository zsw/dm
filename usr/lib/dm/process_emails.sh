#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 [options]

This script processes all email files in the $DM_USERS/input directory,
triggering conversion to mods for each.

OPTIONS:

    -v  Verbose.

    -h   Print this help message.

NOTES:

    The script is intended to be cronned. Processing may take a few minutes.
EOF
}

verbose=

while getopts "hv" options; do
  case $options in

    v ) verbose=1;;
    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

[[ $verbose ]] && LOG_LEVEL=debug
[[ $verbose ]] && LOG_TO_STDOUT=1

# Set nullglob to prevent messages if directory is empty
shopt -s nullglob

fail_dir="$DM_USERS/input/fail"

# In case this directory has not yet been created, create it now so the script
# doesn't crash.
mkdir -p "$DM_USERS/input"

for email in $(find $DM_USERS/input/ -maxdepth 1 -type f); do
    # NOTE: Every email processed in this loop must be removed from
    # $DM_USERS/input. If it is not removed the cron will continually process
    # it possibly creating duplicate mods. If there are errors, move the email
    # to $DM_USERS/input/fail. If there are no errors, delete the email.

    errors=
    logger_debug "Processing email: $email"
    mod_id=$($DM_BIN/mail2mod.sh "$email")
    if [[ "$?" != "0" ]] || [[ ! $mod_id ]];then
        echo "ERROR: Unable to convert email to mod: $email" >&2
        errors=1
    else
        logger_debug "Sorting mod: $mod_id"
        echo $mod_id | $DM_BIN/sort_input.sh
        if [[ "$?" != "0" ]]; then
            echo "ERROR: sort_input.sh for mod $mod_id failed." >&2
            echo "Retry with: echo $mod_id | sort_input.sh" >&2
            errors=1
        fi
    fi

    if [[ $errors ]]; then
        logger_debug "Moving email $email to email_fail."
        mkdir -p $fail_dir
        mv $email $fail_dir/
        base=$(basename $email)
        echo "Email archived: $fail_dir/$base" >&2
    else
        logger_debug "Removing email $email"
        rm "$email"
    fi
done


