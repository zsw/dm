#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() { cat << EOF
usage: $script [OPTIONS]

Purge alert files.
    -a AGE  Age. Default 1 month.
    -h      Print this help message.

EXAMPLES:
    $script                  # Purge alerts aged one month or older.
    $script -a "1 week"      # Purge alerts aged one week or older.
    $script -a "25 days"     # Purge alerts aged 25 days or older.

NOTES:
    If the -a age option is provided, alerts older than the provided age
    will be purged. The age option must be compatible with the date
    command. Test an age option using the following command.

        date --date="<AGE>"

EOF
}

_options() {
    args=()
    age="1 month"

    while [[ $1 ]]; do
        case "$1" in
            -a) shift; age=$1    ;;
            -h) _u; exit 0        ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0        ;;
             *) args+=( "$1" ) ;;
        esac
        shift
    done

     (( ${#args[@]} > 0 )) && { _u; exit 1; }
}

_options "$@"

limit=$(date --date="-${age}" "+%s")
[[ ! $limit ]] && __me "unable to determine purge age limit. Aborting."

alert_dir=$DM_USERS/alerts
tmpfile=$(__tmp_file)

for f in "$alert_dir"/*; do
    if [[ -f $f ]]; then
        sort "$f" | awk -v limit=$limit '$1 > limit {print}' > "$tmpfile"
        cp "$tmpfile" "$f"
    fi
done
