#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0

This script updates a person's details from their local dmrc file to the shared
people file.

OPTIONS:

    -h  Print this help message.
EOF
}

while getopts "h" options; do
  case $options in

    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

# Resource dmrc file in case variables were reset by env.sh
source $HOME/.dm/dmrc || exit 1

# Make sure we have a username
if [[ ! "$USERNAME" ]]; then
    echo "ERROR: USERNAME not defined. Unable to identify user." >&2
    exit 1
fi

# Make sure we have a people file.

if [[ ! "$DM_PEOPLE" ]]; then
    echo "ERROR: DM_PEOPLE not defined. Unable to access people file." >&2
    exit 1
fi

if [[ ! -e $DM_PEOPLE ]]; then
    echo "ERROR: File not found: $DM_PEOPLE" >&2
    exit 1
fi

# Access detail line
# Eg 1,JK,jimk,Jim Karsten,jimkarsten@gmail.com,jimkarsten+jabber@gmail.com,5195042188@pcs.rogers.com,jimkarsten+input@gmail.com,dtjimk
detail_line=$(grep "[0-9]\+,[A-Z]\+,$USERNAME," $DM_PEOPLE)
if [[ ! "$detail_line" ]]; then
    echo "ERROR: Unable to find line in people file $DM_PEOPLE for username $USERNAME." >&2
    exit 1
fi

id=$(echo "$detail_line" | grep -o '^[0-9]\+')

# Double check that the id's match. We don't want to clobber the wrong record.
if [[ "$id" != "$DM_PERSON_ID" ]]; then
    echo "ERROR: Id from people file does not match DM_PERSON_ID. Aborting." >&2
    exit 1
fi

new_line="$DM_PERSON_ID,$DM_PERSON_INITIALS,$DM_PERSON_USERNAME,$DM_PERSON_NAME,$DM_PERSON_EMAIL,$DM_PERSON_JABBER,$DM_PERSON_PAGER,$DM_PERSON_INPUT,$DM_PERSON_SERVER"

tmpfile1=$(__tmp_file)
tmpfile2=$(__tmp_file)

# Copy all but header line to tmp file.
tail -n +2 $DM_PEOPLE > $tmpfile1

# Delete the old line and append new line
sed -i -e "/^$DM_PERSON_ID,/d" $tmpfile1
echo "$new_line" >> $tmpfile1

# Add header and append sorted details
head -1 $DM_PEOPLE > $tmpfile2
sort $tmpfile1 >> $tmpfile2

# Replace people file with new version
cp $tmpfile2 $DM_PEOPLE
