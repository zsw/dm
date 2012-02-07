#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() { cat << EOF
usage: $script [options] [path/to/spec]

This script will create file and directory-based mods within DM_ROOT for the
provided spec file.
    -b      Create a single blank mod assigned to current user and exit.
    -v      Verbose

    -h      Print this help message

EXAMPLE:
    $script ~/tmp/spec.txt          # Create mods from spec file
    $script ~/tmp/spec*.txt         # Create mods from multiple spec files
    $script -b                      # Create a single mod.

    mod_id=\$($script -b)                     # Create mod
    assign_mod.sh -m \$mod_id ABC             # Assign mod to ABC

NOTES:
    Specs should be of the form:

        <offset>[<initials>] <description>
        <notes>
        <offset>[<initials>] <description>
        <notes>
        <offset>[<initials>] <description>
        <notes>
        etc.

    After creating directories and files, the script will output this same
    schema with the ids that were used for the mods.  The output should follow
    the format of a depedency tree.

        <offset>[ ] <id> <description>
        <offset>[ ] <id> <description>
        <offset>[ ] <id> <description>
        etc.

    Any text in specs not following the above mod format is printed as
    is to stdout. This can include group start and end tags or comments.

    The script attempts to handle group start and end tags in a "least
    surprise" method, printing them as part of the dependency tree and
    assuming they are not part of a mod description. In some cases the
    text could be misinterpreted.

    Spec with project groups followed by the dependency tree outputted.

        group 001
        # Project: fix dm system
        <offset>[<initials>] <description>
        <notes>
        end

        group 001
        # Project: fix dm system
        <offset>[ ] <id> <description>
        end
EOF
}


#
# _create_mods
#
# Sent: file - name of file with specs
# Return: nothing, tree structure printed to stdout.
#
# Purpose:
#   Create mods from spec file.
#
_create_mods() {
    local count description file indent len mod mod_dir mod_id
    local prev_notes re saveIFS scrubbed_who who

    file=$1

    unset mod_dir
    unset prev_notes
    count=0
    re="^[ ]*\[([A-Za-z]+)\][ ]*(.+)[ ]*$"

    while IFS=$'\n' read -r line; do
        if [[ ! $line =~ $re ]]; then
            # Check for group start or end tag. Eg, any of these.
            # group 111 Project title.
            #   group 222
            #   end
            # end
            if grep -qP '^ *(group [[:digit:]]+|end$)' <<< "$line"; then
                echo "$line"
                # A group tag signals the mod notes are done as well.
                unset mod_dir
            elif [[ $mod_dir ]]; then
                # If we have a mod_dir, we're processing a mod, we can
                # assume the text is from the mod notes
                echo "$line" >> "$mod_dir/notes"
            else
                # Print non-mod text to stdout as is.
                echo "$line"
            fi

            continue
        fi

        [[ $prev_notes ]] && _unindent "$prev_notes"

        # Mod line: [JK] the description

        mod_id=$("$DM_BIN/next_mod_id.sh")
        [[ $? != '0' || ! $mod_id ]] && __me "Unable to get mod id." && continue

        mod=$(printf %05d $mod_id)
        mod_dir=$DM_ROOT/mods/$mod
        prev_notes=$mod_dir/notes
        who=${BASH_REMATCH[1]}
        description=${BASH_REMATCH[2]}
        scrubbed_who=$(_scrub_who "$who")

        [[ -d $mod_dir ]] && rm -r "$mod_dir"
        mkdir -p "$mod_dir"
        cp /dev/null "$mod_dir/notes"       # Initialize notes file
        cp /dev/null "$mod_dir/specs"       # Initialize specs file

        if [[ ! $scrubbed_who ]]; then
            scrubbed_who=$DM_PERSON_INITIALS
            echo -e "\nASSIGN TO $who\n" >> $mod_dir/notes
        fi
        echo "$scrubbed_who" > "$mod_dir/who"
        echo "$description" > "$mod_dir/description"

        indent=${line%%[^ ]*}
        len=${#indent}
        (( $len > 0 )) && printf "%${len}s" " "
        printf "[ ] %05d %s\n" "$mod" "$description"

    done < "$file"

    [[ $prev_notes ]] && _unindent "$prev_notes"
}

#
# _scrub_who
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Return a scrubbed "who".
#
# Notes:
# Scrubbing includes:
#   * Replacing alias with initials
#   * Changing to uppercase.
#   * Validating initials in people file
#
_scrub_who() {
    local from_alias who

    who=$1
    if [[ ! $who ]]; then
        __v && __mi "scrub_who: no 'who' provided."
        return
    fi

    from_alias=$(awk -F'=' -v var="^${who}=" '$0 ~ var {print $2;exit}' "$DM_ROOT/users/initial_aliases")
    [[ $from_alias ]] && who=$from_alias

    who=${who^^}

    # Check if a user exists with those initials
    [[ ! $(__person_attribute username initials "$who") ]] && return

    echo "$who"
}

_unindent() {
    local filename i j k

    filename=$1

    i=$(sort "$filename" | tail -1)     ## line with least leading white space
    j=${i##* }                          ## remove leading white space
    k=$(( ${#i} - ${#j} ))              ## difference is number leading spaces
    (( $k > 0 )) && sed -i "s/^ \{$k\}//" "$filename"   ## removes leading white space
}

_options() {
    args=()
    unset verbose
    unset blank

    while [[ $1 ]]; do
        case "$1" in
            -b) blank=1         ;;
            -v) verbose=true    ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    [[ ! $blank ]] && (( ${#args[@]} < 1 )) && { _u; exit 1; }
    [[ $blank ]] && (( ${#args[@]} > 0 )) && { _u; exit 1; }
}

_options "$@"

tmpdir=$(__tmp_dir)

if [[ $blank ]]; then
    args[0]=$(__tmp_file)
    echo "[$DM_PERSON_INITIALS] Blank mod" > "${args[0]}"
fi

for spec_file in ${args[@]}; do
    _create_mods "$spec_file"
done
