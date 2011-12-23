#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() { cat << EOF
usage: $script [options]

Print the alert count to stdout.
    -p file People file.
    -h      Print this help message.

NOTES:
    By default the script gets people information from the usual
    $HOME/dm/people file. Use the -p option to use a different file.
    This can be convenient for testing with custom people data.

    Strategy

    For each remote user, from their remote server, get the alerts they
    have for the local user. For each alert that was logged after the last
    pull from that server, increment the alert count.
EOF
}

_options() {
    # set defaults
    args=()
    dm_people=$DM_PEOPLE

    while [[ $1 ]]; do
        case "$1" in
            -p) shift; dm_people=$1    ;;
            -h) _u; exit 0     ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0     ;;
             *) args+=( "$1" ) ;;
        esac
        shift
    done

     (( ${#args[@]} > 0 )) && { _u; exit 1; }
}

_options "$@"


# Validate people file
[[ ! -e $dm_people ]] && __me "Invalid people file $dm_people: No such file or directory."
[[ ! -r $dm_people ]] && __me "Unable to access people file $dm_people: Permission denied."

export DM_PEOPLE=$dm_people

tmpdir=$(__tmp_dir)
tmp_alert_dir=$tmpdir/alerts
mkdir -p "$tmp_alert_dir"

total=0
while read -r id username server; do

    [[ ! $username ]] && __mi "Unable to get username for person id=$id" >&2 && continue
    [[ $username == $USERNAME ]] && continue    # No need to alert yourself
    [[ ! $server ]] && continue

    remote_file=$tmp_alert_dir/$username
    url=http://$server/alerts/$username/$USERNAME
    error_msg=

    wget -q -O "$remote_file" "$url"
    case "$?" in
        0 ) ;;      # No problems occured.
        1 ) error_msg='Generic error code'  ;;
        2 ) error_msg='Parse error'         ;;
        3 ) error_msg='File I/O error'      ;;
        4 ) error_msg='Network failure'     ;;
        5 ) error_msg='SSL verification failure';;
        6 ) error_msg='Username/password authentication failure';;
        7 ) error_msg='Protocol errors'     ;;
        8 ) error_msg='Server issued an error response';;
        * ) error_msg='Unknown error'       ;;
    esac

    if [[ $error_msg ]]; then
        __mi "ERROR: wget failed, url $url" >&2
        __mi "wget returned exit status $exit_status, $error_msg" >&2
        __mi "Unable to get remote mod list for username: $username." >&2
        continue
    fi

    last_pull_secs=$(< "$DM_USERS/pulls/$username")
    # If the user has never pulled from the remote, all alerts
    # should be included in the count. Set to 0.
    [[ ! $last_pull_secs ]] && last_pull_secs=0

    # Count the number of lines where the timestamp is greater than the last pull time
    count=$(awk -v limit="$last_pull_secs" '$1 > limit {n++}; END {print n+0}' "$remote_file")

    total=$(( $total + $count ))
done < <(awk -F',[ \t]*' 'NR>1 {print $1,$3,$9}' "$DM_PEOPLE")

echo "$total"
