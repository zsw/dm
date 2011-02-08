#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

usage() {

    cat << EOF

usage: $0 [OPTIONS] [mod_id mod_id ...]
       or
       echo mod_id | $0 [OPTIONS] -

This script sends a message to all remind email addresses for a mod.

OPTIONS:

   -d      Dry run. No email is sent.

   -h      Print this help message.

EXAMPLES:

    $0 12345
    $0 12345 23456 34567
    echo 12345 | $0 -

NOTES:

    Mod ids can be provided through stdin or as arguments.
    To read the mod list from stdin, use the mod_id '-'.

    If a mod id is not provided the current one is used, ie. the one
    indicated in $DM_USERS/current_mod

    This script will send reminders regardless if the mod is in the mods
    directory of in the archive directory.
EOF
}


#
# process_mod
#
# Sent: mod
# Return: nothing
# Purpose:
#
#   Process reminds for a mod.
#
function process_mod {

    mod=$1

    dir=$(mod_dir $mod)

    if [[ -z $dir ]]; then
        echo "Unable to locate mod $mod in mods or archive directories" >&2
        return
    fi

    logger_debug "Found remind file in $dir"

    remind_mod "$dir"
}

#
# remind_mod
#
# Sent: mod directory (Eg: ~/dm/mods/12345, ~/dm/archive/12345)
# Return: nothing
# Purpose:
#
#   Send an email to all remind email addresses for the mod.
#
function remind_mod {

    mod_dir="$1"

    logger_debug "remind_mod mod_dir: $mod_dir"

    remind="$mod_dir/remind"
    [[ ! -e $remind ]] && return

    # Piping through the sed escapes double quotes and replaces semi-colon with comma.

    subject=$(cat $mod_dir/description | sed -e "s/\"/\\\\\"/" )
    notes=$(cat $mod_dir/notes | sed -e "s/\"/\\\\\"/" )

    for to in $(cat $remind); do

        $dryrun && logger_debug "Dry run. Emails not sent."
        $dryrun && continue

        fetch=true

        res=$(echo -e "To: $to\nSubject: $subject\n\n$notes" | sendmail -v -- $to)
        logger_debug "$res"
    done

    return;
}

dryrun=false

while getopts "dh" options; do
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

$dryrun && logger_debug "** Dry run **"

fetch=false

[[ "$#" -eq "0" ]] && set -- $(< $DM_USERS/current_mod)

while [[ ! "$#" -eq "0" ]]; do
    if [ "$1" == "-" ]; then
        # eg echo 12345 | remind_mod.sh -
        while read arg; do
            process_mod "$arg"
        done
    else
        process_mod "$1"
    fi
    shift
done

logger_debug "Fetch status: $fetch"

if $fetch; then

    cmd="sleep 120 && $DM_BIN/fetch.sh"

    logger_debug "Fetch command: $cmd"

    $dryrun && logger_debug "Dry run. Fetch command not run."

    ( ! $dryrun && eval $cmd ) &
fi
