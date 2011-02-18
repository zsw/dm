#!/bin/bash

#
# person.sh
#
# Library of functions related to person identities and attributes (eg
# id, name, email address, etc)
#

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

#
# person_attribute
#
# Sent: attribute (eg name)
#       key       (eg id)
#       value     (eg 1)
# Return: nothing (echo's the attribute value to stdout)
# Purpose:
#
#   Determine the person attribute value.
#
# Usage:
#
#   value=$(person_attribute attribute key value)
#
function person_attribute {

    attribute=$1
    key=$2
    value=$3

    [[ ! $attribute ]] && return
    [[ ! $key ]]       && return
    [[ ! $value ]]     && return

    logger_debug "attribute: $attribute, key: $key, value: $value"

    if [[ ! -e $DM_PEOPLE ]]; then
        echo "ERROR: Invalid people file $DM_PEOPLE: No such file or directory." >&2
        return
    fi

    if [[ ! -r $DM_PEOPLE ]]; then
        echo "ERROR: Unable to access people file $DM_PEOPLE: Permission denied." >&2
        return
    fi

    # Figure out the index of the key
    key_index=$(head -1 $DM_PEOPLE | awk -v attr="$key" 'BEGIN { FS = ",[ \t]*"} { split($0,a); for (x in a) if( a[x] == attr ) print x} ')

    if [ "$key_index" == "" ]; then

        logger_error "Key $key is not an people attribute."
        return;
    fi

    # Figure out the index of the requested attribute.
    attr_index=$(head -1 $DM_PEOPLE | awk -v attr="$attribute" 'BEGIN { FS = ",[ \t]*"} { split($0,a); for (x in a) if( a[x] == attr ) print x} ')

    if [ "$attr_index" == "" ]; then

        logger_error "Attribute $attribute is not a people attribute."
        return;
    fi

    # If the key and attribute indices are identical, then just echo
    # the key value.
    if [[ "$key_index" == "$attr_index" ]]; then
        echo $value
        return
    fi

    # Perform the look up on all incoming initials.
    cat $DM_PEOPLE | awk -v attr="$attr_index" -v key="$key_index" -v value="$value" 'BEGIN { FS = ",[ \t]*"} { split($0,a); if ( a[key] == value ) print a[attr]}'
}

#
# person_translate_who
#
# Sent: who   - can be number or string representing person's id, initials or
#               username
# Return: initials
# Purpose:
#
#   Transalate a who value into a person's initials.
#
# Notes:
#
#   Values are translated as follows.
#
#   If who is all digits, it is assumed to be a person's id.
#   If who is all uppercase, it is assumed to be a person's initials.
#   Otherwise, it is assumed to be a person's username.
#
function person_translate_who {

    local who=$1
    [[ ! $who ]] && return

    # Default to username
    local attribute='username'
    local all_digits=$(echo $who | grep '^[0-9]\+$')
    local all_uppers=$(echo $who | grep '^[A-Z]\+$')
    if [[ $all_digits ]]; then
        # Digits is an id
        attribute='id'
    elif [[ $all_uppers ]]; then
        # Uppercase is initials
        attribute='initials'
    fi

    logger_debug "Who: $who is translated as attribute: $attribute"

    local initials=$(person_attribute initials "$attribute" "$who")

    echo $initials
    return
}



# This function indicates this file has been sourced.
function _loaded_person {
    return 0
}

# Export all functions to any script sourcing this library file.
for function in $(awk '/^function / { print $2}' $DM_ROOT/lib/person.sh); do
    export -f $function
done
