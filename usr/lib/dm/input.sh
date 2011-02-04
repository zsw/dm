#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

usage() {

    cat << EOF

usage: $0

This script permits the user to record input for the flat file dev
system.

OPTIONS:

    -d  Dry run. Actions are not performed.
    -v  Verbose.

    -h  Print this help message.

EXAMPLES:

    $0

NOTES:

    This script is a tool for the "Collect" phase of the Getting Things Done
    paradigm.
EOF
}


#
# create_mod
#
# Sent: nothing
# Return: id of mod
# Purpose:
#
#   Create a mod and return its id.
#
function create_mod {

    [[ -n $dryrun ]] && echo "Dry run: create mod skipped" >&2
    [[ -n $dryrun ]] && return

    logger_debug "Checking for a reusable mod"

    # Reuse a mod if possible
    local mod=$($DM_BIN/reusable_mods.sh -u $DM_PERSON_USERNAME | head -1 | $DM_BIN/gut_mod.sh -)
    if [[ -n $mod ]]; then
        logger_debug "Reusing mod $mod"
        $DM_BIN/undone_mod.sh $mod
        logger_debug "Undoned mod $mod"
    fi
    logger_debug "Before create mod $mod"

    # Otherwise create a blank mod
    # create_mods.sh returns: [ ] 10028 Blank mod
    if [[ -z $mod ]]; then
        logger_debug "Creating a new mod"
        mod=$(echo "[$DM_PERSON_INITIALS] Blank mod" | $DM_BIN/create_mods.sh | awk '{print $3}')
        logger_debug "Created mod $mod"
    fi
    logger_debug "After create mod $mod"

    if [[ -z "$mod" ]]; then
        echo "Error: Unable to get id of mod" >&2
        exit 1
    fi

    logger_debug "Creating mod component files"
    logger_debug "description: $DM_MODS/$mod/description"
    logger_debug "notes: $DM_MODS/$mod/notes"
    # Escape double quotes and dollar signs
    echo "$subject" > "$DM_MODS/$mod/description"
    echo "$description" > "$DM_MODS/$mod/notes"

    logger_debug "Done mod component files"
    echo "$mod"
    logger_debug "echoed mod"
    return
}


#
# confirm
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Get confirmation from user.
#
function confirm {

    reply=
    while [[ -z "$reply" ]]; do

        echo -n "Process input? (Y/n/e) "
        read reply

        # Default reply to 'y'
        [[ -z "$reply" ]] && reply='y'

        # Convert reply to lowercase
        reply=$(echo $reply | tr "[:upper:]" "[:lower:]")

        case $reply in
            y) action='create';;
            n) action='abort';;
            e) action='edit';;
            *) reply=;;         # Get another reply
        esac

    done
}


#
# edit
#
# Sent: file - full path name of file to edit.
# Return: nothing
# Purpose:
#
#   Edit the file.
#
function edit {

    file=$1

    /usr/bin/vim -f -c "set ft=our_doc" $file
}


#
# preview
#
# Sent: subject
#       description
# Return: nothing
# Purpose:
#
#   Preview the mod created from the file.
#
function preview {

    subject="$1"
    descripton="$2"

    echo
    echo "#-----------------------------"
    echo "Subject: $subject"
    echo "Description:"
    echo "$description"
    echo "#-----------------------------"
    echo

    return;
}


#
# section
#
# Sent: file
# Return: nothing
# Purpose:
#
#   Determine the sections from the file.
#
function section {

    file=$1

    body=$(cat $file)

    # Extract subject, remove leading and trailing whitespace
    subject=$(echo "$body"     | grep '^Sbjct:'    | sed -e "s/Sbjct:\s*//" | sed 's/^[ \t]*//;s/[ \t]*$//')

    # Extract description, remove trailing whitespace
    description=$(echo "$body" | grep -v '^Sbjct:' | sed -e "s/Descr:\s*//" | sed 's/[ \t]*$//')

    #
    # Mods created from an input email work better if they
    # have a description, so use the subject if a description
    # is not entered.
    #
    # One exception is the grocery inputs. They should remain
    # without a description.
    #

    if [[ -z "$description" ]]; then

        grocery=$( echo "$subject" | sed '/^\s*[gG]\s/!d')
        [[ -z "$grocery" ]] && description=$subject
    fi

    return;
}


dryrun=
verbose=

while getopts "dhv" options; do
  case $options in
    d ) dryrun=1;;
    v ) verbose=1;;
    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

[[ -n $verbose ]] && LOG_LEVEL=debug
[[ -n $verbose ]] && LOG_TO_STDERR=1

v_flag=''
[[ -n $verbose ]] && v_flag='-v'
d_flag=''
[[ -n $dryrun ]] && d_flag='-d'

[[ -n $dryrun ]] && logger_debug 'Dry run: Actions will not be performed.'

file=$(tmp_file)
echo -e "Sbjct: \nDescr: " > $file
cp $file ${file}.bak

action='edit'
subject=
description=

while [[ $action == 'edit' ]]; do
    edit $file
    # If edit didn't add changes, assume user wants to abort
    diff -q $file ${file}.bak > /dev/null
    if (( $? == 0 )); then
        action='abort'
        continue
    fi
    section $file
    preview "$subject" "$description"
    confirm
done

if [[ "$action" == 'abort' ]]; then
    echo "Aborting."
    exit 1
fi

logger_debug "Creating mod"
mod=$(create_mod)
logger_debug "Created mod $mod"
if [[ -n $mod ]]; then
    logger_debug "Sorting mod"
    echo "$mod" | $DM_BIN/sort_input.sh $v_flag $d_flag
    if [[ "$?" != "0" ]]; then
        echo "ERROR: sort_input.sh for mod $mod failed." >&2
        echo "Retry with: echo $mod | sort_input.sh" >&2
        exit 1
    fi
fi

echo "Done."
exit 0
