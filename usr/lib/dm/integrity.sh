#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null  || source $DM_ROOT/lib/attributes.sh
__loaded_hold 2>/dev/null        || source $DM_ROOT/lib/hold.sh
__loaded_log 2>/dev/null         || source $DM_ROOT/lib/log.sh
__loaded_person 2>/dev/null      || source $DM_ROOT/lib/person.sh

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
#
# Purpose:
#   Clean the hold file of a mod.
#
_clean_hold() {
    local crontab hold_file timestamp

    hold_file=$1
    [[ ! $hold_file ]] && return

    # Ignore files with git conflict markers. Processing them may cause
    # foo. Eg, the user may be editing the file fixing the conflict or
    # the hold time may get commented out.
    __has_conflict_markers "$hold_file" && return

    # Remove leading and trailing whitespace from each line
    sed -i -e 's/^[ \t]*//;s/[ \t]*$//' "$hold_file"

    # Remove all trailing blank lines at end of file
    sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$hold_file"

    # Comment all uncommented lines but the last
    sed -i -e '$!s/^\([^#]\)/#\1/' "$hold_file"

    # Validate timestamp
    crontab=$(tail -1 "$hold_file" | grep -v '^#')
    [[ ! $crontab ]] && return

    timestamp=$(__hold_as_yyyy_mm_dd_hh_mm_ss "$crontab")
    if ! date -d "$timestamp" &>/dev/null; then
        __me "Invalid hold time $timestamp in hold file $hold_file"
    fi
}
#
# _print_messages
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Print messages stored in the messages file to stdout.
#
_print_messages() {
    local previous_printed i type id msg indented remains printing

    [[ ! ${message_arr[@]} ]] && return

    i=0
    for line in "${message_arr[@]}"; do
        # Break line into components
        # Eg  mod|11111|ERROR: Invalid mod
        # type = 'mod'
        # id = '11111'
        # msg = 'ERROR: Invalid mod'

        # An indented line is assumed a message
        unset indented
        if grep -q '^    ' <<< "$line" ; then
            indented=1
            msg=$line
        elif grep -q '^===> ERROR:' <<< "$line"; then
            indented=1
            msg="$line"
            line="    $line"
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
                who=$(__attribute "$id" 'who')
                if [[ $who && $who != $who_initials ]]; then
                    __logger_debug "Not reporting mod $id, assigned to $who"
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
                (( $i == 1 )) && echo -e "\nMessages:\n"
                echo "${i}. $type $id - $msg"
                previous_printed=1
            else
                echo "  $line"
            fi
        fi
    done

    (( $i > 0 )) && echo ""
}


#
# _run_checks
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run checks.
#
# Notes:
#   Messages are collected in a temporary file and then reviewed one by one to
#   see if they should be printed.
#
#       Message layout:
#           type|id|message
#               Subsequent lines are indented
#               Subsequent lines are indented
#
#       Examples:
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

    # Mods
    # ----

    __logger_debug "Looking for undone mods not in the mods directory."
    while read -r invalid; do
        if [[ -d $DM_MODS/$invalid ]]; then
            message_arr+=( "mod|$invalid|ERROR: Mod exists in $DM_MODS but not found in any tree file or is marked as 'undone' in tree file." )
        else
            message_arr+=( "mod|$invalid|WARNING: Mod appears to be marked as 'undone' in tree file." )
            message_arr+=( "    To mark as 'done' run this command: $DM_BIN/format_mod_in_tree.sh \"$invalid\" " )
        fi
    done < <(comm -3 <(printf '%s\n' "${dm_mods_id[@]}" | sort) \
                     <(printf '%s\n' "${tree_id_undone[@]}" | sort))

    __logger_debug "Looking for done mods not in the archive directory."
    while read -r invalid; do
        if [[ -d $DM_ARCHIVE/$invalid ]]; then
            message_arr+=( "mod|$invalid|ERROR: Mod exists in $DM_ARCHIVE but not found in any tree file or is markked as 'done' in tree file." )
        else
            message_arr+=( "mod|$invalid|WARNING: Mod appears to be marked as 'done' in tree file." )
            message_arr+=( "    To mark as 'undone' run this command: $DM_BIN/format_mod_in_tree.sh \"$invalid\" " )
        fi
    done < <(comm -3 <(printf '%s\n' "${dm_archive_id[@]}" | sort) \
                     <(printf '%s\n' "${tree_id_done[@]}" | sort))

    __logger_debug "Looking for mods found in both the mods and archive directory."
    while read -r dupe; do
        message_arr+=( "mod|$dupe|ERROR: Mod found in both mods and archive subdirectories." )
    done < <(printf "%s\n" "${dm_mods_id[@]}" "${dm_archive_id[@]}" | sort | uniq -d)

    __logger_debug "Syntax checking of trees."
    while read -r tree ; do
        readarray -t arr < <("$DM_BIN/prioritize.sh" "$tree" >/dev/null)
        [[ ${arr[@]} ]] &&  message_arr+=( "tree|$tree|Syntax of tree file incorrect" ); message_arr+=( "${arr[@]}" )
    done < <(find "$DM_TREES/" -type f)

    __logger_debug "Looking for mods found in more than one tree."
    # Report duplicates
    while read -r d; do
        message_arr+=( "mod|$d|WARNING: Mod found more than once in trees." )
        readarray -O "${#arr[@]}" -t arr < <(grep -rP  "^ *\[.\] $d " "$DM_TREES"/* | sed "s/^/   /")
    done < <(printf '%s\n' "${tree_id_done[@]}" "${tree_id_undone[@]}" | sort | uniq -d)

    __logger_debug "Searching for phantom sed files"
    shopt -s globstar
    for file in "$DM_ROOT"/**/sed*; do
        [[ ! $file =~ sed.txt$ ]] && message_arr+=( "other||WARNING: Temporary sed file found: $file" )
    done
    shopt -u globstar

    __logger_debug "Looking for mods in personal trees assigned to another."
    # Ensure every mod in a personal tree is assigned to that person.
    for tree in "$DM_TREES"/*; do
        [[ $tree == *archive || $tree == *main || $tree == *magento ]] && continue
        initials=$(__person_attribute initials username "${tree##*/}")

        while read -r mod_id; do
            who=$(< "$DM_ROOT"/*/"$mod_id"/who)
            if [[ $who != $initials ]]; then
                message_arr+=( "mod|$mod_id|ERROR: 'who' file for mod $mod_id is set to $who but is in a tree belonging to ${tree##*/}" )
                message_arr+=( "    Move mod to a shared tree, eg main?" )
            fi
        done < <(grep -hrP '^ *\[( |x)\] [[:digit:]]{5} ' "$tree"/* | sed -e 's/^[ \t]\+//' | cut -c 5-9)
    done

    __logger_debug "Looking for mods with missing component files."
    # Look for mods missing component files, eg description or who files.
    # Mods missing components will not format properly. The format_mod.sh will
    # produce a message like:
    #
    #   cat: /root/dm/mods/10703/who: No such file or directory
    #
    for mod in "${dm_mods[@]}" "${dm_archive[@]}"; do
        [[ ! -e $mod/description && -e $mod/notes && -e $mod/who ]] &&
            for file in description notes who; do
                mod_id=${mod##*/}
                [[ ! -e $mod/$file ]] && message_arr+=( "mod|$mod_id|ERROR: File $mod_id/$file not found." )
            done
    done


    # Reusable Mods
    # -------------

    __logger_debug "Looking for ids not found in mods/archive or reusable mods."
    # For each person, get a sequence of ids from the first id in their range
    # to their next_mod_id. For each id in the list there should exist a mod
    # either in the mods/archive directories or in a reusable_ids file. Report
    # any ids that do not.
    # Also for each id of an existing mod in mods/archive directories and in
    # reusable_ids files the id should fall within a valid range of ids
    # assigned to a person. Report any that don't.
    # compare_list = list of ids in all users' ranges
    # mod_id_list  = list of ids in mods/archives and reusable_ids
    unset compare_list
    compare_list=()
    while read -r start_id end_id person_id; do
        person_id=${person_id/x/}
        username=$(__person_attribute username id "$person_id")
        [[ ! -e $DM_ROOT/users/$username/mod_counter ]] && continue
        touch "$DM_ROOT/users/$username/reusable_ids"
        mod_counter=$(< "$DM_ROOT/users/$username/mod_counter")
        start=10#$start_id
        end=$mod_counter
        (( $mod_counter > 10#$end_id )) && end=10#$end_id   ## 10# removes leading zeros
        readarray -O "${#compare_list[@]}" -t compare_list < <(for ((i=$start; i<=$end; i++)); do printf "%05d\n" "$i"; done)
    done < <(awk -F",[ \t]*" '/^[0-9]+/ {print $1,$2,$3}' "$DM_IDS")

    while read -r invalid; do
        if grep -qrP "^ *\[( |x)\] $invalid " "$DM_TREES"/*; then
            message_arr+=( "mod|$invalid|ERROR: Mod exists but is not associated with a person." )
        else
            message_arr+=( "mod|$invalid|ERROR: Mod does not exist in $DM_MODS, $DM_ARCHIVE or $DM_ROOT/users/USERNAME/reusable_ids." )
        fi
    done < <(comm -2 -3 <(printf '%s\n' "${compare_list[@]}" | sort) \
                        <(cat "$DM_ROOT"/users/*/reusable_ids <(printf '%s\n' "${dm_mods_id[@]}" "${dm_archive_id[@]}") | sort))

    __logger_debug "Looking for ids of reusable mods found in mods/archive or in trees."
    # Create space delimited string of ids
    mod_ids=$(printf "%s " "${dm_mods_id[@]}" "${dm_archive_id[@]}")
    while read -r reusable_id; do
        grep -qrP "^ *\[.\] $reusable_id " "$DM_TREES"/* &&
            message_arr+=( "mod|$reusable_id|ERROR: Reusable mod found in a tree." )
        [[ $mod_ids =~ $reusable_id ]] &&
            message_arr+=( "mod|$reusable_id|ERROR: Mod id found in $DM_ROOT/users/USERNAME/reusable_ids and is in $DM_MODS or $DM_ARCHIVE." )
    done < <(cat "$DM_ROOT"/users/*/reusable_ids)

    __logger_debug "Looking for duplicate reusable ids."
    while read -r reusable_id; do
        message_arr+=( "mod|$reusable_id|ERROR: Id found multiple times in $DM_ROOT/users/USERNAME/reusable_ids" )
    done < <(sort "$DM_ROOT"/users/*/reusable_ids | uniq -d)


    # Groups
    # ------

    __logger_debug "Looking for groups found in more than one tree."
    # Report duplicates
    while read -r d; do
        message_arr+=( "group|$d|Group found more than once in trees." )
        readarray -O "${#message_arr[@]}" -t message_arr < <(grep -srP  "group $d" "$DM_TREES"/* | sed "s/^/    /")
    done < <(printf '%s\n' "${tree_id_done[@]}" "${tree_id_undone[@]}" | sort | uniq -d)


    # Hold files
    # ----------

    __logger_debug "Looking for expired or invalid hold files."
    # Only check hold files of active mods. The hold status of an
    # archived mod is irrelevant. If the mod were to be undoned, it
    # would immediately be taken off hold, resetting the hold file. If
    # there was still foo, it would then get reported by this script.
    # Not checking archive mods will increase performance dramatically.

    local crontab mod_id clean_msg timestamp status
    for hold in "$DM_MODS"/*/hold; do
        crontab=$(tail -1 "$hold" | grep -v '^#')
        [[ ! $crontab ]] && continue
        mod_id=${hold%/*} mod_id=${mod_id##*/}
        clean_msg=$(_clean_hold "$hold" 2>&1)
        timestamp=$(__hold_timestamp "$mod_id" 2>/dev/null)
        status=$(__hold_timestamp_status "$timestamp")
        if [[ $clean_msg || $status != on_hold ]]; then
            message_arr+=( "mod|$mod_id|ERROR: Mod hold file $hold" )
            if [[ $clean_msg ]]; then
                message_arr+=( "    $clean_msg" )
            else
                message_arr+=( "    Mod may not have been taken off hold properly, hold status: $status" )
                message_arr+=( "    $crontab" )
            fi
        fi
    done

    __logger_debug "Run checks complete."
}


_options() {
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

message_arr=()
out_arr=()
dm_mods=( "$DM_MODS"/* )
dm_mods_id=( ${dm_mods[@]##*/} )
dm_archive=( "$DM_ARCHIVE"/* )
dm_archive_id=( ${dm_archive[@]##*/} )
#readarray -t tree_id < <(grep -hrP '^ *\[( |x)\] [[:digit:]]{5} ' "$DM_TREES"/* | sed -e 's/^[ \t]\+//' | cut -c 5-9 | sort)
readarray -t tree_id_undone < <(grep -hrP '^ *\[ \] [[:digit:]]{5} ' "$DM_TREES"/* | sed -e 's/^[ \t]\+//' | cut -c 5-9)
readarray -t tree_id_done < <(grep -hrP '^ *\[x\] [[:digit:]]{5} ' "$DM_TREES"/* | sed -e 's/^[ \t]\+//' | cut -c 5-9)

unset who_initials
if [[ $user ]]; then
    who_initials=$(__person_translate_who "$user")
    [[ ! $who_initials ]] && __me "Invalid user: $user"
fi

# Update the people file regardless
__logger_debug "Updating people file from dmrc."
"$DM_BIN/person_update.sh"

_run_checks
readarray -t out_arr < <(_print_messages)

[[ ! ${out_arr[@]} ]] && exit
if __v; then
    # If verbose, print output to stdout
    printf "%s\n" "${out_arr[@]}"
else
    # If there was any output, send it in an email
    printf "%s\n" "${out_arr[@]}" | mail -s "Report from integrity.sh" "$DM_PERSON_EMAIL"
fi
