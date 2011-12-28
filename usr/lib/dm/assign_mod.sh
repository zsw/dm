#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_alert 2>/dev/null || source $DM_ROOT/lib/alert.sh
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

mod_dir=$(__mod_dir "$mod_id")
[[ ! $mod_dir ]] && __me "Mod: $mod_id does not exist."
unset who_initials

[[ $owner && $user ]] && __me 'Use one of the -o or -u options, not both.'
[[ ! $owner && ! $user && ! $person ]] && __me 'Please indicate who to assign mod to.'

if [[ $owner ]]; then
    person_id=$(__original_who_id "$mod_id")
    who_initials=$(__person_attribute initials id "$person_id")
elif [[ $user ]]; then
    who_initials=$DM_PERSON_INITIALS
else
    who_initials=$(__person_translate_who "$person")
fi

[[ ! $who_initials ]] && __me 'Unable to determine who to assign the mod to.'

# Call __create_alert before changing the who file, so __create_alert can tell
# if the file has been assigned to someone else. (brought to you by taters)
__create_alert "$who_initials" "$mod_id"

echo "$who_initials" > "$mod_dir/who"
