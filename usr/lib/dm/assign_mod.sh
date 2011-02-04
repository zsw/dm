#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
_loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh

usage() {

    cat << EOF

usage: $0 [OPTIONS] <person_id|initials|username>

This script assigns a mod to a person.

OPTIONS:

    -d      Dry run. Mod is not assigned.
    -m ID   Id of mod assigned.
    -o      Assign mod to the original owner.
    -u      Assign mod to the current user.
    -v      Verbose.

    -h  Print this help message.

EXAMPLES:

    $0 JK           # Assign current mod to person with initials JK
    $0 1            # Assign current mod to person with id 1
    $0 jimk         # Assign current mod to person with username jimk

    $0 -m 12345 JK  # Assign mod 12345 to person with initials JK

    $0 -o           # Assign current mod to its original owner
    $0 -m 12345 -u  # Assign mod 12345 to the person running the script.

NOTES:

    If the -m options is not provided, the mod updated is the current one,
    ie. one indicated in \$HOME/.dm/mod

    If an argument is provided other than an option it is assumed to
    indicate the person to assign the mod to. The argument is interpreted
    as follows:

        Format      Interpretation

        digits      Id of person.
        uppercase   Initials of person
        *           Username of person


    For the -o option, the original owner is determined by looking up
    the mod id in the \$DM_ROOT/ids table. If the -o option is used with
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
# original_owner
#
# Sent: mod_id  - id of mod
# Return: initials
# Purpose:
#
#   Return the initials of the original owner of a mod.
#
function original_owner {

    local mod_id=$1
    [[ -z $mod_id ]] && return

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
    local person_id=$(awk -F',' -v mod=$mod_id '/^[0-9]/ {
            if (mod >= $1 && mod <= $2) {
                print $3;
                exit;
            }
        }' $DM_ROOT/ids | \
        tr -d 'x'
        )

    logger_debug "Mod id: $mod_id translates to person id: $person_id"
    [[ -z $person_id ]] && return

    local initials=$(person_attribute initials id $person_id)
    logger_debug "Person id: $person_id translates to initials: $initials"
    [[ -z $initials ]] && return

    echo $initials
    return
}


dryrun=
mod_id=$(cat $HOME/.dm/mod);
owner=
user=
verbose=

while getopts "dhm:ouv" options; do
  case $options in

    d ) dryrun=1;;
    m ) mod_id=$OPTARG;;
    o ) owner=1;;
    u ) user=1;;
    v ) verbose=1;;

    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

#  Decrements the argument pointer so it points to next argument.
#  $1 now references the first non option item supplied on the command line
#+ if one exists.
shift $(($OPTIND - 1))

[[ -n $verbose ]] && LOG_LEVEL=debug
[[ -n $verbose ]] && LOG_TO_STDERR=1

if [[ -z $mod_id ]]; then
    echo 'ERROR: Unable to determine id of mod to assign.' >&2
    exit 1
fi

mod_dir=$(mod_dir $mod_id)

logger_debug "Mod: $mod_id, mod_dir: $mod_dir"


who_initials=

if [[ -n $owner && -n $user ]]; then
    echo "ERROR: Use one of the -o or -u options, not both." >&2
    exit 1
fi
if [[ -z $owner && -z $user && -z $1 ]]; then
    echo "ERROR: Please indicate who to assign mod to."
    exit 1
fi

if [[ -n $owner ]]; then
    who_initials=$(original_owner $mod_id)
elif [[ -n $user ]]; then
    who_initials=$DM_PERSON_INITIALS
else
    who_initials=$(person_translate_who $1)
fi

if [[ -z $who_initials ]]; then
    echo "ERROR: Unable to determine who to assign the mod to." >&2
    exit 1
fi

logger_debug "Assigning mod: $mod_id to $who_initials"

if [[ -n $dryrun ]]; then
    echo "DRY RUN... mod not assigned." >&2
    exit 0
fi

echo $who_initials > $mod_dir/who
