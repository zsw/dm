#!/usr/bin/perl -w

use strict;

while ( <STDIN> ) {

    print if looks_like_a_mod_path( $_ );
}

exit;

sub looks_like_a_mod_path {

    my $line = shift; chomp $line;

    return 0 unless $line =~ /\d{5}\d*\/?$/;   # ends with a five-plus digit number,
    return 0 unless -d $line;               # is a directory,
    return 0 unless -f "$line/description"; # and includes a description file

    return 1;
}

__END__

=head1 NAME

filter_mod.pl

=head1 SYNOPSIS

<path> <path> ... | filter_mod.pl

=head1 DESCRIPTION

This script will filter paths from STDIN that appear to be dev
mod paths.  A dev mod path is one which:

    * Is a directory,
    * ends with a five-plus digit number,
    * and includes a description file.

