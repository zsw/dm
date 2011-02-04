#!/usr/bin/perl -w

use strict;
use warnings;

use Getopt::Long qw( GetOptions :config bundling no_auto_abbrev );
use Pod::Usage qw(pod2usage);
use Test::More;
use Time::Piece;

my $time_piece = localtime;

my $options = get_options();

if ( $options->{test} ) {
    run_tests();
    exit;
}

my ( $what, $when, $until ) = input_components( $ARGV[0] );

printf "what: %s\n", $what;
printf "when: %s\n", $when;
if ($until) {
    printf "until: %s\n", $until;
}

exit;


#
# input_components
#
# Sent: string - eg '2009-08-03 7pm-9pm The Event'
# Return: array of strings, ( what, where, until )
# Purpose:
#
#   Parse the what, where and until components of an input string.
#
sub input_components {

    my ($string) = @_;


    my ( $what, $when,      $until );
    my ( $date, $time_from, $time_to );

    # Extract the date portion

    my $date_part   = q{};
    my $date_format = q{};
    my $date_year   = q{};

    my $months = qr{
        January   | February | March    | April    |
        May       | June     | July     | August   |
        September | October  | November | December |

        Jan | Feb | Mar | Apr |
        May | Jun | Jul | Aug |
        Sep | Oct | Nov | Dec
    }xms;

    if ($string =~ m{
                            # yyyy-mm-dd
            ^\s*            # Optional whitespace
            (               # $1 start
            [0-9]{4}        # yyyy
            -
            [0-9]{2}        # mm
            -
            [0-9]{2}        # dd
            )               # $1 end
            .*              # Everything else
        }xms
        )
    {
        $date_part   = $1;
        $date_format = '%F';
    }
    elsif (
        $string =~ m{
                            # Month dd, yyyy, Month dd yyyy, Month dd
            ^\s*            # Optional whitespace
            (               # $1 start
            $months         # January or Jan
            \s+
            [0-9]{1,2}      # dd
            \s*
            (               # $2 start
            [\s,]{1}        # Single comma or space
            )               # $2 end
            \s*
            (               # $3 start
            (?|[0-9]{4}|)   # yyyy optional
            )               # $3 end
            )               # $1 end
            .*
        }xms
        )
    {
        $date_part = $1;
        if ( ! $3 ) {
            $date_year = $time_piece->year;
        }

        $date_format = $2 eq q{,} ? '%b %d, %Y'
                                  : '%b %d %Y';

    }
    else {
        $date_part = q{};
    }

    my $dateless = $string;

    if ($date_part) {
        $date =
            Time::Piece->strptime(
                $date_year ? join ' ', $date_part, $date_year : $date_part,
                $date_format
            )->strftime('%F');
        $dateless =~ s/\Q$date_part\E//xms;
    }

    # Extract the time_from portion

    # strptime formats for reference
    #       %H     The hour (0-23).
    #       %I     The hour on a 12-hour clock (1-12).
    #       %M     The minute (0-59).
    #       %S     The seconds (0-59).
    #       %p     The locale's equivalent of AM or PM.  (Note: there may be none.)

    #
    my $from_part   = q{};
    my $from_format = q{};
    my $from_ampm   = q{};

    if ($dateless =~ m{
                            # "hh:mm am", "hh am", "hh:mm", "hh:mm:ss", "hh"
            ^\s*            # Optional whitespace
            (               # $1 start
            [0-9]{1,2}      # hh
            (               # $2 start
            (?|:[0-9]{2}|)  # :mm or empty string
            )               # $2 end
            (               # $3 start
            (?|:[0-9]{2}|)  # :ss or empty string
            )               # $3 end
            (               # $4 start
            (?|\s*am|\s*pm|)    # 'am' or 'pm' with optional leading space,
                                # or empty string
            )               # $4 end
            )               # $1 end
            .*              # Everything else
        }xms
        )
    {
        $from_part = "$1";
        $from_format =
              $3 ? '%H:%M:%S'
            : $4 && $2 ? '%I:%M%n%p'
            : $4 ? '%I%n%p'
            : $2 ? '%H:%M'
            :      '%H';
        $from_ampm = $4;
    }

    my $from_less = $dateless;

    if ($from_part) {
        $time_from =
            Time::Piece->strptime( $from_part, $from_format )->strftime('%T');

        $from_less =~ s/\Q$from_part\E//xms;
    }

    # The additional ? character make matches not greedily.


    # Extract the time_to portion

    my $to_part   = q{};
    my $to_format = q{};
    my $to_ampm   = q{};

    if ($from_less =~ m{
            # " - hh:mm am", " - hh am", " - hh:mm", "hh:mm:ss", " - hh",
            # "to hh:mm am", "to hh am", "to hh:mm", "hh:mm:ss", "to hh",
            ^\s*
            (?:-|to)        # - or to
            \s*
            (               # $1 start
            [0-9]{1,2}      # hh
            (               # $2 start
            (?|:[0-9]{2}|)  # :mm or empty string
            )               # $2 end
            (               # $3 start
            (?|:[0-9]{2}|)  # :ss or empty string
            )               # $3 end
            (               # $4 start
            (?|\s*am|\s*pm|)    # 'am' or 'pm' with optional leading space,
                                # or empty string
            )               # $4 end
            )               # $1 end
            .*              # Everything else
        }xms
        )
    {
        $to_part = "$1";
        $to_format =
              $3 ? '%H:%M:%S'
            : $4 && $2 ? '%I:%M%n%p'
            : $4 ? '%I%n%p'
            : $2 ? '%H:%M'
            :      '%H';
        $to_ampm = $4;
    }

    my $to_less = $from_less;

    if ($to_part) {
        $time_to =
            Time::Piece->strptime( $to_part, $to_format )->strftime('%T');
        $to_less =~ s/\s*(?:-|to)\s*\Q$to_part\E//xms;
    }


    # If the "to" time has an am/pm indicator but the "from" doesn't, assume the
    # "to" am/pm for the "from" time.

    if ( !$from_ampm && $to_ampm ) {
        $from_part .= " $to_ampm";    # Append the am/pm value to from time
        $from_format =~ s/%H/%I/xmsg; # Replace 24 hr format with 12 hr
        $from_format .= '%n%p';       # Append am/pm to format
        $time_from =
            Time::Piece->strptime( $from_part, $from_format )->strftime('%T');
    }


    $what = $to_less;
    $what =~ s/^\s*//xms;                # Remove leading whitespace.
    $what =~ s/\s*$//xms;                # Remove trailing whitespace.

    $when = join q{ }, $date, $time_from;
    $until =
        $time_to
        ? join q{ }, $date, $time_to
        : q{};

    return ( $what, $when, $until );
}


#
# run_tests
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on the input_components function.
#
sub run_tests {


    my $yyyy = $time_piece->year;

    #  --- test ------    ----- expect --------
    # ('calendar input', 'what', 'when', 'until')
    my @tests = (
        ['2009-08-03      7pm The Event', 'The Event', '2009-08-03 19:00:00', q{} ],
        ['August 3, 2009  7pm The Event', 'The Event', '2009-08-03 19:00:00', q{} ],
        ['August 3 2009   7pm The Event',            'The Event', '2009-08-03 19:00:00', q{}        ],
        ['August  3  2009 7pm The Event', 'The Event', '2009-08-03 19:00:00', q{} ],
        ['August 03 2009  7pm The Event', 'The Event', '2009-08-03 19:00:00', q{} ],
        ['Aug 3, 2009     7pm The Event', 'The Event', '2009-08-03 19:00:00', q{} ],
        ['Aug 3 2009      7pm The Event', 'The Event', '2009-08-03 19:00:00', q{} ],
        ['January 31, 2009  7am The Event', 'The Event', '2009-01-31 07:00:00', q{} ],
        ['Jan 31, 2009      7am The Event', 'The Event', '2009-01-31 07:00:00', q{} ],
        ['2009-08-03 7pm                The Event', 'The Event', '2009-08-03 19:00:00', q{} ],
        ['2009-08-03 7:35 pm            The Event', 'The Event', '2009-08-03 19:35:00', q{} ],
        ['2009-08-03 07:35 pm           The Event', 'The Event', '2009-08-03 19:35:00', q{} ],
        ['2009-08-03 7 pm               The Event', 'The Event', '2009-08-03 19:00:00', q{} ],
        ['2009-08-03 7-9am              The Event', 'The Event', '2009-08-03 07:00:00', '2009-08-03 09:00:00' ],
        ['2009-08-03 7-9pm              The Event', 'The Event', '2009-08-03 19:00:00', '2009-08-03 21:00:00' ],
        ['2009-08-03 7pm-9pm            The Event', 'The Event', '2009-08-03 19:00:00', '2009-08-03 21:00:00' ],
        ['2009-08-03 7:30am-9:45pm      The Event', 'The Event', '2009-08-03 07:30:00', '2009-08-03 21:45:00' ],
        ['2009-08-03 07:30am-09:45pm    The Event', 'The Event', '2009-08-03 07:30:00', '2009-08-03 21:45:00' ],
        ['2009-08-03 7pm to 9pm         The Event', 'The Event', '2009-08-03 19:00:00', '2009-08-03 21:00:00' ],
        ['2009-08-03 7:30am to 9:45pm   The Event', 'The Event', '2009-08-03 07:30:00', '2009-08-03 21:45:00' ],
        ['2009-08-03 07:30am to 09:45pm The Event', 'The Event', '2009-08-03 07:30:00', '2009-08-03 21:45:00' ],
        ['2009-08-03 19:00              The Event', 'The Event', '2009-08-03 19:00:00', q{} ],
        ['2009-08-03 19:00 - 21:00      The Event', 'The Event', '2009-08-03 19:00:00', '2009-08-03 21:00:00' ],
        ['2009-08-03 19:00 to 21:00     The Event', 'The Event', '2009-08-03 19:00:00', '2009-08-03 21:00:00' ],
        ['2009-08-03 19:00:00           The Event', 'The Event', '2009-08-03 19:00:00', q{} ],
        ['2009-08-03 19:00:00 to 21:00:00 The Event', 'The Event', '2009-08-03 19:00:00', '2009-08-03 21:00:00' ],
        ['2009-08-03 19:00:00 - 21:00:00  The Event', 'The Event', '2009-08-03 19:00:00', '2009-08-03 21:00:00' ],
        ['2009-08-03 19:00:00 to 21:00    The Event', 'The Event', '2009-08-03 19:00:00', '2009-08-03 21:00:00' ],
        ['2009-08-03 19:00 to 21:00:00 The Event', 'The Event', '2009-08-03 19:00:00', '2009-08-03 21:00:00' ],
        ['Aug 19          2:15pm to 3pm The Event', 'The Event', "$yyyy-08-19 14:15:00", "$yyyy-08-19 15:00:00" ],
        ['2009-08-03 7pm Toronto DemoCamp #21', 'Toronto DemoCamp #21', '2009-08-03 19:00:00', q{} ],
    );

    plan tests => scalar @tests;

    foreach my $test (@tests) {
        my ( $string, $expect_what, $expect_when, $expect_until ) =
            ( @{$test} );

        my ( $got_what, $got_when, $got_until ) = input_components($string);

#printf "%s %s %s\n", $got_what, $got_when, $got_until;

        ok( $got_what eq $expect_what &&
            $got_when eq $expect_when &&
            $got_until eq $expect_until,
            "\"$string\" parses as expected"
        );
    }

    return;
}


#
# get_options
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#     Process command-line options.
#
sub get_options {

    my %options = ();

    GetOptions(

        'test|t' => \$options{test},
        'help|?' => \$options{help},
        'man'    => \$options{man},

    ) or pod2usage( -verbose => 0 );

    if ( $options{help} ) {
        pod2usage( -verbose => 1 );
    }

    if ( $options{man} ) {
        pod2usage( -verbose => 2 );
    }

    if ( !$options{test} && !$ARGV[0] ) {
        pod2usage( -verbose => 1 );
    }

    return \%options;
}


__END__

=head1 NAME

calendar_input_parse.pl

=head1 SYNOPSIS

calendar_input_parse.pl [options] string

Options:

        --test, -t      Perform tests on parsing method.

        --help, -?      Show usage instructions.
        --man           Show man page.

=head1 DESCRIPTION

This script will parse a calendar input string and print the "when", "until"
and "what" sections.

Example:

    calendar_input_parse.pl "2009-08-03 7pm to 9pm Web Design meetup.

    # Prints:

    what: Web Design meetup.
    when: 2009-08-03 19:00:00
    until: 2009-08-03 21:00:00

=head1 OPTIONS

=over 4

=item B<--test, -t>

When the --test option is provided, tests are run on the parsing method and
results are printed to STDOUT.

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Print the manual page and exits.

=back

