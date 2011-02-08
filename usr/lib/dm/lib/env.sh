#!/bin/bash

#
# env.sh
#
# Library file that sets the environment for the dm system.
#
# All dm system scripts need to source this file before running.
#

function _loaded_env {
    export -f _loaded_env
}

[[ -z $DM_ROOT ]] && unset DM_ROOT
: ${DM_ROOT?"environment variable not set or empty."}

[[ -z $USERNAME ]] && unset USERNAME
: ${USERNAME?"environment variable not set or empty."}

export DM_ARCHIVE=$DM_ROOT/archive
export DM_BIN=$DM_ROOT/bin
export DM_DOC=$DM_ROOT/doc
export DM_FILES=$DM_ROOT/files
export DM_IDS=$DM_ROOT/users/ids
export DM_MODS=$DM_ROOT/mods
export DM_PEOPLE=$DM_ROOT/users/people
export DM_TREES=$DM_ROOT/trees
export DM_TREES_ARCHIVE=$DM_ROOT/trees/archive
export DM_USERS=$DM_ROOT/users/$USERNAME

# The dev system cannot run properly with $USERNAME=root.
# Die if that is the case.

if [[ "$USERNAME" == "root" ]]; then
    echo "Dev system cannot run with USERNAME set to root." >&2
    exit 1
fi

#
# Set the PERSON_* variables based on $USERNAME env variable
#
save_ifs="$IFS"         # Save IFS value
IFS=$(echo)             # Change IFS to newline

#
# The following awk command converts the people header record and a
# detail record into variable assignments. Example:
# DM_PERSON_ID="1"
# DM_PERSON_NAME="Jim Karsten"
# DM_PERSON_USERNAME="jimk"
# etc.
#

eval $(awk -v username=$USERNAME 'BEGIN { FS = ",[ \t]*" }  $1 ~ /^id$/ && NR==FNR{ split($0,a); next; }  $3 ~ username && NR!=FNR{ for (i in a) print "export DM_PERSON_" toupper(a[i])"=\""$i"\""} ' $DM_PEOPLE $DM_PEOPLE )

IFS="$save_ifs"         # Restore IFS
