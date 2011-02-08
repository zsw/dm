#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

usage() {

    cat << EOF

usage: $0 [OPTIONS]

Purge alert files.

OPTIONS:

    -a AGE  Age. Default 1 month.
    -v      Verbose.
    -h      Print this help message.

EXAMPLES:

    $0                  # Purge alerts aged one month or older.
    $0 -a "1 week"      # Purge alerts aged one week or older.
    $0 -a "25 days"     # Purge alerts aged 25 days or older.

NOTES:
    If the -a age option is provided, alerts older than the provided age
    will be purged. The age option must be compatible with the date
    command. Test an age option using the following command.

        date --date="<AGE>"

EOF
}

age="1 month"
verbose=

while getopts "a:hv" options; do
  case $options in

    a ) age=$OPTARG;;
    v ) verbose=1;;
    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

[[ -n $verbose ]] && LOG_LEVEL=debug
[[ -n $verbose ]] && LOG_TO_STDERR=1

logger_debug "Age: $age"

limit=$(date --date="-${age}" "+%s")
if [[ -z $limit ]]; then
    echo "ERROR: unable to determine purge age limit. Aborting." >&2
    exit 1
fi

logger_debug "Purging older than: $limit"

alert_dir="$DM_USERS/alerts"

tmpfile=$(tmp_file)
logger_debug "Temp file: $tmpfile"
for f in $(find $alert_dir -maxdepth 1 -mindepth 1 -type f); do
    logger_debug "Purging: $f"

    cat $f | sort | awk -v limit=$limit '{if ($1 > limit) {print}}' > $tmpfile
    cp $tmpfile $f
done
