#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
_loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

usage() { cat << EOF

usage: $0 [OPTIONS]

Print the alert count to stdout.

OPTIONS:

    -p file People file.
    -v      Verbose.
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

dm_people=$DM_PEOPLE
verbose=

while getopts "hp:v" options; do
  case $options in

    p ) dm_people=$OPTARG;;
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

logger_debug "dm_people: $dm_people"

# Validate people file
if [[ ! -e $dm_people ]]; then
    echo "ERROR: Invalid people file $dm_people: No such file or directory " >&2
    exit 1
fi

if [[ ! -r $dm_people ]]; then
    echo "ERROR: Unable to access people file $dm_people: Permission denied." >&2
    return
fi

export DM_PEOPLE="$dm_people"

wget_flag='-q'
[[ -n $verbose ]] && wget_flag='-v'

tmpdir=$(tmp_dir)
tmp_alert_dir="${tmpdir}/alerts"
mkdir -p $tmp_alert_dir

total=0
for id in $(cat $DM_PEOPLE | awk 'BEGIN { FS = ",[ \t]*"} { print $1}'); do
    # Skip the header record
    [[ "$id" == "id" ]] && continue
    username=$(person_attribute username id $id)
    if [[ -z "$username" ]]; then
        echo "ERROR: Unable to get username for person id=$id" >&2
        continue
    fi
    # No need to alert yourself
    [[ "$username" == "$USERNAME" ]] && continue

    server=$(person_attribute server id $id)
    if [[ -z "$server" ]]; then
        logger_warn "WARNING: Unable to get server for person username: $username"
        logger_warn "Unable to get alert count for person username: $username"
        continue
    fi

    logger_debug "$username Checking id:$id username:$username server:$server"

    remote_file="${tmp_alert_dir}/$username"

    url="http://$server/alerts/$username/$USERNAME"
    logger_debug "$username remote url: $url"
    logger_debug "$username wget: wget $wget_flag -O $remote_file $url"
    wget $wget_flag -O $remote_file $url
    exit_status=$?

    error_msg=
    case $exit_status in

        0 ) ;;      # No problems occured.
        1 ) error_msg='Generic error code';;
        2 ) error_msg='Parse error';;
        3 ) error_msg='File I/O error';;
        4 ) error_msg='Network failure';;
        5 ) error_msg='SSL verification failure';;
        6 ) error_msg='Username/password authentication failure';;
        7 ) error_msg='Protocol errors';;
        8 ) error_msg='Server issued an error response';;
        * ) error_msg='Unknown error'
            ;;
    esac

    if [[ -n "$error_msg" ]]; then
        logger_debug "$username wget exit status: $exit_status"
        logger_debug "$username wget error message: $error_msg"
        echo "ERROR: wget failed, url $url" >&2
        echo "wget returned exit status $exit_status, $error_msg" >&2
        echo "Unable to get remote mod list for username: $username." >&2
        continue
    fi

    pull_file="$DM_USERS/pulls/$username"
    logger_debug "$username pull file: $pull_file"
    last_pull_secs=$(cat $pull_file)
    if [[ -z $last_pull_secs ]]; then
        # If the user has never pulled from the remote, all alerts
        # should be included in the count. Set to 0.
        last_pull_secs=0
    fi
    logger_debug "$username last pull: $last_pull_secs"
    logger_debug "$username alerts file: $remote_file"

    # Instead of a loop, the following could have be simplified by
    # piping output into "wc -l" but then it wouldn't be possible to
    # debug each line of output.
    count=0
    saveIFS=$IFS
    IFS=$'\n'
    for line in $(cat $remote_file | awk -v limit=$last_pull_secs '{if ($1 > limit ) {print}}'); do
        logger_debug "$username alertable: $line"
        let count++
    done
    IFS=$saveIFS

    logger_debug "$username alert count: $count"

    total=$(( $total + $count ))
done

echo $total
