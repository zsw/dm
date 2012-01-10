#!/bin/bash

#
# person.sh
#
# Library of functions related to person identities and attributes (eg
# id, name, email address, etc)
#

__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

#
# __person_attribute
#
# Sent: attribute (eg name)
#       key       (eg id)
#       value     (eg 1)
#
# Return: nothing (echo's the attribute value to stdout)
#
# Purpose:
#   Determine the person attribute value.
#
# Usage:
#   value=$(__person_attribute attribute key value)
#
__person_attribute() {
    local attribute key value key_index attr_index

    attribute=$1
    key=$2
    value=$3

    [[ ! $attribute ]] && return
    [[ ! $key ]]       && return
    [[ ! $value ]]     && return

    __logger_debug "attribute: $attribute, key: $key, value: $value"

    if [[ ! -e $DM_PEOPLE ]]; then
        __mi "Invalid people file $DM_PEOPLE: No such file or directory." >&2
        return
    fi

    if [[ ! -r $DM_PEOPLE ]]; then
        __mi "Unable to access people file $DM_PEOPLE: Permission denied." >&2
        return
    fi

    # Figure out the index of the key
    key_index=$(awk -F",[[:blank:]]*" -v attr="$key" 'NR==1 { for (i=1; i<=NF; i++) if ($i == attr) print i}' "$DM_PEOPLE")
    if [[ ! $key_index ]]; then
        __logger_error "Key $key is not an people attribute."
        return
    fi

    # Figure out the index of the requested attribute.
    attr_index=$(awk -F",[[:blank:]]*" -v attr="$attribute" 'NR==1 { for (i=1; i<=NF; i++) if ($i == attr) print i}' "$DM_PEOPLE")
    if [[ ! $attr_index ]]; then
        __logger_error "Attribute $attribute is not a people attribute."
        return
    fi

    # If the key and attribute indices are identical, then just echo
    # the key value.
    if [[ $key_index == $attr_index ]]; then
        echo "$value"
        return
    fi

    # Perform the look up on all incoming initials.
    awk -F",[[:blank:]]*" -v attr="$attr_index" -v key="$key_index" -v value="$value" 'NR>1 { for (i=1; i<=NF; i++) if (i == key && $i == value)  print $attr}' "$DM_PEOPLE"
}


#
# __person_translate_who
#
# Sent: who   - can be number or string representing person's id, initials or
#               username
# Return: initials
#
# Purpose:
#   Transalate a who value into a person's initials.
#
# Notes:
#   Values are translated as follows.
#
#   If who is all digits, it is assumed to be a person's id.
#   If who is all uppercase, it is assumed to be a person's initials.
#   Otherwise, it is assumed to be a person's username.
#
__person_translate_who() {
    local who attribute all_digits all_uppers initials

    who=$1
    [[ ! $who ]] && return

    # Default to username
    attribute='username'
    [[ $who =~ ^[0-9]+$ ]] && attribute='id'
    [[ $who =~ ^[A-Z]+$ ]] && attribute='initials'

    __logger_debug "Who: $who is translated as attribute: $attribute"

    initials=$(__person_attribute initials "$attribute" "$who")

    echo "$initials"
}



# This function indicates this file has been sourced.
__loaded_person() {
    return 0
}

# Export all functions to any script sourcing this library file.
while read -r function; do
    export -f "${function%%(*}"         # strip '()'
done < <(awk '/^__*()/ {print $1}' "$DM_ROOT"/lib/person.sh)
