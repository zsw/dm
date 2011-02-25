#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
__loaded_hold 2>/dev/null || source $DM_ROOT/lib/hold.sh
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh
__loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh
__loaded_alert 2>/dev/null || source $DM_ROOT/lib/alert.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0

Print mods that require alerts.

OPTIONS:

    -i FILE Read git status input from this file.
    -v      Verbose.
    -h      Print this help message.

EXAMPLES:

    $ $0
    1271889061 12345
    1271889059 12344
    1271889025 12343
    1271889011 12322
    1271889004 12311

NOTES:
    The output format is a timestamp (seconds since epoch) and mod id
    separated by a space.

    The script uses the 'git status' command. It expects that a
    'git add . && git add -u' command has been issued.
EOF
}


#
# old_contents
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Return the contents of the old who file.
#
function old_contents {

    local who_file=$1
    __logger_debug "Getting contents of old who file: $who_file"

    # Sample output
    # $ git commit --dry-run  --verbose -- mods/10829/who
    # # On branch master
    # # Changes to be committed:
    # #   (use "git reset HEAD <file>..." to unstage)
    # #
    # #       modified:   mods/10829/who
    # #
    # diff --git a/mods/10829/who b/mods/10829/who
    # index 77bef84..65eb5f7 100644
    # --- a/mods/10829/who
    # +++ b/mods/10829/who
    # @@ -1 +1 @@
    # -JLB
    # +JK
    #                +-----+
    local object=$(git commit --dry-run  --verbose -- "$who_file" | \
        grep '^index ' | \
        tr '.' ' ' | \
        awk '{print $2}')

    if [[ ! $object ]]; then
        __logger_debug "Unable to get object of old who file."
        return
    fi
    __logger_debug "Object: $object"

    git cat-file -p $object
    return
}


#
# parse_line
#
# Sent: line to parse
# Return: nothing
# Purpose:
#
#   Parse line for alert.
#
function parse_line {

    local line=$1
    __logger_debug "Parsing line: $line"

    local init=$(echo $line | awk '{print $1}' | grep -E '[A|D|M]')
    if [[ ! $init ]]; then
        __logger_debug "Line is not A,D or M. Ignoring."
        return
    fi
    local who_file=$(echo $line | awk '{print $2}')
    __logger_debug "Who file: $who_file"
    local alert=
    case $init in
        A)  who=$(cat $who_file | tr -d -c 'A-Z')
            if [[ "$who" != "$DM_PERSON_INITIALS" ]]; then
                alert=$who
            fi
            ;;
        D)  old_who=$(old_contents $who_file)
            if [[ "$old_who" != "$DM_PERSON_INITIALS" ]]; then
                alert=$old_who
            fi
            ;;
        M)  who=$(cat $who_file | tr -d -c 'A-Z')
            if [[ "$who" != "$DM_PERSON_INITIALS" ]]; then
                alert=$who
            else
                old_who=$(old_contents $who_file)
                if [[ "$old_who" != "$DM_PERSON_INITIALS" ]]; then
                    alert=$old_who
                fi
            fi
            ;;
    esac

    if [[ ! $alert ]]; then
        __logger_debug "No alert."
        return
    fi

    __logger_debug "Alert $alert"
    local mod_id=$(echo $who_file | awk -F'/' '{print $2}')

    # If mod is on hold do not create an alert. The take_off_hold.sh
    # will create the alert at that time.
    local status=$(__hold_status $mod_id | awk '{print $5}')
    [[ "$status" == 'on_hold' ]] && return

    __create_alert $alert $mod_id
    return
}


input_file=
verbose=

while getopts "hvi:" options; do
  case $options in

    i ) input_file=$OPTARG;;
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

# Git commands require we are in the repo directory
cd $DM_ROOT

if [[ $input_file ]]; then
    __logger_debug "Parsing file: $input_file"
    who_lines=$(cat "$input_file")
else
    who_lines=$(git status -s | grep '/who$')
fi

saveIFS=$IFS
IFS=$'\n'
for line in $who_lines; do
    parse_line "$line"
done
IFS=$saveIFS

