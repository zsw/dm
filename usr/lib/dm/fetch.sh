#!/bin/bash

usage() {

    cat << EOF

usage: $0

This script fetches mail.

OPTIONS:

   -v      Verbose.

   -h      Print this help message.

EXAMPLES:

    $0                  # Logs to /var/log/mail.log
    $0 -v               # Logs to stdout.

NOTES:

    This script can be cronned, ideally without -v option.
EOF
}

log_opt='-l'
verbose_opt=

while getopts "hv" options; do
  case $options in

    v ) verbose_opt='-v'
        log_opt=
        ;;
    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

# shift $(($OPTIND - 1))

/usr/bin/fdm $log_opt $verbose_opt fetch
