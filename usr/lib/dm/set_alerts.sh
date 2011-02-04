#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh
_loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh
_loaded_alert 2>/dev/null || source $DM_ROOT/lib/alert.sh

usage() {

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
    logger_debug "Getting contents of old who file: $who_file"

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

    if [[ -z $object ]]; then
        logger_debug "Unable to get object of old who file."
        return
    fi
    logger_debug "Object: $object"

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
    logger_debug "Parsing line: $line"

    local init=$(echo $line | awk '{print $1}' | grep -E '[A|D|M]')
    if [[ -z $init ]]; then
        logger_debug "Line is not A,D or M. Ignoring."
        return
    fi
    local who_file=$(echo $line | awk '{print $2}')
    logger_debug "Who file: $who_file"
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

    if [[ -z $alert ]]; then
        logger_debug "No alert."
        return
    fi

    logger_debug "Alert $alert"
    local mod_id=$(echo $who_file | awk -F'/' '{print $2}')

    # If mod is on hold do not create an alert. The take_off_hold.sh
    # will create the alert at that time.
    local status=$($DM_BIN/hold_status.sh $mod_id | awk '{print $5}')
    [[ "$status" == 'on_hold' ]] && return

    create_alert $alert $mod_id
    return
}


input_file=
verbose=

while getopts "hvi:" options; do
  case $options in

    i ) input_file=$OPTARG;;
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

# Git commands require we are in the repo directory
cd $DM_ROOT

if [[ -n $input_file ]]; then
    logger_debug "Parsing file: $input_file"
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

