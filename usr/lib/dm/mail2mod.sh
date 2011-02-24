#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_ripmime 2>/dev/null || source $DM_ROOT/lib/ripmime.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 /path/to/maildir_file

This script converts a maildir email file to a mod. If successful it prints
the id of the mod created.

OPTIONS:

   -h      Print this help message.

EXAMPLE:

    $0 ~/.mail/inbox/cur/1231774030.26974_0.dtjimk:2,S

NOTES:

    The path can be absolute or relative.

    The email is converted into a mod as follows

        email subject  => mod description
        email body     => mod notes
        attachments    => \$DM_FILES/attachments
        \$DM_PERSON_INITIALS => mod who
EOF
}


#
# do_attachment
#
# Sent: file
# Return: nothing
# Purpose:
#
#   Attach file to mod.
#
function do_attachment {

    local file=$1

    [[ ! $file ]] && return

    local files_dir="$DM_FILES/attachments"
    local attach_dir="$DM_MODS/$mod/attachments"

    mkdir -p $files_dir;
    mkdir -p $attach_dir;

    local base=${file##*/}

    # Ensure the file doesn't clobber existing file.
    # Append .x extension as needed.

    local count=0
    while test -e "$files_dir/$base"; do
        count=$(( $count + 1))
        base="${base}.$count"
    done

    mv $file $files_dir/$base

    ln -snf $files_dir/$base $attach_dir/$base

    return
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

if [ $# -lt 1 ]; then
    _u
    exit 1
fi

file=$1;

if [[ ! -r $file ]]; then
    echo "Unable to read file $file" >&2
    exit 1
fi

mod=$("$DM_BIN/create_mods.sh" -b | awk '{print $3}')

if [[ ! $mod ]]; then
    echo "Error: Unable to get id of mod" >&2
    exit 1
fi

"$DM_BIN/assign_mod.sh" -m "$mod" "$DM_PERSON_INITIALS"

notes=$DM_MODS/$mod/notes
descr=$DM_MODS/$mod/description

cat $file | grep '^Subject: ' | head -1 | sed -e "s/Subject: //g" > $descr

ripmime_files_cat "$file" >> $notes

for attachment in $(ripmime_attachments "$file"); do
    do_attachment "$attachment"
done

#echo 'Hello '
# Add X-DM-Mod-Id header to email file.
sed -i -e "s/\(From:.*\)/\1\nX-DM-Mod-Id: $mod/" $file

echo $mod
