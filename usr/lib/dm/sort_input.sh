#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh


script=${0##*/}
_u() {

    cat << EOF

usage: echo mod_id | $0

This script sorts a mod created from an input based on its type.

OPTIONS:

    -d  Debug.
    -v  Verbose.
    -h  Print this help message.

EXAMPLE:

    echo 12345 | $0

NOTES:

    The mod type id determined by a leading single letter code in the
    mod description. Example description:

        d Fix bug in the sort_input.sh script.

    Mod types are sorted as follows. Codes are case insensitive.

    Code  Type            Action

    n     now             schedule now
    d     daily           postpone until tomorrow
    w     weekly          postpone until next sunday
    c     calendar        create calendar event
    g     grocery         create grocery list item
    k     knowledge base  store in kb [1]

    [1] The knowledge base feature is not operational at this time. # FIXME

    If the mod description does not have a code, or the type cannot be
    determined, the type 'now' is assumed.

    If the -d debug option is provided the script adds grocery items to
    the test server.
EOF
}


#
# create_calendar
#
# Sent: mod_id
# Return: nothing
# Purpose:
#
#   Create a calendar event from a mod.
#
function create_calendar {

    local mod_id=$1

    __logger_debug "Creating calendar, mod id: $mod_id"

    local mod_dir="$DM_MODS/$mod_id"
    local description="${mod_dir}/description"

    if [[ ! -r "$description" ]]; then
        echo "Unable to read description $description" >&2
        exit 1
    fi

    local tmpfile=$(tmp_file)
    local tmpfile_update="${tmpfile}.upd"

    local descr=$(cat $description | sed -e 's/^\s*c\s\+//')
    $DM_BIN/calendar_input_parse.pl "$descr" > $tmpfile

    # Parse the email body
    local notes=$(cat $mod_dir/notes | tr "\n" " ")
    echo "description: $notes" >> $tmpfile

    # Create a google calendar entry
    $DM_BIN/calendar_entry_update.py $tmpfile > $tmpfile_update

    local result=$(grep 'result: \w\+' $tmpfile_update)
    if [[ ! $result ]]; then
        echo "ERROR: calendar_entry_update.py returned no result." >&2
        echo "Calendar event may not be created properly" >&2
        exit 1
    fi

    return
}


#
# create_grocery
#
# Sent: mod_id
# Return: nothing
# Purpose:
#
#   Create a grocery item from a mod.
#
function create_grocery {


    local mod_id=$1

    __logger_debug "Creating grocery, mod id: $mod_id"

    local mod_dir="$DM_MODS/$mod_id"
    local description="${mod_dir}/description"

    if [[ ! -r "$description" ]]; then
        echo "Unable to read description $description" >&2
        exit 1
    fi

    local descr=$(cat $description | sed -e 's/^\s*g\s\+//')

    local url="$grocery_url/grocery_update__mp.cgi"

    post_data="employee_initials=$DM_PERSON_INITIALS"
    post_data="${post_data}&description=${descr}"
    post_data="${post_data}&status=a"

    __logger_debug "Calling wget: wget -q -O - --post-data=\"$post_data\" $url."

    wget -q -O - --post-data="$post_data" $url > /dev/null
    local exit_status=$?

    local error_msg=
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

    __logger_debug "wget exit status: $exit_status"
    __logger_debug "wget error message: $error_msg"

    if [[ "$error_msg" ]]; then
        echo "ERROR: wget returned exit status $exit_status, $error_msg" >&2
        echo "Grocery item add may not have succeeded." >&2
        exit 1
    fi

    __logger_debug "Creating grocery: complete"

    return
}

debug=
verbose=

while getopts "dhv" options; do
  case $options in

    d ) debug=1;;
    v ) verbose=1;;
    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

[[ $verbose ]] && LOG_LEVEL=debug
[[ $verbose ]] && LOG_TO_STDERR=1

v_flag=''
[[ $verbose ]] && v_flag='-v'
d_flag=''
[[ $dryrun ]] && v_flag='-d'

grocery_url="http://www.dtjimk.internal/groceries"
[[ $debug ]] && grocery_url="http://test.dtjimk.internal/groceries"

tmpdir=$(tmp_dir)
pipe_dir="${tmpdir}/pipes"
osd_pipe="$pipe_dir/osd"

main="main"
now="$DM_PERSON_USERNAME/now"
unsorted="$DM_PERSON_USERNAME/unsorted"

while read mod; do

    mod_dir="$DM_MODS/$mod"
    description="${mod_dir}/description"

    if [[ ! -r "$description" ]]; then
        echo "Unable to read description $description" >&2
        exit 1
    fi

    descr=$(cat $description)

    init=$(echo "$descr" | awk '{print $1}' | tr "[:upper:]" "[:lower:]")
    __logger_debug "init: $init"

    tree=
    reuse=

    case "$init" in
        c)  # calendar
            create_calendar $mod
            tree=$main
            reuse=1
            echo "Calendar event created."
            ;;

        d)
            # daily
            # postpone until tomorrow
            $DM_BIN/postpone.sh -m $mod "tomorrow 7am"
            tree=$unsorted
            ;;

        g)  # grocery
            create_grocery $mod
            tree=$main
            reuse=1
            echo "Grocery list: $grocery_url/groceries__mp.cgi"
            ;;

        k)
            # knowledge base
            # store in kb FIXME
            ;;

        w)
            # weekly
            # postpone until next sunday
            $DM_BIN/postpone.sh -m $mod "next sunday 7am"
            tree=$unsorted
            ;;

        *)
            # now (default)
            # if mod happens to be on hold, take it off hold
            $DM_BIN/take_off_hold.sh -f $mod

            # Alert using OSD
            message=$(printf "Received NOW input: Mod %s - %s" "$mod" "$descr")
            test -p $osd_pipe && echo "$message" >> $osd_pipe

            tree=$now
            ;;

    esac

    if [[ ! "$tree" ]]; then
        tree=$unsorted
    fi

    # Remove the mod from all other trees (in case mod is reused)
    rm_trees=$(find $DM_TREES/ -type f ! -name 'sed*' | xargs --replace grep -l  "\[.\] $mod"  {})

    if [[ $rm_trees ]]; then
        sed -i "/\[.\] $mod /d" $rm_trees
    fi

    # Append the mod line to the appropriate dependency tree
    echo "$mod_dir" | $DM_BIN/format_mod.sh "[ ] %i %d" >> $DM_TREES/$tree

    if [[ $reuse ]]; then
        __logger_debug "Flagging for reuse, mod $mod"
        "$DM_BIN/reuse_mod.sh" "$mod"
    fi

done
