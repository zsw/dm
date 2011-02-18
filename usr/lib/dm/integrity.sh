#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

_loaded_attributes 2>/dev/null  || . $DM_ROOT/lib/attributes.sh
_loaded_hold 2>/dev/null        || . $DM_ROOT/lib/hold.sh
_loaded_lock 2>/dev/null        || . $DM_ROOT/lib/lock.sh
_loaded_log 2>/dev/null         || . $DM_ROOT/lib/log.sh
_loaded_person 2>/dev/null      || . $DM_ROOT/lib/person.sh
_loaded_tmp 2>/dev/null         || . $DM_ROOT/lib/tmp.sh

script="${0##*/}"
script=${0##*/}
_u() {
    cat << EOF
usage: $script [ OPTIONS ]
This script runs integrity checks and dm system cleanup.

    -u user Only report messages for mods assigned to this user.
    -v      Verbose.
    -h      Print this help message.

NOTES:
    This script is intended to be cronned or run in the background.

    With the verbose option, messages from checks are printed to stdout.
    Without the verbose option, messages are emailed to the user.

    The -u option accepts a username, initials or an id. The argument is
    interpreted as follows:

        Format      Interpretation

        digits      Id of person.
        uppercase   Initials of person
        *           Username of person

EOF
}


#
# print_messages
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Print messages stored in the messages file to stdout.
#
print_messages() {

    [[ ! -e $message_file ]] && return

    local previous_printed=
    local i=0
    saveIFS=$IFS
    IFS="" # Prevent IFS from affecting whitespace
    while read line; do
        # Break line into components
        # Eg  mod|11111|ERROR: Invalid mod
        # type = 'mod'
        # id = '11111'
        # msg = 'ERROR: Invalid mod'

        local type id msg
        # An indented line is assumed a message
        local indented=
        if grep -q '^    ' <<< "$line" ; then
            indented=1
            msg="$line"
        else
            type=${line%%|*}
            local remains=${line#*|}
            id=${remains%%|*}
            msg=${remains#*|}
        fi

        # Should we be printing the line?
        local printing=1
        if [[ ! $indented ]]; then
            if [[ $who_initials ]]; then
                if [[ $type == 'mod' ]]; then
                    who=$(attribute $id 'who')
                    if [[ "$who" && "$who" != "$who_initials" ]]; then
                        printing=
                        previous_printed=
                    fi
                fi
            fi
        else
            printing=$previous_printed
        fi

        # Print the line if applicable
        if [[ $printing ]]; then
            if [[ ! $indented ]]; then
                let "i += 1"
                if (( $i == 1 )); then
                    echo "Messages:"
                    echo ""
                fi
                echo "$i." "$type $id - $msg"
                previous_printed=1
            else
                echo "  $line"
            fi
        fi
    done < $message_file

    IFS=$saveIFS

    (( $i > 0 )) && echo ""
    return
}


#
# run_checks
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run checks.
#
# Notes:
#
#   Messages are collected in a temporary file and then reviewed one by one to
#   see if they should be printed.
#
#       Message layout:
#           type|id|message
#               Subsequent lines are indented
#               Subsequent lines are indented
#
#       Examples:
#
#           mod|11111|ERROR: blah blah
#           mod|22222|ERROR: blah blah
#           mod|33333|ERROR: blah blah
#               Second line of message.
#           tree|main|ERROR: blah blah
#           tree|jimk/reminders|ERROR: blah blah
#               Second line of message.
#           group|111|WARNING: blahblahblah
#           other||WARNING: Temporary sed file ....
#
run_checks() {

    # Create some temp files
    local work_file=$(tmp_file)
    local msg_file=$(tmp_file)


    # Mods

    logger_debug "Looking for mods not in dependency tree or flagged improperly."
    invalids=$(for i in $(find $DM_MODS -maxdepth 1 -mindepth 1) ; do grep -rqP "\s*\[ \] ${i##*/}\b" $DM_TREES/* || echo ${i##*/} ; done)
    for invalid in $invalids; do
        flagged_done=$(grep -rqP "\s*\[x\] 0*${invalid}\b" $DM_TREES/* && echo $invalid)
        if [[ $flagged_done ]]; then
            echo "mod|$invalid|WARNING: Mod does not appear to be flagged undone properly." >> $message_file
            echo "    Update tree with this command: $DM_BIN/format_mod_in_tree.sh \"$invalid\" " >> $message_file
        else
            echo "mod|$invalid|ERROR: Mod is not done but not found in any dependency tree." >> $message_file
        fi
    done

    logger_debug "Looking for archived mods not in dependency tree or flagged improperly."
    invalids=$(for i in $(find $DM_ARCHIVE -maxdepth 1 -mindepth 1) ; do grep -rqP "\s*\[x\] ${i##*/}\b" $DM_TREES/* || echo ${i##*/} ; done)
    for invalid in $invalids; do
        flagged_undone=$(grep -rqP "\s*\[ \] 0*${invalid}\b" $DM_TREES/* && echo $invalid)
        if [[ $flagged_undone ]]; then
            echo "mod|$invalid|WARNING: Mod does not appear to be flagged undone properly." >> $message_file
            echo "    Update tree with this command: $DM_BIN/format_mod_in_tree.sh \"$invalid\" " >> $message_file
        else
            echo "mod|$invalid|ERROR: Mod is not done but not found in any dependency tree." >> $message_file
        fi
    done

    logger_debug "Looking for mods found in both the mods and archive directory."
    dupes=$(find $DM_MODS $DM_ARCHIVE -maxdepth 1 -mindepth 1 -type d | sed -e "s@$DM_MODS/@@g;s@$DM_ARCHIVE/@@g" | sort | uniq -d)
    for dupe in $dupes; do
        echo "mod|$dupe|ERROR: Mod found in both mods and archive subdirectories." >> $message_file
    done

    logger_debug "Syntax checking dependency tree."
    while read -d ' ' tree ; do
        tree_file=$($DM_BIN/tree.sh $tree)
        msg=$(cat $tree_file | $DM_BIN/dependency_schema.pl $DM_ROOT 2>&1)
        [[ $msg ]] && echo "tree|$tree|$msg" >> $message_file
    done < $DM_USERS/current_trees


    logger_debug "Looking for mods found in more than one tree."
    cp /dev/null $work_file
    # Get a list of all mod ids found in all trees
    cut -c 5-10 <(grep -hrE '^[ ]*\[( |x)\] [0-9]{5}' $DM_TREES/* | sed -e 's/^[ \t]\+//') >> $work_file

    # Report duplicates
    for d in $(sort $work_file | uniq -d); do
        cp /dev/null $msg_file
        echo "mod|$d|WARNING: Mod found more than once in trees." >> $msg_file
        grep -sr  "\[.\] $d" $DM_TREES/* | sed "s/^/   /" >> $msg_file
        cat $msg_file >> $message_file
    done

    logger_debug "Searching for phantom sed files"
    sed_files=$(find $DM_ROOT/ -name 'sed*' -not -name 'sed.txt')
    for file in $sed_files; do
        echo "other||WARNING: Temporary sed file found: $file" >> $message_file
    done

    logger_debug "Looking for mods in personal trees assigned to another."
    # Ensure every mod in a personal tree is assigned to that person.
    saveIFS=$IFS
    IFS=$'\n'
    # Browse all mods except those in main tree
    declare -a records=( $(find $DM_MODS/ -maxdepth 1 -mindepth 1 | \
                           $DM_BIN/format_mod.sh -t sub  "%w %t %i" 2>/dev/null| sort | \
                           awk '$2 != "main" && $2 != "projects" ') );
    IFS=$saveIFS
    prev_initials=
    prev_username=
    for i in ${!records[@]}; do

        declare -a fields=( ${records[$i]} )
        if [[ ${#fields[@]} != '3' ]]; then
            # invalid record
            mod=$(sed -e 's/^[ \t]\+//' <<< "${records[$i]}")       # Strip leading whitespace
            echo "mod|$mod|ERROR: Personal tree check, invalid mod" >> $message_file
            continue
        fi

        # The array fields has the following elements
        # 0 - who initials
        # 1 - tree path
        # 2 - mod id

        username_from_path="${fields[1]%%/*}"
        username_from_initials=$prev_username

        if [[ "$prev_initials" != "${fields[0]}" ]]; then
            username_from_initials=$(person_attribute username initials "${fields[0]}")
        fi

        if [[ "$username_from_path" != "$username_from_initials" ]]; then
            echo "mod|${fields[2]}|ERROR: Mod from ${fields[1]} assigned to ${fields[0]} not $username_from_path." >> $message_file
            echo "    Move mod to a shared tree, eg main?" >> $message_file
        fi

        prev_initials=${fields[0]}
        prev_username=$username_from_initials
    done


    # Look for mods missing component files, eg description or who files.

    # Mods missing components will not format properly. The format_mod.sh will
    # produce a message like:
    #
    #   cat: /root/dm/mods/10703/who: No such file or directory
    #

    logger_debug "Looking for mods with missing component files."
    for dm_dir in $DM_MODS $DM_ARCHIVE; do
        msg=$(find $dm_dir -maxdepth 1 -mindepth 1 -type d | $DM_BIN/format_mod.sh 2>&1 | grep '^cat')
        if [[ $msg ]]; then
            # Example message:
            #   cat: /root/dm/archive/10001/who: No such file or directory
            mod_id=$(grep -o '[0-9]\+' <<< "$msg")
            echo "mod|$mod_id|$msg" >> $message_file
        fi
    done


    # Groups

    logger_debug "Looking for groups found in more than one tree."
    cp /dev/null $work_file
    # Get a list of all group ids found in all trees
    for t in $(find $DM_TREES -type f); do
        awk '/^[ ]*group [0-9]+/ {print $2}' "$t" >> $work_file
    done

    # Report duplicates
    for d in $(sort $work_file | uniq -d); do
        cp /dev/null $msg_file
        echo "group|$d|Group found more than once in trees." >> $msg_file
        grep -sr  "group $d" $DM_TREES/* | sed "s/^/    /" >> $msg_file
        cat $msg_file >> $message_file
    done


    # Hold files

    logger_debug "Looking for expired or invalid hold files."

    # Only check hold files of active mods. The hold status of an
    # archived mod is irrelevant. If the mod were to be undoned, it
    # would immediately be taken off hold, resetting the hold file. If
    # there was still foo, it would then get reported by this script.
    # Not checking archive mods will increase performance dramatically.

    for hold in $(find $DM_MODS -maxdepth 2 -mindepth 2 -type f -name "hold"); do
        local crontab=$(tail -1 $hold | grep -v '^#')
        [[ ! "$crontab" ]] && continue
        local stripped=${hold%/*}
        local mod_id=${stripped##*/}
        local clean_msg=$($DM_BIN/hold_clean.sh -v $mod_id 2>&1)
        local timestamp=$(hold_timestamp "$mod_id" 2>/dev/null)
        local status=$(hold_timestamp_status "$timestamp")
        if [[ "$clean_msg" || "$status" != "on_hold" ]]; then
            cp /dev/null $msg_file
            echo "mod|$mod_id|ERROR: Mod hold file $hold"  >> $msg_file
            if [[ $clean_msg ]]; then
                echo "    $clean_msg" >> $msg_file
            else
                echo "    Mod may not have been taken off hold properly, hold status: $status" >> $msg_file
                echo "    $crontab" >> $msg_file
            fi
            cat $msg_file >> $message_file
        fi
    done

    # Cleanup
    rm $msg_file
    rm $work_file

    logger_debug "Run checks complete."
    return
}


verbose=
user=
while getopts "hu:v" options; do
  case $options in

    u ) user=$OPTARG    ;;
    v ) verbose=1       ;;
    h ) _u ; exit 0  ;;
    \?) _u ; exit 1  ;;
    * ) _u ; exit 1  ;;

  esac
done

shift $(($OPTIND - 1))

[[ $verbose ]] && LOG_LEVEL=debug
[[ $verbose ]] && LOG_TO_STDERR=1

cd $DM_ROOT

message_file=$(tmp_file)
out_file=$(tmp_file)

who_initials=
if [[ $user ]]; then
    who_initials=$(person_translate_who $user)
    if [[ ! $who_initials ]]; then
        echo "Invalid user $user" >&2
        _u
        exit 1
    fi
fi

# Update the people file regardless
logger_debug "Updating people file from dmrc."
$DM_BIN/person_update.sh

run_checks 2>&1  >> $out_file
print_messages 2>&1 >> $out_file

if [[ -s $out_file ]]; then
    if [[ $verbose ]]; then
        # If verbose, print output to stdout
        cat $out_file
    else
        # If there was any output, send it in an email
        echo -e "To: $DM_PERSON_EMAIL\nSubject: Report from integrity.sh\n\n" | cat -  $out_file | sendmail $DM_PERSON_EMAIL
    fi
fi
