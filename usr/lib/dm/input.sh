#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() { cat << EOF
usage: $script

This script permits the user to record input for the flat file dev
system.
    -h  Print this help message.

EXAMPLES:
    $script

NOTES:
    This script is a tool for the "Collect" phase of the Getting Things Done
    paradigm.
EOF
}


#
# _create_mod
#
# Sent: nothing
# Return: id of mod
# Purpose:
#
#   Create a mod and return its id.
#
_create_mod() {
    local mod

    mod=$("$DM_BIN/create_mods.sh" -b | awk '{print $3}')

    [[ ! $mod ]] && __me "Unable to get id of mod"
    "$DM_BIN/assign_mod.sh" -m "$mod" "$DM_PERSON_INITIALS"

    echo "$subject" > "$DM_MODS/$mod/description"
    echo "$description" > "$DM_MODS/$mod/notes"

    echo "$mod"
}


#
# _confirm
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Get confirmation from user.
#
_confirm() {
    reply=
    while [[ ! $reply ]]; do
        echo -n "Process input? (Y/n/e) "
        read reply

        # Default reply to 'y'
        [[ ! $reply ]] && reply='y'

        # Convert reply to lowercase
        reply=$(tr "[:upper:]" "[:lower:]" <<< "$reply")

        case "$reply" in
            y) action='create'  ;;
            n) action='abort'   ;;
            e) action='edit'    ;;
            *) reply=           ;;         # Get another reply
        esac
    done
}


#
# _preview
#
# Sent: subject
#       description
# Return: nothing
# Purpose:
#
#   Preview the mod created from the file.
#
_preview() {

    subject="$1"
    descripton="$2"

    echo
    echo "#-----------------------------"
    echo "Subject: $subject"
    echo "Description:"
    echo "$description"
    echo "#-----------------------------"
    echo
}


#
# _section
#
# Sent: file
# Return: nothing
# Purpose:
#
#   Determine the sections from the file.
#
_section() {
    file=$1

    # Explanation of awk command
    #  -F'[: ]+'    : Field separator on any number of semicolons or spaces.
    #  /^Sbjct:/    : Match only subject lines, ignore everything else.
    #  $1="";       : Remove the first column, ie 'Sbjct:'
    #  sub(...)     : Remove trailing spaces.
    subject=$(awk -F'[: ]+' '/^Sbjct:/ {$1=""; sub(/^ /,""); print}' "$file")

    # Explanation of awk command
    #  /^Sbjct:/... : Ignore subject lines
    #  /^Descr:/... : Same as in previous awk call
    #  {sub(...)}   : Remove trailing spaces.
    # Note: Leading spaces should not be removed from lines without a 'Sbjct:'
    # or 'Descr:' prefix. The spaces may be intended indentation.
    description=$(awk -F'[: ]+' '/^Sbjct:/ {next;}
         /^Descr:/ {$1=""; sub(/^ /,""); print; next}
         {sub(/[ \t]+$/, ""); print};' "$file")

    #
    # Mods created from an input email work better if they
    # have a description, so use the subject if a description
    # is not entered.
    #
    # One exception is the grocery inputs. They should remain
    # without a description.
    #

    if [[ ! $description ]]; then
        grocery=$(sed '/^\s*[gG]\s/!d' <<< "$subject")
        [[ ! $grocery ]] && description=$subject
    fi
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

file=$(__tmp_file)
echo -e "Sbjct: \nDescr: " > "$file"
cp "$file" "${file}".bak

action='edit'
unset subject
unset description

while [[ $action == edit ]]; do
    vim -f -c 'set ft=our_doc' "$file"
    # If _edit didn't add changes, assume user wants to abort
    if diff -q "$file" "${file}".bak >/dev/null; then
        action='abort'
        continue
    fi
    _section "$file"
    _preview "$subject" "$description"
    _confirm
done

if [[ $action == abort ]]; then
    __me "Aborting."
fi

mod=$(_create_mod)
if [[ $mod ]]; then
    if ! "$DM_BIN/sort_input.sh" <<< "$mod"; then
        __me "sort_input.sh for mod $mod failed.\n===> ERROR: Retry with: echo $mod | sort_input.sh"
    fi
fi

echo "Create mod: $mod"
exit 0
