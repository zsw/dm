#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null  || . $DM_ROOT/lib/attributes.sh
__loaded_hold 2>/dev/null        || . $DM_ROOT/lib/hold.sh
__loaded_lock 2>/dev/null        || . $DM_ROOT/lib/lock.sh
__loaded_log 2>/dev/null         || . $DM_ROOT/lib/log.sh
__loaded_person 2>/dev/null      || . $DM_ROOT/lib/person.sh
__loaded_tmp 2>/dev/null         || . $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() { cat << EOF
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
# _clean_hold
#
# Sent: name of hold file
# Return: nothing
# Purpose:
#
#   Clean the hold file of a mod.
#
_clean_hold() {
    local crontab hold_file timestamp

    hold_file=$1

    [[ ! $hold_file ]] && return

    # Ignore files with git conflict markers. Processing them may cause
    # foo. Eg, the user may be editing the file fixing the conflict or
    # the hold time may get commented out.

    has_conflict_markers "$hold_file" && return

    # Remove leading and trailing whitespace from each line
    sed -i -e 's/^[ \t]*//;s/[ \t]*$//' "$hold_file"

    # Remove all trailing blank lines at end of file
    sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$hold_file"

    # Comment all uncommented lines but the last
    sed -i -e '$!s/^\([^#]\)/#\1/' "$hold_file"

    # Validate timestamp
    crontab=$(tail -1 "$hold_file" | grep -v '^#')
    [[ ! $crontab ]] && return

    timestamp=$(hold_as_yyyy_mm_dd_hh_mm_ss "$crontab")

    if ! date -d "$timestamp" &>/dev/null; then
        __me "Invalid hold time $timestamp in hold file $hold_file"
    fi
}
#
# _print_messages
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Print messages stored in the messages file to stdout.
#
_print_messages() {
    local previous_printed i type id msg indented remains printing

    [[ ! -e $message_file ]] && return

    unset previous_printed
    i=0
    while IFS="" read -r line; do
        # Break line into components
        # Eg  mod|11111|ERROR: Invalid mod
        # type = 'mod'
        # id = '11111'
        # msg = 'ERROR: Invalid mod'

        # An indented line is assumed a message
        unset indented
        if grep -q '^    ' <<< "$line" ; then
            indented=1
            msg="$line"
        else
            type=${line%%|*}
            remains=${line#*|}
            id=${remains%%|*}
            msg=${remains#*|}
        fi

        # Should we be printing the line?
        printing=1
        if [[ ! $indented ]]; then
            if [[ $who_initials && $type == mod ]]; then
                who=$(attribute "$id" 'who')
                #if [[ $who && $who != $who_initials ]] && unset printing previous_printed
                if [[ -n $who && $who != $who_initials ]]; then
                    logger_debug "Not reporting mod $id, assigned to $who"
                    unset printing previous_printed
                fi
            fi
        else
            printing=$previous_printed
        fi

        # Print the line if applicable
        if [[ $printing ]]; then
            if [[ ! $indented ]]; then
                ((i += 1))
                if (( $i == 1 )); then
                    echo "Messages:"
                    echo ""
                fi
                echo "${i}. $type $id - $msg"
                previous_printed=1
            else
                echo "  $line"
            fi
        fi
    done < "$message_file"

    (( $i > 0 )) && echo ""
}


#
# _run_checks
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
_run_checks() {
    local work_file msg_file

    # Create some temp files
    work_file=$(tmp_file)
    msg_file=$(tmp_file)


    # Mods
    # ----

    logger_debug "Looking for mods not in dependency tree or flagged improperly."
    invalids=$(for i in "$DM_MODS"/*; do i=${i##*/}; grep -rqP "\s*\[ \] $i\b" "$DM_TREES"/* || echo "$i"; done)
    for invalid in $invalids; do
        if grep -rqP "\s*\[x\] 0*${invalid}\b" "$DM_TREES"/*; then
            echo "mod|$invalid|WARNING: Mod does not appear to be flagged undone properly." >> "$message_file"
            echo "    Update tree with this command: $DM_BIN/format_mod_in_tree.sh \"$invalid\" " >> "$message_file"
        else
            echo "mod|$invalid|ERROR: Mod is not done but not found in any dependency tree." >> "$message_file"
        fi
    done

    logger_debug "Looking for archived mods not in dependency tree or flagged improperly."
    invalids=$(for i in "$DM_ARCHIVE"/*; do i=${i##*/}; grep -rqP "\s*\[x\] $i\b" "$DM_TREES"/* || echo "$i"; done)
    for invalid in $invalids; do
        if grep -rqP "\s*\[ \] 0*${invalid}\b" "$DM_TREES"/*; then
            echo "mod|$invalid|WARNING: Mod does not appear to be flagged undone properly." >> "$message_file"
            echo "    Update tree with this command: $DM_BIN/format_mod_in_tree.sh \"$invalid\" " >> "$message_file"
        else
            echo "mod|$invalid|ERROR: Mod is not done but not found in any dependency tree." >> "$message_file"
        fi
    done

    logger_debug "Looking for mods found in both the mods and archive directory."
    dupes=$(for i in "$DM_MODS"/* "$DM_ARCHIVE"/*; do echo "${i##*/}"; done | sort | uniq -d)
    for dupe in $dupes; do
        echo "mod|$dupe|ERROR: Mod found in both mods and archive subdirectories." >> $message_file
    done

    logger_debug "Syntax checking dependency tree."
    while read -r -d ' ' tree ; do
        tree_file=$("$DM_BIN/tree.sh" "$tree")
        msg=$(cat "$tree_file" | "$DM_BIN/dependency_schema.pl" "$DM_ROOT" 2>&1)
        [[ $msg ]] && echo "tree|$tree|$msg" >> "$message_file"
    done < "$DM_USERS/current_trees"


    logger_debug "Looking for mods found in more than one tree."
    cp /dev/null "$work_file"
    # Get a list of all mod ids found in all trees
    cut -c 5-10 <(grep -hrE '^[ ]*\[( |x)\] [0-9]{5}' "$DM_TREES"/* | sed -e 's/^[ \t]\+//') >> "$work_file"

    # Report duplicates
    while read -r d; do
        echo "mod|$d|WARNING: Mod found more than once in trees." >> "$message_file"
        grep -sr  "\[.\] $d" "$DM_TREES"/* | sed "s/^/   /" >> "$message_file"
    done < <(sort "$work_file" | uniq -d)

    logger_debug "Searching for phantom sed files"

    shopt -s globstar
    for file in "$DM_ROOT"/**/sed*; do
        [[ ! $file =~ sed.txt$ ]] && echo "other||WARNING: Temporary sed file found: $file" >> "$message_file"
    done
    shopt -u globstar

    logger_debug "Looking for mods in personal trees assigned to another."
    # Ensure every mod in a personal tree is assigned to that person.
    saveIFS=$IFS
    IFS=$'\n'
    # Browse all mods except those in main tree
    records=( $(find "$DM_MODS/" -maxdepth 1 -mindepth 1 | \
                   "$DM_BIN/format_mod.sh" -t sub  "%w %t %i" 2>/dev/null | sort | \
                   awk '$2 != "main" && $2 != "projects"') )
    IFS=$saveIFS
    unset prev_initials
    unset prev_username
    for i in ${!records[@]}; do

        fields=( ${records[$i]} )
        if [[ ${#fields[@]} != 3 ]]; then
            # invalid record
            mod=$(sed -e 's/^[ \t]\+//' <<< "${records[$i]}")       # Strip leading whitespace
            echo "mod|$mod|ERROR: Personal tree check, invalid mod" >> "$message_file"
            continue
        fi

        # The array fields has the following elements
        # 0 - who initials
        # 1 - tree path
        # 2 - mod id

        username_from_path=${fields[1]%%/*}
        username_from_initials=$prev_username

        if [[ $prev_initials != ${fields[0]} ]]; then
            username_from_initials=$(person_attribute username initials "${fields[0]}")
        fi

        if [[ $username_from_path != $username_from_initials ]]; then
            echo "mod|${fields[2]}|ERROR: Mod from ${fields[1]} assigned to ${fields[0]} not $username_from_path." >> $message_file
            echo "    Move mod to a shared tree, eg main?" >> "$message_file"
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
    for mod in "$DM_MODS"/* "$DM_ARCHIVE"/*; do
        mod_id=${mod##*/}
        for file in description notes who; do
            [[ ! -e $mod/$file ]] && echo "mod|$mod_id|ERROR: File $mod_id/$file not found." >> "$message_file"
        done
    done


    # Reusable Mods
    # -------------

    logger_debug "Looking for ids not found in mods/archive or reusable mods."

    # For each person, get a sequence of ids from the first id in their range
    # to their next_mod_id. For each id in the list there should exist a mod
    # either in the mods/archive directories or in a reusable_ids files. Report
    # any that don't.
    # Also for each id of an existing mod in mods/archive directories and in
    # reusable_ids files the id should fall within a valid range of ids
    # assigned to a person. Report any that don't.
    # compare_list = list of ids in all users' ranges
    # mod_id_list  = list of ids in mods/archives and reusable_ids
    unset compare_list
    while read -r start_id end_id person_id; do
        person_id=${person_id/x/}
        username=$(person_attribute username id $person_id)
        [[ ! -e $DM_ROOT/users/$username/mod_counter ]] && continue
        touch $DM_ROOT/users/$username/reusable_ids
        mod_counter=$(< "$DM_ROOT/users/$username/mod_counter")
        start=10#$start_id
        end=$mod_counter
        (( $mod_counter > 10#$end_id )) && end=10#$end_id   ## 10# removes leading zeros
        list=$(for ((i=$start; i<=$end; i++)); do printf "%05d\n" $i; done)
        if [[ $compare_list ]]; then
            compare_list="$compare_list\n$list"
        else
            compare_list="$list"
        fi
    done < <(awk -F",[ \t]*" '/^[0-9]+/ {print $1,$2,$3}' "$DM_IDS")

    mod_id_list=$(cat "$DM_ROOT"/users/*/reusable_ids <(for i in "$DM_MODS"/* "$DM_ARCHIVE"/*; do echo "${i##*/}"; done))

    while read -r invalid; do
        echo "mod|$invalid|ERROR: Mod exists but is not associated with a person." >> "$message_file"
    done < <(comm -1 -3 <(echo -e "$compare_list" | sort) <(sort <<< "$mod_id_list"))

    while read -r invalid; do
        echo "mod|$invalid|ERROR: Mod does not exist in $DM_MODS, $DM_ARCHIVE or $DM_ROOT/users/USERNAME/reusable_ids." >> "$message_file"
    done < <(comm -2 -3 <(echo -e "$compare_list" | sort) <(sort <<< "$mod_id_list"))


    logger_debug "Looking for ids of reusable mods found in mods/archive or in trees."

    # Create space delimited string of ids
    mod_ids=$(for i in "$DM_MODS"/* "$DM_ARCHIVE"/*; do echo -n "${i##*/} "; done)
    while read -r reusable_id; do
        grep -qE "^\s*\[.\]\s*$reusable_id" "$DM_TREES"/* &&
            echo "mod|$reusable_id|ERROR: Reusable mod found in a tree." >> "$message_file"
        [[ $mod_ids =~ $reusable_id ]] &&
            echo "mod|$reusable_id|ERROR: Mod id found in $DM_ROOT/users/USERNAME/reusable_ids and is in $DM_MODS or $DM_ARCHIVE." >> "$message_file"
    done < <(cat "$DM_ROOT"/users/*/reusable_ids)


    logger_debug "Looking for duplicate reusable ids."

    while read -r reusable_id; do
        echo "mod|$reusable_id|ERROR: Id found multiple times in $DM_ROOT/users/USERNAME/reusable_ids" >> "$message_file"
    done < <(uniq -d <(sort "$DM_ROOT"/users/*/reusable_ids))


    # Groups
    # ------

    logger_debug "Looking for groups found in more than one tree."
    cp /dev/null "$work_file"
    # Get a list of all group ids found in all trees
    shopt -s globstar
    for t in trees/**; do
        [[ ! -d $t ]] && awk '/^[ ]*group [0-9]+/ {print $2}' "$t" >> "$work_file"
    done
    shopt -u globstar

    # Report duplicates
    while read -r d; do
        echo "group|$d|Group found more than once in trees." >> "$message_file"
        grep -sr  "group $d" "$DM_TREES"/* | sed "s/^/    /" >> "$message_file"
    done < <(sort "$work_file" | uniq -d)


    # Hold files
    # ----------

    logger_debug "Looking for expired or invalid hold files."

    # Only check hold files of active mods. The hold status of an
    # archived mod is irrelevant. If the mod were to be undoned, it
    # would immediately be taken off hold, resetting the hold file. If
    # there was still foo, it would then get reported by this script.
    # Not checking archive mods will increase performance dramatically.

    local crontab stripped mod_id clean_msg timestamp status
    for hold in "$DM_MODS"/*/hold; do
        crontab=$(tail -1 "$hold" | grep -v '^#')
        [[ ! $crontab ]] && continue
        stripped=${hold%/*}
        mod_id=${stripped##*/}
        clean_msg=$(_clean_hold "$hold" 2>&1)
        timestamp=$(hold_timestamp "$mod_id" 2>/dev/null)
        status=$(hold_timestamp_status "$timestamp")
        if [[ $clean_msg || $status != on_hold ]]; then
            echo "mod|$mod_id|ERROR: Mod hold file $hold"  >> "$message_file"
            if [[ $clean_msg ]]; then
                echo "    $clean_msg" >> "$message_file"
            else
                echo "    Mod may not have been taken off hold properly, hold status: $status" >> "$message_file"
                echo "    $crontab" >> "$message_file"
            fi
        fi
    done

    # Cleanup
    rm "$msg_file"
    rm "$work_file"

    logger_debug "Run checks complete."
}


_options() {
    # set defaults
    args=()
    unset verbose
    unset user

    while [[ $1 ]]; do
        case "$1" in
            -u) shift; user=$1  ;;
            -v) verbose=true    ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} != 0 )) && { _u; exit 1; }
}

_options "$@"

__v && LOG_LEVEL=debug LOG_TO_STDERR=1

cd "$DM_ROOT"

message_file=$(tmp_file)
out_file=$(tmp_file)

unset who_initials
if [[ $user ]]; then
    who_initials=$(person_translate_who "$user")
    [[ ! $who_initials ]] && __me "Invalid user: $user"
fi

# Update the people file regardless
logger_debug "Updating people file from dmrc."
"$DM_BIN/person_update.sh"

_run_checks 2>&1  >> "$out_file"
_print_messages 2>&1 >> "$out_file"

if [[ -s $out_file ]]; then
    if __v; then
        # If verbose, print output to stdout
        cat "$out_file"
    else
        # If there was any output, send it in an email
        echo -e "To: $DM_PERSON_EMAIL\nSubject: Report from integrity.sh\n\n" | cat - "$out_file" | sendmail "$DM_PERSON_EMAIL"
    fi
fi
