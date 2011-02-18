#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/ripmime.sh functions.
#

_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

source $DM_ROOT/test/test.sh
_loaded_ripmime 2>/dev/null || source $DM_ROOT/lib/ripmime.sh

tmpdir=$(tmp_dir)
test_dir="${tmpdir}/test"
test_filename="test_ripmime.mime"
test_file="${test_dir}/$test_filename"


#
# _setup_test_mime_file
#
# Sent: text_plain - include plain text file
#       text_html - include plain html file
#       attachment - include attached file
# Return: nothing
# Purpose:
#
#   Setup test mime file.
#
function _setup_test_mime_file {

    text_plain=$1
    text_html=$2
    attachment=$3

    rip_tmpdir=$(ripmime_tmpdir)
    ripmime_dir="${rip_tmpdir}/$test_filename"

    [[ -d "$ripmime_dir" ]] && rm -r "$ripmime_dir"

    cp /dev/null $test_file

cat >> $test_file << EOT
MIME-Version: 1.0
Received: by localhost.localdomain (fdm 1.6, account "jimkarsten");
    Sat, 24 Oct 2009 16:01:02 -0400
Received: by 10.210.114.7 with HTTP; Sat, 24 Oct 2009 12:56:56 -0700 (PDT)
Date: Sat, 24 Oct 2009 15:56:56 -0400
Delivered-To: jimkarsten@gmail.com
Message-ID: <6f8e8fc90910241256r1bba6327ma20d3676aad19fc1@mail.gmail.com>
Subject: wdp_copy.sh change
From: Jim Karsten <jimkarsten@gmail.com>
X-DM-Mod-Id: 10606
To: "Karsten, Jim - input" <jimkarsten+input@gmail.com>
Content-Type: multipart/alternative; boundary=0015174bdcee16ca360476b3bb9d
EOT

[[ $text_plain ]] && cat >> $test_file << EOT
--0015174bdcee16ca360476b3bb9d
Content-Type: text/plain; charset=ISO-8859-1

This is a mime body.

EOT

[[ $text_html ]] && cat >> $test_file << EOT
--0015174bdcee16ca360476b3bb9d
Content-Type: text/html; charset=ISO-8859-1

This is a mime body.<br>

EOT

[[ $attachment ]] && cat >> $test_file << EOT
--0015174bdcee16ca360476b3bb9d

Content-Type: text/html; charset=US-ASCII; name="__test__.htm"
Content-Disposition: attachment; filename="__test__.htm"
Content-Transfer-Encoding: base64
X-Attachment-Id: f_g79bxg8t0

CjwhRE9DVFlQRSBIVE1MIFBVQkxJQyAiLS8vVzNDLy9EVEQgSFRNTCA0LjAxIFRyYW5zaXRpb25h
bC8vRU4iICJodHRwOi8vd3d3LnczLm9yZy9UUi9odG1sNC9sb29zZS5kdGQiPgoKPGh0bWw+Cjxo
--0015174bdcee16ca360476b3bb9d--
EOT
    return
}


#
# tst_ripmime_command
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on ripmime_command function.
#
function tst_ripmime_command {

    got=$(ripmime_command)
    expect='/usr/bin/ripmime'
    tst "$got" "$expect" 'ripmime command returned expected'
}

#
# tst_ripmime_files_cat
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on ripmime_files_cat function.
#
function tst_ripmime_files_cat {

    text_plain=1
    text_html=
    attachment=
    _setup_test_mime_file "$text_plain" "$text_html" "$attachment"

    value=$(ripmime_files_cat $test_file)
    expect=$(echo -e "This is a mime body.\n")
    tst "$value" "$expect" "typical email returned expected"

    text_plain=
    text_html=1
    attachment=
    _setup_test_mime_file "$text_plain" "$text_html" "$attachment"

    value=$(ripmime_files_cat $test_file)
    expect=$(echo -e "This is a mime body.<br>\n")
    tst "$value" "$expect" "typical email returned expected"

    text_plain=1
    text_html=1
    attachment=1
    _setup_test_mime_file "$text_plain" "$text_html" "$attachment"

    value=$(ripmime_files_cat $test_file)
    expect=$(echo -e "This is a mime body.\n")
    tst "$value" "$expect" "typical email returned expected"

    return
}


#
# tst_ripmime_run
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on ripmime_run function.
#
function tst_ripmime_run {

    text_plain=1
    text_html=1
    attachment=1
    _setup_test_mime_file "$text_plain" "$text_html" "$attachment"

    rip_tmpdir=$(ripmime_tmpdir)
    ripmime_dir="${rip_tmpdir}/$test_filename"

    value=$(ripmime_run $test_file)
    expect=$ripmime_dir

    tst "$value" "$expect" "returned expected"

    unset a i
    while IFS= read -r file; do
        a[i++]="$file"
    done < <(find $ripmime_dir -type f | sort)
    # $ find /tmp/dm_jimk/ripmime/test_ripmime.mime -type f | sort
    #/tmp/dm_jimk/ripmime/test_ripmime.mime/__rip__text-html1
    #/tmp/dm_jimk/ripmime/test_ripmime.mime/__rip__text-plain0
    #/tmp/dm_jimk/ripmime/test_ripmime.mime/__test__.htm

    tst "${#a[@]}" "3" "returned expected number of files"
    tst "${a[0]}" "$ripmime_dir/__rip__text-html1" "second file correct"
    tst "${a[1]}" "$ripmime_dir/__rip__text-plain0" "third file correct"
    tst "${a[2]}" "$ripmime_dir/__test__.htm" "first file correct"

    return
}


#
# tst_ripmime_tmpdir
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on ripmime_tmpdir function.
#
function tst_ripmime_tmpdir {

    save_DM_TMP=DM_TMP
    DM_TMP=/tmp/dm_testing

    value=$(ripmime_tmpdir)
    expect="$DM_TMP/ripmime"
    tst "$value" "$expect" "returned expected"

    DM_TMP=$save_DM_TMP

    return
}


functions=$(cat $0 | grep '^function ' | awk '{ print $2}')

[[ "$1" ]] && functions="$*"

for function in  $functions; do
    if [[ ! $(declare -f $function) ]]; then
        echo "Function not found: $function"
        continue
    fi

    $function
done
