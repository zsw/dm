#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

script=${0##*/}
_u() { cat << EOF
usage: $script

This script updates a person's details from their local dmrc file to the shared
people file.
    -h  Print this help message.
EOF
}

_options() {
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

# Re-source dmrc file in case variables were reset by env.sh
source $HOME/.dm/dmrc || exit 1

# Make sure we have a username
[[ ! $USERNAME ]] && __me "USERNAME not defined. Unable to identify user."

# Make sure we have a people file.
[[ ! $DM_PEOPLE ]] && __me "DM_PEOPLE not defined. Unable to access people file."

[[ ! -e $DM_PEOPLE ]] && __me "File not found: $DM_PEOPLE"

# Access detail line
# Eg 1,JK,jimk,Jim Karsten,jimkarsten@gmail.com,jimkarsten+jabber@gmail.com,5195042188@pcs.rogers.com,jimkarsten+input@gmail.com,dtjimk
detail_line=$(grep -P "[[:digit:]]+,[[:alpha:]]+,$USERNAME," "$DM_PEOPLE")
[[ ! $detail_line ]] && __me "Unable to find line in people file $DM_PEOPLE for username $USERNAME."

id=$(grep -oP '^[[:digit:]]+' <<< "$detail_line")

# Double check that the id's match. We don't want to clobber the wrong record.
[[ $id != $DM_PERSON_ID ]] && __me "Id from people file does not match DM_PERSON_ID. Aborting."

new_line="$DM_PERSON_ID,$DM_PERSON_INITIALS,$DM_PERSON_USERNAME,$DM_PERSON_NAME,$DM_PERSON_EMAIL,$DM_PERSON_JABBER,$DM_PERSON_PAGER,$DM_PERSON_INPUT,$DM_PERSON_SERVER"

sed -i "s/^$DM_PERSON_ID,.*/$new_line/" "$DM_PEOPLE"
