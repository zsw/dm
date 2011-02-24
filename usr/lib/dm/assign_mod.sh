#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
__loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh

script=${0##*/}
_u() { cat << EOF
usage: $script [OPTIONS] person_id|initials|username

This script assigns a mod to a person.
    -m ID   Id of mod assigned.
    -o      Assign mod to the original owner.
    -u      Assign mod to the current user.

    -h      Print this help message.

EXAMPLES:
    $script JK           # Assign current mod to person with initials JK
    $script 1            # Assign current mod to person with id 1
    $script jimk         # Assign current mod to person with username jimk

    $script -m 12345 JK  # Assign mod 12345 to person with initials JK

    $script -o           # Assign current mod to its original owner
    $script -m 12345 -u  # Assign mod 12345 to the person running the script.

NOTES:
    If the -m options is not provided, the mod updated is the current one,
    ie. one indicated in \$DM_USERS/current_mod

    If an argument is provided other than an option it is assumed to
    indicate the person to assign the mod to. The argument is interpreted
    as follows:

        Format      Interpretation

        digits      Id of person.
        uppercase   Initials of person
        *           Username of person


    For the -o option, the original owner is determined by looking up
    the mod id in the \$DM_ROOT/users/ids table. If the -o option is used with
    an argument indicating a person to assign to, the -o option takes
    precedence and the mod is assigned to the original owner.

    For the -u option, the current user is indicated by
    \$DM_PERSON_INITIALS. If the -u option is used with an argument
    indicating a person to assign to, the -u option takes precedence and
    the mod is assigned to the current user.

    If both the -o and -u option are provided the script exits with an
    error.
EOF
}

#
# _original_owner
#
# Sent: mod_id  - id of mod
# Return: initials
# Purpose:
#
#   Return the initials of the original owner of a mod.
#
_original_owner() {

    local initials mod_id person_id
    mod_id=$1
    [[ ! $mod_id ]] && return

    # Determine the person_id associated with the mod by looking up in
    # the range of ids in the ids table.

    # Command explanation
    # Line 1: Filter lines beginning with digit, ie screen out comments and
    #         header lines
    # Line 2: If the mod id is within the range...
    # Line 3: ... print the third column, ie the person id
    # Line 4: Exit immediately to restrict to one result of output.
    # Line 6: Filter ids file.
    # Line 7: Completed id ranges are indicated with an x prefix on the
    #         person id. Remove the x.
    person_id=$(awk -F',' -v mod=$mod_id '/^[0-9]/ {
            if (mod >= $1 && mod <= $2) {
                print $3;
                exit;
            }
        }' "$DM_IDS" | \
        tr -d 'x'
        )

    [[ ! $person_id ]] && return

    initials=$(person_attribute initials id "$person_id")
    [[ ! $initials ]] && return

    echo $initials
}

_options() {
    # set defaults
    args=()
    mod_id=$(< "$DM_USERS/current_mod")
    unset owner
    unset user

    while [[ $1 ]]; do
        case "$1" in
            -m) shift; mod_id=$1;;
            -o) owner=1         ;;
            -u) user=1          ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    if [[ ! $owner && ! $user ]]; then
        (( ${#args[@]} != 1 )) && { _u; exit 1; }
        person=${args[0]}
    fi
}

_options "$@"

[[ ! $mod_id ]] && __me 'Unable to determine id of mod to assign.'

mod_dir=$(mod_dir "$mod_id")
unset who_initials

[[ $owner && $user ]] && __me 'Use one of the -o or -u options, not both.'
[[ ! $owner && ! $user && ! $person ]] && __me 'Please indicate who to assign mod to.'

if [[ $owner ]]; then
    who_initials=$(_original_owner "$mod_id")
elif [[ $user ]]; then
    who_initials=$DM_PERSON_INITIALS
else
    who_initials=$(person_translate_who "$person")
fi

[[ ! $who_initials ]] && __me 'Unable to determine who to assign the mod to.'

echo "$who_initials" > "$mod_dir/who"
