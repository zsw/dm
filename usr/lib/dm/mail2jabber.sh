#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_ripmime 2>/dev/null || source $DM_ROOT/lib/ripmime.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

usage() {

    cat << EOF

    usage: $0 /path/to/maildir/file

This script converts a maildir email file to a jabber message.

OPTIONS:

   -h      Print this help message.

EXAMPLE:

    $0 ~/.mail/inbox/cur/1231774030.26974_0.dtjimk:2,S

NOTES:

    The path can be absolute or relative.

    The email is converted into a jabber as follows

        email subject  => jabber body
        email body     => jabber body

    Assumptions and caveats.

    * Attachments on the email are ignored.
    * Assumes a weechat_fifo pipe exists.
EOF
}

while getopts "h" options; do
  case $options in

    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))


if [ $# -lt 1 ]; then
    usage
    exit 1
fi

file=$1;

if [[ ! -r "$file" ]]; then
    echo "Unable to read file $file" >&2
    exit 1
fi

subject=$(cat $file | grep '^Subject: ' | sed -e "s/Subject: //g")
body=$(ripmime_files_cat "$file" | head -5)

tmpfile=$(tmp_file)

cat > $tmpfile << EOT
....... mail2jabber message .......
$subject
"$body"
...................................
EOT

$DM_BIN/send_message.sh $tmpfile
