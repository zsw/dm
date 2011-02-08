#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

usage() {

    cat << EOF

usage: $0 [OPTIONS] [mod_id mod_id ...]
       or
       echo mod_id | $0 [OPTIONS] -

This script does a mairix search for emails associated with mods.

OPTIONS:

    -h  Print this help message.

EXAMPLES:

    $0                  # Mairix search for emails associated with current mod.
    $0 12345 23456      # Mairix search for emails associated with mods 12345 and 23456.
    echo 12345 | $0 -   # Mairix search for emails associated with mod 12345.

NOTES:

    Mod ids can be provided through stdin or as arguments.
    To read the mod list from stdin, use the mod_id '-'.

    If a mod id is not provided the current one is used, ie. the one
    indicated in $DM_USERS/current_mod
EOF
}


#
# process_mod
#
# Sent: mod
# Return: nothing
# Purpose:
#
#   Process a mairix search on a mod.
#
function process_mod {

    mod=$1

    logger_debug "Mod: $mod"

    count=0

    # Determine the mail base directory from mairixrc base setting
    base=$(grep '^base=' $HOME/.mairixrc | awk -F'=' '{print $2}')

    # get list of mail file names with label
    for mail in $(grep -lsr "^X-DM-Mod-Id: $mod" ${base}/*)
    do

        # Mairix indexes by Message-ID
        # Convert the name of a mail file to a Message-ID.
        message_id=$(grep '^Message-ID' $mail | awk '{ print $2}' | tr -d '<>')

        logger_debug "mail: $mail, message_id: $message_id"

        # Use the -a augment option to append results
        a=
        [[ "$count" -gt "0" ]] && a="-a"

        mairix -t $a m:$message_id 2>/dev/null | grep '^Matched'

        count=$(( $count + 1 ))
    done

    echo "$mod"
}


while getopts "h" options; do
  case $options in

    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

mairix      # Index mail folders

[[ "$#" -eq "0" ]] && set -- $(< $DM_USERS/current_mod)

while [[ ! "$#" -eq "0" ]]; do
    if [ "$1" == "-" ]; then
        # eg echo 12345 | mairix_mod.sh -
        while read arg; do
            process_mod "$arg"
        done
    else
        process_mod "$1"
    fi
    shift
done
