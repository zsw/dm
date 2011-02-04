#!/usr/bin/perl -w

use strict;

use Pod::Usage;
use Getopt::Long qw( :config bundling no_auto_abbrev );
use File::Temp;


my $options = get_options();

unless ( $options->{dm_root} ) {
    die "dm_root option not set.";
}

if ( $options->{test} ) {

    Dependency::Schema::test();

    exit 0; # ok
}

my $Schema = Dependency::Schema->new( lines_from_stdin() );

$Schema->debug(1) if $options->{debug};

unless ( $Schema->is_valid ) {

    print STDERR map { "error: $_\n" } $Schema->errors;

    exit 1; # not ok
}

if ( $options->{mods} ) {

    my @mods = $options->{available} ? $Schema->available_mods : $Schema->mods;

    print map { "$_\n" } uniq( @mods );
}

exit 0; # ok

#
# lines_from_stdin
#
# Sent: nothing
# Return: mulit-line string
# Purpose:
#
#    Read and return all lines from STDIN.
#
sub lines_from_stdin {

    my $lines = "";

    while ( my $line = <STDIN> ) {

        $lines .= $line;
    }

    return $lines;
}


#
# get_options
#
# Sent: nothing
# Return: hashref
# Purpose:
#
#     Process and return command-line options.
#
sub get_options {

    my %options = ();

    GetOptions(

        "available|a" => \$options{available},
        "debug|d"     => \$options{debug},
        "mods|m"      => \$options{mods},
        "test|t"      => \$options{test},

        "help|?" => \$options{help},
        "man"    => \$options{man},

    ) or pod2usage( -verbose => 0 );

    pod2usage( -verbose => 1 ) if $options{help};
    pod2usage( -verbose => 2 ) if $options{man};

    $options{mods} = 1 if $options{available};

    if ( ! @ARGV ) {
        if ($options{test}) {
            $options{dm_root} = File::Temp->newdir("/tmp/dm_XXXXXXXXXX");
        }
        else {
            print STDERR "Please provide /path/to/dm/root\n";
            pod2usage( -verbose => 0 )
        }
    }
    else {
        $options{dm_root} = $ARGV[0];
    }

    return \%options;
}


#
# uniq - return only unique elements from @a, in
#        order of appearance.
#
sub uniq {

    my ( @a ) = @_;

    my ( @b, %k );

    foreach my $a ( @a ) {

        next if exists $k{$a}; $k{$a} = 1;

        push @b, $a;
    }

    return @b;
}


#
# Dependency::Schema::Line
#
# Purpose:
#
#     Each instance represents a single line in a dependency tree.
#     The package houses a number of predicates that will test for
#     certain types of content, eg. "looks_like_a_comment", as well
#     as methods for extracting information from lines, eg. "mod_id".
#
#     Instances are created and used by Dependency::Schema.
#
# Usage:
#
#     my $Line = Dependency::Schema::Line->new( <text>, <line number> )
#
#     print $Line->mod_id if $Line->looks_like_a_mod;
#     etc.
#
package Dependency::Schema::Line;

use strict;

use overload '""' => "text";

our $INDENT; # proper indent step (will default to four)

sub text   { (shift)->{text}   } # attribute
sub number { (shift)->{number} } # accessors

sub mod_id        { (shift)->text =~ /^\s*\[.\]\s(\d+)/ ?               $1 : "" } # these methods
sub group_id      { (shift)->text =~ /^\s*(?:group|start|end)\s(\d+)/ ? $1 : "" } # will extract
sub offset        { (shift)->text =~ /^(\s+)/ ?                         $1 : "" } # information from
sub trim_offset   { (shift)->text =~ /^\s*(.*)$/;                       $1      } # the line, eg.
sub offset_length { length((shift)->offset)                                     } # the mod's id.

#
# has_valid_start_token
#
# Sent: nothing
# Return: true/false (1/0)
# Purpose:
#
#     Validate the initial token on the line, make sure it matches
#     something expected of a dependency tree.
#
sub has_valid_start_token {

    my $class = shift;

    return 1 if $class->looks_like_a_comment
             || $class->looks_like_a_mod
             || $class->looks_like_a_group_start
             || $class->looks_like_a_group_end
             || $class->looks_like_a_group_boundary;

    return 0;
}

sub is_blank                    { (shift)->text =~ /^\s*$/                    || 0 } # validation
sub looks_like_a_comment        { (shift)->text =~ /^\s*\#/                   || 0 } # predicates
sub looks_like_a_mod            { (shift)->text =~ /^\s*\[.\]/                || 0 } #
sub looks_like_a_group_start    { (shift)->text =~ /^\s*group\b/              || 0 } #
sub looks_like_a_group_end      { (shift)->text =~ /^\s*end\s*(?:\#|$)/       || 0 } #
sub looks_like_a_group_boundary { (shift)->text =~ /^\s*(?:start\b|end\s\d+)/ || 0 } #
sub has_valid_indent            { length((shift)->offset) % $INDENT == 0   ? 1 : 0 } #

#
# with_numbered_offset
#
# Sent: nothing
# Return: string
# Purpose:
#
#     Return line with leading spaces replaced with 1-$INDENT(4).
#
#     Example:
#
#         original: "     abc def"
#           output: "12341abc def"
#
# Notes:
#
#   * This method helps debug incorrect indent alignment.
#
sub with_numbered_offset {

    my $class = shift;

    my $line = $class->text;

    my $c = 0; while ( $line =~ /\s/ ) {

        $c = 1 if $c++ % $INDENT == 0;

        $line =~ s/\s/$c/;

        last if $line =~ /^\d+(?=[^\d\s])/;
    }

    return $line;
}


#
# numbered
#
# Sent: nothing
# Return: string
# Purpose:
#
#     Return the line formatted with its line number.
#
#     Example:
#
#         0012: [ ] 12345
#
sub numbered { my $class = shift; sprintf("%04d: %s", $class->number, $class) }


#
# new
#
# Sent: $text, $number ( string; single line, integer )
# Return: object ( Dependency::Schema::Line )
# Purpose:
#
#     Instantiate and return a new line object.
#
sub new {

    my $class = shift;

    my ( $text, $number ) = @_;

    our $INDENT ||= 4;

    return bless { text => $text || "", number => $number || 0 }, ref($class) || $class;
}


#
# test
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#     Test the functionality of Dependency::Schema::Line.
#
sub test {

    require Test::More; Test::More->import;

    my $new = sub { Dependency::Schema::Line->new( @_ ) };

    ok ( $new->("")->is_blank, "is_blank1" );
    ok ( $new->(" ")->is_blank, "is_blank2" );
    ok ( $new->("  ")->is_blank, "is_blank3" );
    ok ( ! $new->("   abc")->is_blank, "is_blank4" );

    ok ( $new->("# comment")->looks_like_a_comment, "looks_like_a_comment1" );
    ok ( $new->("  # comment")->looks_like_a_comment, "looks_like_a_comment2" );
    ok ( $new->("#comment")->looks_like_a_comment, "looks_like_a_comment3" );
    ok ( ! $new->("[ ] 123 #")->looks_like_a_comment, "looks_like_a_comment4" );
    ok ( ! $new->("end #")->looks_like_a_comment, "looks_like_a_comment5" );

    ok ( $new->("[ ] 1234 This is extra # comment")->looks_like_a_mod, "looks_like_a_mod1" );
    ok ( $new->("[ ] 1234 This is extra")->looks_like_a_mod, "looks_like_a_mod2" );
    ok ( $new->("[ ] 1234")->looks_like_a_mod, "looks_like_a_mod3" );
    ok ( $new->("[ ]")->looks_like_a_mod, "looks_like_a_mod4" );
    ok ( $new->("[X]")->looks_like_a_mod, "looks_like_a_mod5" );
    ok ( $new->("[x]")->looks_like_a_mod, "looks_like_a_mod6" );
    ok ( $new->("    [ ] 1234 This is extra # comment")->looks_like_a_mod, "looks_like_a_mod7" );
    ok ( $new->("    [ ] 1234 This is extra")->looks_like_a_mod, "looks_like_a_mod8" );
    ok ( $new->("    [ ] 1234")->looks_like_a_mod, "looks_like_a_mod9" );
    ok ( $new->("    [ ]")->looks_like_a_mod, "looks_like_a_mod10" );
    ok ( $new->("    [X]")->looks_like_a_mod, "looks_like_a_mod11" );
    ok ( $new->("    [x]")->looks_like_a_mod, "looks_like_a_mod12" );
    ok ( ! $new->("group 123")->looks_like_a_mod, "looks_like_a_mod13" );
    ok ( ! $new->("[   ] abc")->looks_like_a_mod, "looks_like_a_mod14" );
    ok ( ! $new->("( )")->looks_like_a_mod, "looks_like_a_mod15" );

    ok ( $new->("group")->looks_like_a_group_start, "looks_like_a_group_start1" );
    ok ( ! $new->("start 123")->looks_like_a_group_start, "looks_like_a_group_start2" );
    ok ( ! $new->("end 123")->looks_like_a_group_start, "looks_like_a_group_start3" );
    ok ( ! $new->("end")->looks_like_a_group_start, "looks_like_a_group_start4" );
    ok ( ! $new->("# start 123")->looks_like_a_group_start, "looks_like_a_group_start5" );

    ok ( $new->("end")->looks_like_a_group_end, "looks_like_a_group_end6" );
    ok ( $new->("end # comment")->looks_like_a_group_end, "looks_like_a_group_end7" );
    ok ( ! $new->("end 123")->looks_like_a_group_end, "looks_like_a_group_end8" );

    ok ( $new->("start 123")->looks_like_a_group_boundary, "looks_like_a_group_boundary1" );
    ok ( $new->("end 123")->looks_like_a_group_boundary, "looks_like_a_group_boundary2" );
    ok ( $new->("    start 123")->looks_like_a_group_boundary, "looks_like_a_group_boundary3" );
    ok ( $new->("    end 123")->looks_like_a_group_boundary, "looks_like_a_group_boundary4" );
    ok ( ! $new->("group 123")->looks_like_a_group_boundary, "looks_like_a_group_boundary5" );
    ok ( ! $new->("end")->looks_like_a_group_boundary, "looks_like_a_group_boundary6" );
    ok ( ! $new->("# start 123")->looks_like_a_group_boundary, "looks_like_a_group_boundary7" );

    ok ( $new->("[ ] 123")->has_valid_start_token, "has_valid_start_token1" );
    ok ( $new->("# comment")->has_valid_start_token, "has_valid_start_token2" );
    ok ( $new->("group")->has_valid_start_token, "has_valid_start_token3" );
    ok ( $new->("start")->has_valid_start_token, "has_valid_start_token4" );
    ok ( $new->("end")->has_valid_start_token, "has_valid_start_token5" );
    ok ( ! $new->("abc")->has_valid_start_token, "has_valid_start_token6" );
    ok ( ! $new->("( )")->has_valid_start_token, "has_valid_start_token7" );
    ok ( ! $new->("( ]")->has_valid_start_token, "has_valid_start_token8" );
    ok ( ! $new->("[ )")->has_valid_start_token, "has_valid_start_token9" );
    ok ( ! $new->("[  ]")->has_valid_start_token, "has_valid_start_token10" );

    ok ( $new->("[ ] 12345 abc")->mod_id == 12345, "mod_id1" );
    ok ( ! $new->("[ ]   12345 abc")->mod_id, "mod_id2" );
    ok ( $new->("[ ] abc")->mod_id eq '', "mod_id3" );
    ok ( ! $new->("[ ]")->mod_id, "mod_id4" );

    ok ( $new->("group 123 abc")->group_id == 123, "group_id1" );
    ok ( $new->("start 123")->group_id == 123, "group_id2" );
    ok ( $new->("end 123")->group_id == 123, "group_id3" );
    ok ( ! $new->("group   123 abc")->group_id, "group_id4" );
    ok ( ! $new->("group abc")->group_id, "group_id5" );
    ok ( ! $new->("group")->group_id, "group_id6" );
    ok ( ! $new->("start   123")->group_id, "group_id7" );
    ok ( ! $new->("start abc")->group_id, "group_id8" );
    ok ( ! $new->("end   123")->group_id, "group_id9" );
    ok ( ! $new->("end abc")->group_id, "group_id10" );

    ok ( $new->("abc")->offset eq "", "offset1" );
    ok ( $new->("   abc")->offset eq "   ", "offset2" );
    ok ( $new->("     abc")->offset eq "     ", "offset3" );

    ok ( $new->("abc")->offset_length == 0, "offset_length1" );
    ok ( $new->("   abc")->offset_length == 3 , "offset_length2" );
    ok ( $new->("     abc")->offset_length == 5, "offset_length3" );

    ok ( $new->("abc")->trim_offset eq "abc", "trim_offset1" );
    ok ( $new->("   abc")->trim_offset eq "abc", "trim_offset2" );
    ok ( $new->("     abc")->trim_offset eq "abc", "trim_offset3" );
    ok ( $new->("     abc   ")->trim_offset eq "abc   ", "trim_offset4" );

    ok ( $new->("abc")->has_valid_indent, "has_valid_indent1");
    ok ( ! $new->(" abc")->has_valid_indent, "has_valid_indent2");
    ok ( ! $new->("  abc")->has_valid_indent, "has_valid_indent3");
    ok ( ! $new->("   abc")->has_valid_indent, "has_valid_indent4");
    ok (   $new->("    abc")->has_valid_indent, "has_valid_indent5");
    ok ( ! $new->("     abc")->has_valid_indent, "has_valid_indent6");
    ok (   $new->("        abc")->has_valid_indent, "has_valid_indent7");

    ok ( $new->("aaa", 1)->numbered eq "0001: aaa", "numbered1" );
    ok ( $new->("aaa", 2)->numbered eq "0002: aaa", "numbered2" );
    ok ( $new->("aaa", 101)->numbered eq "0101: aaa", "numbered3" );

    ok ( $new->("abc")->with_numbered_offset eq 'abc', "with_numbered_offset1" );
    ok ( $new->(" abc")->with_numbered_offset eq '1abc', "with_numbered_offset2" );
    ok ( $new->("  abc")->with_numbered_offset eq '12abc', "with_numbered_offset3" );
    ok ( $new->("   abc")->with_numbered_offset eq '123abc', "with_numbered_offset4" );
    ok ( $new->("    abc")->with_numbered_offset eq '1234abc', "with_numbered_offset5" );
    ok ( $new->("     abc")->with_numbered_offset eq '12341abc', "with_numbered_offset6" );
    ok ( $new->("      abc")->with_numbered_offset eq '123412abc', "with_numbered_offset7" );

    return;
}

1;

#
# Dependency::Schema
#
# Purpose:
#
#     Each instance represents a complete dependency tree.
#
# Usage:
#
#     my $Schema = Dependency::Schema->new( <text> )
#
#     print $Schema->errors unless $Schema->is_valid;
#
#
package Dependency::Schema;

use strict;

sub text { (shift)->{text} } # accessor for text

#
# lines
#
# Sent: nothing
# Return: list ( objects; Dependency::Schema::Line )
# Purpose:
#
#     Return a list of line objects, one for each line from the text.
#
sub lines {

    my $class = shift;

    my @lines = split(/\n/, $class->text);

    my $count = 0;

    return map { new Dependency::Schema::Line( $_, ++$count ) } @lines;
}


#
# elements
#
# Sent: nothing
# Return: list ( objects; Dependency::Schema::Element )
# Purpose:
#
#     Return a list of all elements found within the dependency schema.
#
sub elements {

    my $class = shift;

    return map { new Dependency::Schema::Element( $_ ) } $class->dependencies->lines;
}


#
# mods
#
# Sent: nothing
# Return: list ( objects; Dependency::Schema::Element::Mod )
# Purpose:
#
#     Return a list of all mod elements found within the dependency schema.
#
sub mods {

    my $class = shift;

    return grep { $_->type eq 'mod' } $class->elements;
}


#
# available_mods
#
# Sent: nothing
# Return: list ( objects; Dependency::Schema::Element::Mod )
# Purpose:
#
#     Return the list of mods that are available to be worked
#     on.  A mod is available if it's not done or on hold, and
#     all of its parent dependencies are done.
#
sub available_mods {

    my $class = shift;

    my @mods = ();

    foreach my $mod ( $class->mods ) {

        next if $mod->on_hold || $mod->is_done;

        next unless $class->all_parents_for_element_done( $mod );

        push @mods, $mod;
    }

    return @mods;
}


#
# significant_lines
#
# Sent: nothing
# Return: list ( objects; Dependency::Schema::Line )
# Purpose:
#
#     Return lines, with blanks and comments filtered out.
#
sub significant_lines { grep { ! $_->is_blank && ! $_->looks_like_a_comment } (shift)->lines }


#
# is_valid
#
# Sent: nothing
# Return: true/false
# Purpose:
#
#     Return true of the dependency schema is valid.  The schema is
#     valid if it is formatted correctly, has proper groups (all
#     groups closed, no references to undefined groups, etc.), and
#     has valid dependencies (no circular references).
#
sub is_valid {

    my $class = shift;

    return $class->has_valid_line_format
        && $class->has_valid_indenting
        && $class->has_valid_groups
        && $class->has_valid_dependencies;
}


#
# has_valid_line_format
#
# Sent: nothing
# Return: true/false
# Purpose:
#
#     Return true (1) if each line is individually formatted correctly.
#
sub has_valid_line_format {

    my $class = shift;

    my $is_valid = 1;

    my @lines = $class->lines;

    if ( $class->debug ) {

        print "\n";
        print "all lines\n";
        print "---------\n";
        print map { $_->numbered."\n" } @lines;
        print "\n";
    }

    foreach my $line ( @lines ) {

        next if $line->is_blank;

        unless ( $line->has_valid_start_token ) {

            $class->errors("invalid line token at line ", $line->number, ": ", $line->text);

            $is_valid = 0;

            next;
        }

        if ( $line->looks_like_a_mod ) {

            unless ( $line->mod_id ) {

                $class->errors("invalid or non-existant mod id at line ", $line->number, ": ", $line->text);

                $is_valid = 0;

                next;
            }
        }
        elsif ( $line->looks_like_a_group_start || $line->looks_like_a_group_boundary ) {

            unless ( $line->group_id ) {

                $class->errors("invalid or non-existant group id at line ", $line->number, ": ", $line->text);

                $is_valid = 0;

                next;
            }
        }
    }

    if ( $is_valid && $class->debug ) {

        print "significant lines\n";
        print "-----------------\n";
        print map { $_->numbered."\n" } $class->significant_lines;
        print "\n";
    }

    return $is_valid;
}


#
# has_valid_indenting
#
# Sent: nothing
# Return: true/false
# Purpose:
#
#     Return true if the indenting is valid.
#
#     * Lines must be indented by a factor of four.
#
#     * Lines offset to the right may be no more than four spaces
#       from their parent.
#
sub has_valid_indenting {

    my $class = shift;

    my $is_valid = 1;

    my $previous_indent;

    my $tab = $Dependency::Schema::Line::INDENT;

    foreach my $line ( $class->significant_lines ) {

        my $indent = $line->offset;

        if ( $previous_indent ) {

            my $diff = length($indent) - length($previous_indent);

            unless ( $diff <= 0 || $diff == $tab ) {

                $class->errors("invalid indent level at line ", $line->number, " (+step != $tab): ", $line->with_numbered_offset, " (diff = $diff)");

                $is_valid = 0;
            }
        }

        $previous_indent = $indent;
    }

    return $is_valid;
}


#
# has_valid_groups
#
# Sent: nothing
# Return: true/false
# Purpose:
#
#     Return true if all groups are valid.
#
#     * All groups must be closed (matched with an 'end')
#
#     * Groups may be nested, but must not overlap.
#
#     * There must be no group boundaries (start N, end N) for
#       groups that were not defined.  In other words, this is
#       invalid because group 002 is undefined:
#
#           group 001
#           end
#
#           start 002
#
sub has_valid_groups {

    my $class = shift;

    return 0 unless $class->all_groups_unique
                 && $class->has_valid_group_offsets
                 && $class->all_groups_closed
                 && $class->has_valid_group_boundaries;

    if ( $class->debug ) {

        print "groups\n";
        print "------\n";

        foreach my $group ( $class->groups ) {

            print sprintf("group %s: [%s]\n", $group->{id}, join ", ", @{$group->{nodes}});
        }

        print "\n";
    }

    return 1;
}


#
# has_valid_group_offsets
#
# Sent: nothing
# Return: true/false
# Purpose:
#
#     Return true if group offsets are valid.
#
#     * Groups must be closed by an 'end' at the same indent level.
#
sub has_valid_group_offsets {

    my $class = shift;

    my $is_valid = 1;

    my @ids = ();

    my $group_offset = {};

    foreach my $line ( $class->significant_lines ) {

        my $offset = length($line->offset);

        if ( $line->looks_like_a_group_start ) {

            my $group_id = $line->group_id;

            $group_offset->{$group_id} = $offset;

            push @ids, $group_id;
        }
        elsif ( $line->looks_like_a_group_end ) {

            if ( my $id = pop @ids ) {

                unless ( $offset == $group_offset->{$id} ) {

                    $class->errors("offset mismatch for group $id: ", "$offset != ".$group_offset->{$id});

                    $is_valid = 0;
                }
            }
        }
    }

    return $is_valid;
}


#
# all_groups_unique
#
# Sent: nothing
# Return: true/false
# Purpose:
#
#     Return true if all groups are unique.  This routine
#     will find groups that are opened a second time.
#
sub all_groups_unique {

    my $class = shift;

    my $is_valid = 1;

    my $groups = {};

    foreach my $line ( $class->significant_lines ) {

        if ( $line->looks_like_a_group_start ) {

            my $group_id = $line->group_id;

            if ( exists $groups->{$group_id} ) {

                $class->errors("group $group_id opened again at line ", $line->number);

                $is_valid = 0;

                next;
            }

            $groups->{$group_id} = 1;
        }
    }

    return $is_valid;
}


#
# all_groups_closed
#
# Sent: nothing
# Return: true/false
# Purpose:
#
#     Return true if all groups were closed, that is, all
#     groups were paired with an 'end' at the same indent level.
#
sub all_groups_closed {

    my $class = shift;

    my $is_valid = 1;

    my @groups = $class->groups;

    foreach my $group ( @groups ) {

        if ( $group->{open} ) {

            $class->errors("group ", $group->{id}, " was not closed");

            $is_valid = 0;
        }
    }

    return $is_valid;
}


#
# has_valid_group_boundaries
#
# Sent: nothing
# Return: true/false
# Purpose:
#
#     Return true if group boundaries (ie. start 123, end 123) are
#     valid.  This will find group boundaries that refer to groups
#     that were not opened.
#
sub has_valid_group_boundaries {

    my $class = shift;

    my $is_valid = 1;

    my @groups = $class->groups;

    foreach my $line ( $class->significant_lines ) {

        if ( $line->looks_like_a_group_boundary ) {

            my $group_id = $line->group_id;

            unless ( grep { $_->{id} == $group_id } @groups ) {

                $class->errors("invalid group at line ", $line->number, ": $line");

                $is_valid = 0;
            }
        }
    }

    return $is_valid;
}


#
# has_valid_dependencies
#
# Sent: nothing
# Return: true/false
# Purpose:
#
#     Return true if dependencies are valid.
#
#     * Dependencies must not be circular.
#
sub has_valid_dependencies {

    my $class = shift;

    return 0 if $class->has_circular_dependencies;

    if ( $class->debug ) {

        if ( my $dependencies = $class->dependencies ) {

            print "dependencies\n";
            print "------------\n";
            print map { $_->numbered."\n" } $dependencies->significant_lines;
            print "\n";
        }
    }

    return 1;
}


#
# children_for_line
#
# Sent: $parent ( integer; line number )
# Return: list ( objects; Dependency::Schema::Line )
# Purpose:
#
#     Given a line number, return all lines that are a direct descendent
#     of it.
#
#     For example, given this schema:
#
#         0001: aaa
#         0002:     bbb
#         0003:     ccc
#         0004: ddd
#         0005:     eee
#         0006:         fff
#         0007:     ggg
#         0008: hhh
#
#
#     $class->children_for_line(4) will return lines 'eee' and 'ggg'
#     (in object form).
#
# Notes:
#
#     * The routine is likely to be called many times, so the first time
#       through it will build and cache a number-to-line hash in the
#       object instance.
#
sub children_for_line {

    my $class = shift;

    my $parent = shift || 1;

    my @children = ();

    $class->{lines_by_number} ||= {map { $_->number => $_ } $class->significant_lines};

    my $line = sub { $class->{lines_by_number}->{(shift)} }; # just simplifies lookup

    my $tab = $Dependency::Schema::Line::INDENT;

    foreach my $number ( sort { $a <=> $b } keys %{$class->{lines_by_number}} ) {

        next unless $number > $parent; # wait 'till we're on the line after $parent

        # start on the next line if the offset has moved left, or isn't any deeper
        last if $line->($number)->offset_length <= $line->($parent)->offset_length;

        # skip this line if the offset is too far right
        next unless $line->($number)->offset_length == $line->($parent)->offset_length + $tab;

        # line is a direct descendent of parent, add to children
        push @children, $line->($number);
    }

    return @children;
}


#
# children_by_line_content
#
# Sent: nothing
# Return: hashref
# Purpose:
#
#     Return all children, indexed by parent line content.
#
#     For example, given this schema:
#
#         0001: aaa
#         0002:     bbb
#         0003:     ccc
#         0004: ddd
#         0005:     aaa
#         0006:         eee
#
#     The returned hash will look something like:
#
#         'aaa' => ['bbb', 'ccc', 'eee'],
#         'ddd' => ['aaa']
#
# Notes:
#
#     * The lines are indexed by the left-trimmed value of each line.
#       In other words, the line minus it's leading offset.  What this
#       means is that if lines with the same token (ie. [ ] 111111)
#       differ -- say, one has a comment or an extra description -- they
#       will not be considered the same line.
#
#       To use the above example, if line 5 was "    aaa yadda yadda", the
#       line 'eee' would not be considered a child of 'aaa'.
#
#       As a result, this routine is most useful after the schema has been
#       tokenized, and extra lines and comments stripped (the dependencies()
#       method returns a useful format).
#
#     * Lines with no children are not indexed by the hash.  This will allow
#       the coder to say, "if ( $class->children_by_line_content->{foo} )".
#       If all lines were indexed, the coder would have to dereference the
#       array element and test it in scalar context.
#
sub children_by_line_content {

    my $class = shift;

    my $children_by_line_content = {};

    foreach my $line ( $class->significant_lines ) {

        my @children = $class->children_for_line( $line->number );

        next unless @children;

        push @{$children_by_line_content->{ $line->trim_offset }}, @children;

        next;

        push @{$children_by_line_content->{ $line->trim_offset }},

            map { $_->trim_offset } @children;
    }

    return $children_by_line_content;
}


#
# parent_for_line
#
# Sent: $child ( integer; line number )
# Return: object ( Dependency::Schema::Line )
# Purpose:
#
#     Given a line number, return the direct parent of that line.
#
#     For example, given this schema:
#
#         0001: aaa
#         0002:     bbb
#         0003:     ccc
#         0004: ddd
#         0005:     eee
#         0006:         fff
#         0007:     ggg
#         0008: hhh
#
#
#     $class->parent_for_line(3) would return line 1, "aaa" in object form.
#     $class->parent_for_line(4) would not return anything.
#
# Notes:
#
#     * Like children_for_line, this routine is likely to be called many
#       times, so the first time through it will build and cache a number-to-line
#       hash in the object instance.
#
sub parent_for_line {

    my $class = shift;

    my $child = shift || 1;

    $class->{lines_by_number} ||= {map { $_->number => $_ } $class->significant_lines};

    my $line = sub { $class->{lines_by_number}->{(shift)} }; # just simplifies lookup

    my $tab = $Dependency::Schema::Line::INDENT;

                       # work through lines in reverse order
    foreach my $number ( sort { $b <=> $a } keys %{$class->{lines_by_number}} ) {

        next unless $number < $child; # wait 'till we're on the line before the target child

        # keep going until the offset is one tab less
        next unless $line->($number)->offset_length == $line->($child)->offset_length - $tab;

        # this is our parent

        return $line->($number);
    }

    return;
}


#
# parents_by_line_content
#
# Sent: nothing
# Return: hashref
# Purpose:
#
#     Return all parents, indexed by child line content.
#
#     For example, given this schema:
#
#         0001: aaa
#         0002:     bbb
#         0003:     ccc
#         0004: ddd
#         0005:     bbb
#         0006:         eee
#
#     The returned hash will look something like:
#
#         'bbb' => ['aaa', 'ddd']
#         'ccc' => ['aaa']
#         'eee' => ['bbb']
#
# Notes:
#
#     * See children_by_line_content for additional details.
#
sub parents_by_line_content {

    my $class = shift;

    my $parents_by_line_content = {};

    foreach my $line ( $class->significant_lines ) {

        my $parent = $class->parent_for_line( $line->number ) or next;

        push @{$parents_by_line_content->{ $line->trim_offset }}, $parent;
    }

    return $parents_by_line_content;
}


#
# parents_for_element
#
# Sent: $element ( object; Dependency::Schema::Element )
# Return: list ( objects; Dependency::Schema::Element )
# Purpose:
#
#    Given an element, return a list of all parents for it.
#
sub parents_for_element {

    my $class = shift;

    my ( $element ) = @_;

    $class->{parents_for_element} ||= $class->dependencies->parents_by_line_content;

    my $parents = $class->{parents_for_element}->{ $element->line->trim_offset };

    return () unless $parents;

    return map { new Dependency::Schema::Element ( $_ ) } @$parents;
}


#
# all_parents_for_element_done
#
# Sent: $element ( object; Dependency::Schema::Element )
# Return: true/false (1/0)
# Purpose:
#
#     Return true if all parents of the supplied element are done.
#
sub all_parents_for_element_done {

    my $class = shift;

    my ( $element ) = @_;

    foreach my $parent ( $class->parents_for_element( $element ) ) {

        if ( $parent->type eq 'mod' ) {

            return 0 unless $parent->is_done;
        }

        return 0 unless $class->all_parents_for_element_done( $parent );
    }

    return 1;
}


#
# has_circular_dependencies
#
# Sent: nothing
# Return: true/false
# Purpose:
#
#     Return true if circular dependencies are detected.
#
#     Examples:
#
#         [ ] 11111
#             [ ] 22222
#                 [ ] 11111
#
#         [ ] 11111
#             [ ] 22222
#         [ ] 22222
#             [ ] 33333
#         [ ] 33333
#             [ ] 11111
#
#         start 001
#             [ ] 11111
#                 end 001
#                     [ ] 22222
#                         start 001
#
sub has_circular_dependencies {

    my $class = shift;

    my $is_circular = 0;

    my $dependencies = $class->dependencies or return 0;

    my $children_by_dependency = $dependencies->children_by_line_content;

    foreach my $dependency ( keys %$children_by_dependency ) {

        if ( circular_link( $children_by_dependency, $dependency, $dependency ) ) {

            $class->errors("circular link to $dependency detected");

            $is_circular = 1;

            last;
        }
    }

    return $is_circular;
}


#
# circular_link
#
# Sent: $children, $parent, $grandparent, $chain ( hashref, string x2, array ref )
# Return true/false
# Purpose:
#
#     Return true if a child has itself as a parent or grandparent.
#
# Notes:
#
#     This method essentially builds a chain of children (ie. [mod 1111, mod 2222]),
#     including the children of each child.  Along the way, it tests to see if the
#     original child, which is now considered the "grandparent" in context is
#     contained within the chain that was built.  If it does, the chain is circular
#     and the routine will return true (1).
#
#     This routine will be called for each element by has_circular_dependencies().
#
#     The routine is recursive in nature, but should return cleanly when circular
#     dependencies are detected.
#
sub circular_link {

    my ( $children, $parent, $grandparent, $chain ) = @_;

    $chain ||= [];

    return 1 if grep { $_ eq $grandparent } @$chain; # link detected

    foreach my $child ( map { $_->trim_offset } @{$children->{$parent}} ) {

        push @$chain, $child;

        return 1 if circular_link( $children, $child, $grandparent, $chain );
    }

    return 0;
}


#
# groups
#
# Sent: nothing
# Return: list ( hashrefs )
# Purpose:
#
#     Build a list of all groups found in the schema, and keep track of
#     which mods and other groups and embedded within each.
#
#     For example, if the schema looks like:
#
#         group 001
#             [ ] 11111
#             group 002
#                 [ ] 22222
#             end
#             [ ] 33333
#         end
#
#     The list will look something like:
#
#         ( { id => 001, nodes => ['mod 11111', 'group 002', 'mod 33333'] }
#           { id => 002, nodes => ['mod 22222 ] )
#
sub groups {

    my $class = shift;

    my @lines = $class->significant_lines or return;

    my @groups = ();

    my $find_open_group = sub {

        my $open_group_idx;

        for ( my $idx = $#groups; $idx >= 0; $idx-- ) {

            if ( $groups[$idx]->{open} ) {

                $open_group_idx = $idx;

                last;
            }
        }

        return defined $open_group_idx ? $groups[$open_group_idx] : undef;
    };

    foreach my $line ( @lines ) {

        if ( $line->looks_like_a_group_start ) {

            my $group_id = $line->group_id;

            if ( @groups ) {

                my $last = $#groups;

                if ( $groups[$last]->{open} ) {

                    push @{$groups[$last]->{nodes}}, "group $group_id";
                }
            }

            push @groups, { id => $group_id, nodes => [], open => 1 };
        }
        elsif ( $line->looks_like_a_group_end ) {

            if ( my $open_group = $find_open_group->() ) {

                $open_group->{open} = 0;
            }
        }
        elsif ( $line->looks_like_a_mod ) {

            if ( my $open_group = $find_open_group->() ) {

                push @{$open_group->{nodes}}, "mod ".$line->mod_id;
            }
        }
    }

    foreach my $group ( @groups ) { # filter unique nodes

        my %nodes = map { $_ => 1 } @{$group->{nodes}};

        $group->{nodes} = [keys %nodes];
    }

    return @groups;
}


#
# normalize_group_offset
#
# Sent: nothing
# Return: instance ( for method chaining )
# Purpose:
#
#     The routine will normalize offsets within groups.
#
#     All of the following are technicallly equivalent, but the differences in
#     offset can cause problems for other routines, so this routine will adjust
#     the tabbing so they're all consistent.
#
#         group 001
#             [ ] 11111
#                 [ ] 22222
#                     [ ] 33333
#         end
#
#         group 001
#         [ ] 11111
#             [ ] 22222
#                 [ ] 33333
#         end
#
#         group 001
#     [ ] 11111
#         [ ] 22222
#             [ ] 33333
#         end
#
#         group 001
# [ ] 11111
#     [ ] 22222
#         [ ] 33333
#         end
#
#     After normalization, all groups will be formatted like this:
#
#         group 001
#             [ ] 11111
#                 [ ] 22222
#                     [ ] 33333
#         end
#
# Notes:
#
#     * This routine will side-affect the instance, changing the underlying text.
#       It should be safe to call multiple times, however.
#
#     * The routine does not need to handle the case where group members are
#       offset to the right by more than four spaces, as it is assumed the
#       schema will first validate its indenting.  A right offset of more than
#       four spaces is invalid, so this routine will not be called in that
#       instance.
#
sub normalize_group_offset {

    my $class = shift;

    my $text = "";

    my @groups = ();

    my $tab = $Dependency::Schema::Line::INDENT;

    foreach my $line ( $class->significant_lines ) {

        my $offset = $line->offset;

        pop @groups if $line->looks_like_a_group_end;

        my $open_group = $groups[$#groups];

        if ( $open_group && ! $open_group->{first_offset} ) {

            $open_group->{first_offset} = $offset;

            if ( length($open_group->{first_offset}) < length($open_group->{offset}) ) {

                my $diff = length($open_group->{offset}) - length($offset);

                $open_group->{offset_adjust} = $diff + $tab;
            }
            elsif ( length($open_group->{first_offset}) == length($open_group->{offset}) ) {

                $open_group->{offset_adjust} = $tab;
            }
        }

        if ( $open_group && $open_group->{offset_adjust} ) {

            $offset .= " " x $open_group->{offset_adjust};
        }

        $text .= $offset.$line->trim_offset."\n";

        push @groups, { offset => $offset } if $line->looks_like_a_group_start;
    }

    $class->{text} = $text;

    return $class;
}


#
# dependencies
#
# Sent: nothing
# Return: object ( Dependency::Schema )
# Purpose:
#
#     Return a new schema that includes only dependencies, those that
#     were defined explicitly, and those defined implicitly with groups.
#     The groups themselves will not be included in the output.
#
#     For example, if the schema looks like:
#
#         group 001
#             [ ] 111111
#             group 002
#                 [ ] 22222
#             end
#                 [ ] 33333
#         end
#
#     The text version of the resulting schema will look like:
#
#         start 001
#             end 001
#             mod 11111
#                 end 001
#             start 002
#                 end 002
#                 mod 22222
#                     end 002
#             end 002
#                 mod 33333
#                     end 001
#         end 001
#
sub dependencies {

    my $class = shift;

    my $string = "";

    my @groups = ();

    $class->normalize_group_offset;

    my $tab = " " x $Dependency::Schema::Line::INDENT;

    foreach my $line ( $class->significant_lines ) {

        my $offset = $line->offset;

        if ( $line->looks_like_a_group_start ) {

            $string .= $offset."start ".$line->group_id."\n";
            $string .= $offset.$tab."end ".$line->group_id."\n";

            push @groups, { id => $line->group_id, offset => $offset };
        }
        elsif ( $line->looks_like_a_mod ) {

            $string .= $offset."mod ".$line->mod_id."\n";

            if ( my $group = $groups[$#groups] ) {

                $string .= $offset.$tab."end ".$group->{id}."\n";
            }
        }
        elsif ( $line->looks_like_a_group_end ) {

            if ( my $group = pop @groups ) {

                $string .= $offset."end ".$group->{id}."\n";
            }

            if ( my $group = $groups[$#groups] ) {

               $string .= $offset.$tab."end ".$group->{id}."\n";
            }
        }
        elsif ( $line->looks_like_a_group_boundary ) {

            my $type; $line =~ /^\s*(start|end)/; $type = $1;

            $string .= $offset.$type." ".$line->group_id."\n";
        }
    }

    return Dependency::Schema->new( $string );
}


#
# errors
#
# Sent: list ( strings; optional )
# Return: list
# Purpose:
#
#     Setter and getter for the errors list.
#
sub errors {

    my $class = shift;

    push @{$class->{errors}}, join "", @_ if @_;

    return @{$class->{errors}};
}


#
# debug
#
# Sent: integer (true/false)
# Return: true/false
# Purpose:
#
#     Setter and getter for the debug option.
#
sub debug {

    my $class = shift;

    $class->{debug} = shift @_ if @_;

    return $class->{debug};
}


#
# new
#
# Sent: $string ( multi-line string )
# Return: object ( Dependency::Schema )
# Purpose:
#
#     Instantiate and return a schema for the supplied text.
#
sub new {

    my $class = shift;

    my ( $string ) = @_;

    my $self = {

        text   => $string || "",
        errors => [],
    };

    return bless $self, ref($class) || $class;
}


#
# test
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#     Test the Dependency::Schema, and Dependency::Schema::Line packages.
#
sub test {

    require Test::More; Test::More->import("no_plan");

    Dependency::Schema::Line::test();
    Dependency::Schema::Element::test();

    my $new     = sub { Dependency::Schema->new( @_ )                     };
    my $line    = sub { Dependency::Schema::Line->new( @_ )               };
    my $element = sub { Dependency::Schema::Element->new( $line->( @_ ) ) };

    # lines

    ok ( $new->('               # 1
        abc                     # 2
        def                     # 3
        ghi                     # 4
    ')->lines == 5, "lines1" ); # 5

    ok ( $new->('               # 1
        abc                     # 2
                                # 3
        def                     # 4
                                # 5
        ghi                     # 6
    ')->lines == 7, "lines2" ); # 7

    ok ( $new->('               # 1
        abc                     # 2
        # comment               # 3
        def                     # 4
        # comment               # 5
        ghi                     # 6
    ')->lines == 7, "lines3" ); # 7

    # significant_lines

    ok ( $new->('                                       # - blank
        abc                                             # 1
        def                                             # 2
        ghi                                             # 3
    ')->significant_lines == 3, "significant_lines1" ); # - blank

    ok ( $new->('                                       # - blank
        abc                                             # 1
        # comment                                       # - comment
        def                                             # 2
        # comment                                       # - comment
        ghi                                             # 3
    ')->significant_lines == 3, "significant_lines2" ); # - blank

    # has_valid_indenting

    ok ( $new->()->has_valid_indenting, "has_valid_indenting1");

    ok ( ! $new->('

    abc
     abc
      abc
     abc
    abc

    ')->has_valid_indenting, "has_valid_indenting2" );

    ok ( ! $new->('

    abc
      abc
        abc
      abc
    abc

    ')->has_valid_indenting, "has_valid_indenting3" );

    ok ( ! $new->('

    abc
       abc
          abc
       abc
    abc

    ')->has_valid_indenting, "has_valid_indenting4" );

    ok ( $new->('

    abc
        abc
            abc
        abc
    abc

    ')->has_valid_indenting, "has_valid_indenting5" );

    ok ( ! $new->('

    abc
         abc
              abc
         abc
    abc

    ')->has_valid_indenting, "has_valid_indenting6" );

    ok ( $new->('

    abc
     # comment
      # comment
        abc
         # comment
          # comment
            abc

    ')->has_valid_indenting, "has_valid_indenting7" );

    # all_groups_unique

    ok ( $new->('

        group 001
        end
        group 002
        end
        group 003
        end

    ')->all_groups_unique, "all_groups_unique1" );

    ok ( ! $new->('

        group 001
        end
        group 002
        end
        group 001
        end

    ')->all_groups_unique, "all_groups_unique2" );

    # has_valid_group_offsets

    ok ( $new->('

        group 111
        end

    ')->has_valid_group_offsets, "has_valid_group_offsets1" );

    ok ( $new->('

        group 111
            group 222
            end
        end

    ')->has_valid_group_offsets, "has_valid_group_offsets2" );

    ok ( ! $new->('

        group 111
            end

    ')->has_valid_group_offsets, "has_valid_group_offsets3" );

    ok ( ! $new->('

        group 111
            group 222
        end
            end

    ')->has_valid_group_offsets, "has_valid_group_offsets4" );

    # all_groups_closed

    ok ( $new->('

        group 111
        end
        group 222
        end
        group 333
        end

    ')->all_groups_closed, "all_groups_closed1" );

    ok ( ! $new->('

        group 111
        end
        group 222
        end
        group 333

    ')->all_groups_closed, "all_groups_closed2" );

    ok ( ! $new->('

        group 111
            group 222
        end
        group 333
        end

    ')->all_groups_closed, "all_groups_closed3" );

    # has_valid_group_boundaries

    ok ( $new->('

        group 111
            group 222
            end
        end

        start 111
        end 111
        start 222
        end 222

    ')->has_valid_group_boundaries, "has_valid_group_boundaries1" );

    ok ( ! $new->('

        group 111
            group 222
            end
        end

        start 333
        end 111
        start 222
        end 222

    ')->has_valid_group_boundaries, "has_valid_group_boundaries2" );

    ok ( ! $new->('

        group 111
            group 222
            end
        end

        start 111
        end 111
        start 222
        end 333

    ')->has_valid_group_boundaries, "has_valid_group_boundaries3" );

    # has_valid_groups

    ok ( $new->('

        group 111
            [ ] 11111
            group 222
                [ ] 22222
                [ ] 33333
            end
            [ ] 44444
        end

    ')->has_valid_groups, "has_valid_groups1" );

    ok ( ! $new->('

        group 111
            group 111
            end
        end

    ')->has_valid_groups, "has_valid_groups2" ); # opened twice

    ok ( ! $new->('

        group 111
            [ ] 11111
            group 222
                [ ] 22222
                [ ] 33333
        end
            [ ] 44444
            end

    ')->has_valid_groups, "has_valid_groups3" ); # overlap

    ok ( ! $new->('

        group 111
            [ ] 11111
            group 222
                [ ] 22222
                [ ] 33333
            end
            [ ] 44444

    ')->has_valid_groups, "has_valid_groups4" ); # missing end

    ok ( $new->('

        group 111
            [ ] 11111
            group 222
                [ ] 22222
            end
            [ ] 33333
        end

        start 111
        end 222

    ')->has_valid_groups, "has_valid_groups5" );

    ok ( ! $new->('

        group 111
            [ ] 11111
            group 222
                [ ] 22222
            end
            [ ] 33333
        end

        start 333
        end 222

    ')->has_valid_groups, "has_valid_groups6" );

    ok ( ! $new->('

        group 111
            [ ] 11111
            group 222
                [ ] 22222
            end
            [ ] 33333
        end

        start 111
        end 333

    ')->has_valid_groups, "has_valid_groups7" );

    # groups

    group1: {

        my @groups = $new->('

            [ ] 00000
            group 111
                [ ] 11111
                group 222
                    [ ] 22222
                    [ ] 33333
                end
                [ ] 44444
            end
            [ ] 55555

    ')->groups;

        @groups = sort { $a->{id} <=> $b->{id} } @groups;

        ok ( @groups == 2, "groups1" );
        ok ( ( grep { $_->{id} == 111 } @groups ), "groups2" );
        ok ( ( grep { $_->{id} == 222 } @groups ), "groups3" );
        ok ( @{$groups[0]->{nodes}} == 3, "groups4" ); # 11111, group 222, 44444
        ok ( @{$groups[1]->{nodes}} == 2, "groups5" ); # 22222, 33333
        ok ( ! $groups[0]->{open}, "groups6" );
        ok ( ! $groups[1]->{open}, "groups7" );
    }

    group2: {

        my @groups = $new->('

            group 111
                [ ] 11111
                group 222
                    [ ] 22222
                end

    ')->groups;

        @groups = sort { $a->{id} <=> $b->{id} } @groups;

        ok ( @groups == 2, "groups8" );
        ok ( ( grep { $_->{id} == 111 } @groups ), "groups9" );
        ok ( ( grep { $_->{id} == 222 } @groups ), "groups10" );
        ok ( @{$groups[0]->{nodes}} == 2, "groups11" ); # 11111, group 222
        ok ( @{$groups[1]->{nodes}} == 1, "groups12" ); # 22222
        ok (   $groups[0]->{open}, "groups13" );
        ok ( ! $groups[1]->{open}, "groups14" );
    }

    # normalize_group_offset;

    ok ( $new->('
        group 001
            [ ] 11111
                [ ] 22222
                    [ ] 33333
        end
    ')->normalize_group_offset->text eq
'        group 001
            [ ] 11111
                [ ] 22222
                    [ ] 33333
        end
', "normalize_group_offset1" );

    ok ( $new->('
        group 001
        [ ] 11111
            [ ] 22222
                [ ] 33333
        end
    ')->normalize_group_offset->text eq
'        group 001
            [ ] 11111
                [ ] 22222
                    [ ] 33333
        end
', "normalize_group_offset2" );

    ok ( $new->('
        group 001
    [ ] 11111
        [ ] 22222
            [ ] 33333
        end
    ')->normalize_group_offset->text eq
'        group 001
            [ ] 11111
                [ ] 22222
                    [ ] 33333
        end
', "normalize_group_offset3" );

    ok ( $new->('
        group 001
            [ ] 11111
            group 002
                [ ] 2222
            end
        end
    ')->normalize_group_offset->text eq
'        group 001
            [ ] 11111
            group 002
                [ ] 2222
            end
        end
', "normalize_group_offset4" );

    ok ( $new->('
        group 001
            [ ] 11111
            group 002
            [ ] 2222
            end
        end
    ')->normalize_group_offset->text eq
'        group 001
            [ ] 11111
            group 002
                [ ] 2222
            end
        end
', "normalize_group_offset5" );

    ok ( $new->('
        group 001
        [ ] 11111
        group 002
        [ ] 2222
        end
        end
    ')->normalize_group_offset->text eq
'        group 001
            [ ] 11111
            group 002
                [ ] 2222
            end
        end
', "normalize_group_offset6" );

    ok ( $new->('
        group 001
[ ] 11111
group 002
    [ ] 2222
end
        end
    ')->normalize_group_offset->text eq
'        group 001
            [ ] 11111
            group 002
                [ ] 2222
            end
        end
', "normalize_group_offset7" );

    # dependencies

    ok( $new->('

group 001
end

')->dependencies->text eq
'start 001
    end 001
end 001
', "dependencies1");

    ok( $new->('

group 001
end
start 001
    end 001

')->dependencies->text eq
'start 001
    end 001
end 001
start 001
    end 001
', "dependencies2");

    ok( $new->('

group 002
end
group 001
    start 002
    end 002
end

')->dependencies->text eq
'start 002
    end 002
end 002
start 001
    end 001
    start 002
    end 002
end 001
', "dependencies3");

    ok( $new->('

group 001
    group 002
    end
end

')->dependencies->text eq
'start 001
    end 001
    start 002
        end 002
    end 002
        end 001
end 001
', "dependencies4");

    ok( $new->('

group 001
group 002
end
end

')->dependencies->text eq
'start 001
    end 001
    start 002
        end 002
    end 002
        end 001
end 001
', "dependencies5");

    ok( $new->('

group 001
    [ ] 1111
        [ ] 2222
end

')->dependencies->text eq
'start 001
    end 001
    mod 1111
        end 001
        mod 2222
            end 001
end 001
', "dependencies6");

    ok( $new->('

group 001
[ ] 1111
    [ ] 2222
end

')->dependencies->text eq
'start 001
    end 001
    mod 1111
        end 001
        mod 2222
            end 001
end 001
', "dependencies7");

    ok( $new->('

group 001
    [ ] 1111
    group 002
        [ ] 2222
        [ ] 3333
    end
        [ ] 4444
end

')->dependencies->text eq
'start 001
    end 001
    mod 1111
        end 001
    start 002
        end 002
        mod 2222
            end 002
        mod 3333
            end 002
    end 002
        end 001
        mod 4444
            end 001
end 001
', "dependencies8");

    # children_for_line

    ok ( ($new->('   # 1
        aaa          # 2
            bbb      # 3
            ccc      # 4
        ddd          # 5
            eee      # 6
    ')->children_for_line(2))[0]->text eq '            bbb      # 3', "children_for_line1" );

    ok ( ($new->('   # 1
        aaa          # 2
            bbb      # 3
            ccc      # 4
        ddd          # 5
            eee      # 6
    ')->children_for_line(2))[1]->text eq '            ccc      # 4', "children_for_line2" );

    ok ( ($new->('   # 1
        aaa          # 2
            bbb      # 3
            ccc      # 4
        ddd          # 5
            eee      # 6
    ')->children_for_line(5))[0]->text eq '            eee      # 6', "children_for_line3" );

    ok ( ! $new->('  # 1
        aaa          # 2
            bbb      # 3
            ccc      # 4
        ddd          # 5
            eee      # 6
    ')->children_for_line(4), "children_for_line4" );

    # children_by_line_content

    my $children_by_line_content = $new->('

        aaa
            bbb
            ccc
        ddd
            eee
        aaa
            fff

    ')->children_by_line_content;

    ok (      $children_by_line_content->{aaa}->[0]->trim_offset eq 'bbb'
         &&   $children_by_line_content->{aaa}->[1]->trim_offset eq 'ccc'
         &&   $children_by_line_content->{aaa}->[2]->trim_offset eq 'fff'
         && ! $children_by_line_content->{bbb}
         && ! $children_by_line_content->{ccc}
         &&   $children_by_line_content->{ddd}->[0]->trim_offset eq 'eee'
         && ! $children_by_line_content->{eee}

    , "children_by_line_content1" );

    # parent_for_line

    ok ( ! $new->('  # 1
        aaa          # 2
            bbb      # 3
            ccc      # 4
        ddd          # 5
            eee      # 6
    ')->parent_for_line(1), "parent_for_line1" );

    ok ( ! $new->('  # 1
        aaa          # 2
            bbb      # 3
            ccc      # 4
        ddd          # 5
            eee      # 6
    ')->parent_for_line(2), "parent_for_line2" );

    ok ( ($new->('   # 1
        aaa          # 2
            bbb      # 3
            ccc      # 4
        ddd          # 5
            eee      # 6
    ')->parent_for_line(3))->text eq '        aaa          # 2', "parent_for_line3" );

    ok ( ($new->('   # 1
        aaa          # 2
            bbb      # 3
            ccc      # 4
        ddd          # 5
            eee      # 6
    ')->parent_for_line(4))->text eq '        aaa          # 2', "parent_for_line4" );

    ok ( ! $new->('  # 1
        aaa          # 2
            bbb      # 3
            ccc      # 4
        ddd          # 5
            eee      # 6
    ')->parent_for_line(5), "parent_for_line5" );

    ok ( ($new->('   # 1
        aaa          # 2
            bbb      # 3
            ccc      # 4
        ddd          # 5
            eee      # 6
    ')->parent_for_line(6))->text eq '        ddd          # 5', "parent_for_line6" );

    # parents_by_line_content

    my $parents_by_line_content = $new->('

        aaa
            bbb
            ccc
        ddd
            eee
        fff
            bbb

    ')->parents_by_line_content;

    ok (    ! $parents_by_line_content->{aaa}
         &&   $parents_by_line_content->{bbb}->[0]->trim_offset eq 'aaa'
         &&   $parents_by_line_content->{bbb}->[1]->trim_offset eq 'fff'
         &&   $parents_by_line_content->{ccc}->[0]->trim_offset eq 'aaa'
         && ! $parents_by_line_content->{ddd}
         &&   $parents_by_line_content->{eee}->[0]->trim_offset eq 'ddd'
         && ! $parents_by_line_content->{fff}

    , "parents_by_line_content1" );

    # has_circular_dependencies

    ok ( $new->('

        [ ] 11111
            [ ] 11111

    ')->has_circular_dependencies, "has_circular_dependencies1" );

    ok ( ! $new->('

        [ ] 11111
            [ ] 22222

    ')->has_circular_dependencies, "has_circular_dependencies2" );

    ok ( $new->('

        [ ] 11111
            [ ] 22222
                [ ] 11111

    ')->has_circular_dependencies, "has_circular_dependencies3" );

    ok ( $new->('

        [ ] 11111
            [ ] 22222
                [ ] 33333
                    [ ] 22222

    ')->has_circular_dependencies, "has_circular_dependencies4" );

    ok ( $new->('

        [ ] 11111
            [ ] 22222
                [ ] 33333
                    [ ] 22222
                        [ ] 44444

    ')->has_circular_dependencies, "has_circular_dependencies5" );

    ok ( $new->('

        [ ] 11111
            [ ] 22222
                [ ] 11111 extra stuff (should still be considered 11111)

    ')->has_circular_dependencies, "has_circular_dependencies6" );

    ok ( $new->('

        [ ] 11111
            [ ] 22222
        [ ] 22222
            [ ] 33333
        [ ] 33333
            [ ] 11111

    ')->has_circular_dependencies, "has_circular_dependencies7" );

    ok ( ! $new->('

        [ ] 11111
            [ ] 22222
        [ ] 22222
            [ ] 33333
        [ ] 33333
            [ ] 44444

    ')->has_circular_dependencies, "has_circular_dependencies8" );

    ok ( ! $new->('

        group 001
            [ ] 11111
        end

    ')->has_circular_dependencies, "has_circular_dependencies9" );

    ok ( $new->('

        group 001
            [ ] 11111
        end

        [ ] 11111
            start 001

    ')->has_circular_dependencies, "has_circular_dependencies10" );

    # has_valid_dependencies

    ok ( $new->('

        group 001
            [ ] 11111
                [ ] 22222
            group 002
                [ ] 22222
                    [ ] 33333
            end
            [ ] 33333
                [ ] 44444
        end

    ')->has_valid_dependencies, "has_valid_dependencies1" );

    ok ( ! $new->('

        group 001
            [ ] 11111
                [ ] 22222
            group 002
                [ ] 22222
                    [ ] 33333
            end
            [ ] 33333
                [ ] 44444
        end

        [ ] 33333
            start 001 # comment ?

    ')->has_valid_dependencies, "has_valid_dependencies2" );

    # elements

    my @elements =$new->('

        start 111
            [ ] 11111
                end 111
        [ ] 22222
        [ ] 33333

    ')->elements;

    ok (      @elements == 5
         && ( $elements[0]->type eq 'group_boundary' && $elements[0]->id == 111   )
         && ( $elements[1]->type eq 'mod'            && $elements[1]->id == 11111 )
         && ( $elements[2]->type eq 'group_boundary' && $elements[2]->id == 111   )
         && ( $elements[3]->type eq 'mod'            && $elements[3]->id == 22222 )
         && ( $elements[4]->type eq 'mod'            && $elements[4]->id == 33333 ),

            "elements1" );

    # mods

    my @mods =$new->('

        start 111
            [ ] 11111
                end 111
        [ ] 22222
        [ ] 33333

    ')->mods;

    ok (      @mods == 3
         && ( $mods[0]->type eq 'mod' && $mods[0]->id == 11111 )
         && ( $mods[1]->type eq 'mod' && $mods[1]->id == 22222 )
         && ( $mods[2]->type eq 'mod' && $mods[2]->id == 33333 ),

            "mods1" );

    # parents_for_element


    parents_for_element: {

        my $schema = $new->('
            group 111
                [ ] 11111
                [ ] 22222
            end
                [ ] 33333
            [ ] 44444
                [ ] 11111
        ');

        ok ( ! $schema->parents_for_element( $element->("start 111") ),      "parents_for_element1" );
        ok (   $schema->parents_for_element( $element->("mod 11111") ) == 2, "parents_for_element2" );
        ok (   $schema->parents_for_element( $element->("mod 22222") ) == 1, "parents_for_element3" );
        ok (   $schema->parents_for_element( $element->("end 111") )   == 3, "parents_for_element4" );
        ok (   $schema->parents_for_element( $element->("mod 33333") ) == 1, "parents_for_element5" );
        ok ( ! $schema->parents_for_element( $element->("mod 44444") ),      "parents_for_element6" );

        ok (    ( $schema->parents_for_element( $element->("mod 11111") ) )[0]->type eq 'group_boundary'
             && ( $schema->parents_for_element( $element->("mod 11111") ) )[0]->id   == 111
             && ( $schema->parents_for_element( $element->("mod 11111") ) )[1]->type eq 'mod'
             && ( $schema->parents_for_element( $element->("mod 11111") ) )[1]->id   == 44444
             && ( $schema->parents_for_element( $element->("mod 22222") ) )[0]->type eq 'group_boundary'
             && ( $schema->parents_for_element( $element->("mod 22222") ) )[0]->id   == 111
             && ( $schema->parents_for_element( $element->("mod 33333") ) )[0]->type eq 'group_boundary'
             && ( $schema->parents_for_element( $element->("mod 33333") ) )[0]->id   == 111
             && ( $schema->parents_for_element( $element->("end 111")   ) )[0]->id   == 111
             && ( $schema->parents_for_element( $element->("end 111")   ) )[1]->id   == 11111
             && ( $schema->parents_for_element( $element->("end 111")   ) )[2]->id   == 22222,

                "parents_for_element7" );
    }

    # all_parents_for_element_done

    all_parents_for_element_done: {

        my $schema = $new->('
            group 111
                group 222
                end
                group 333
                end
            end
        ');

        ok ( $schema->all_parents_for_element_done( $element->("start 111") ), "all_parents_for_element_done1" );
        ok ( $schema->all_parents_for_element_done( $element->("start 222") ), "all_parents_for_element_done2" );
        ok ( $schema->all_parents_for_element_done( $element->("end 222") ),   "all_parents_for_element_done3" );
        ok ( $schema->all_parents_for_element_done( $element->("start 333") ), "all_parents_for_element_done4" );
        ok ( $schema->all_parents_for_element_done( $element->("end 333") ),   "all_parents_for_element_done5" );
        ok ( $schema->all_parents_for_element_done( $element->("end 111") ),   "all_parents_for_element_done6" );

        $schema = $new->('
            group 111
                [ ] 11111
                    group 222
                    end
                group 333
                end
            end
        ');

        ok (   $schema->all_parents_for_element_done( $element->("start 111") ), "all_parents_for_element_done7" );
        ok ( ! $schema->all_parents_for_element_done( $element->("start 222") ), "all_parents_for_element_done8" );
        ok ( ! $schema->all_parents_for_element_done( $element->("end 222") ),   "all_parents_for_element_done9" );
        ok (   $schema->all_parents_for_element_done( $element->("start 333") ), "all_parents_for_element_done10" );
        ok (   $schema->all_parents_for_element_done( $element->("end 333") ),   "all_parents_for_element_done11" );
        ok ( ! $schema->all_parents_for_element_done( $element->("end 111") ),   "all_parents_for_element_done12" );
    }

    # available_mods

    tests_for_available_mods: {

        # prepare test data

        # local $ENV{DM_ROOT} = "/tmp/dm";

        my $path = $options->{dm_root};

        mkdir "$path/mods" unless -d "$path/mods";
        mkdir "$path/archive" unless -d "$path/archive";

        my $simulate_done = sub { mkdir sprintf("%s/archive/%s", $path, shift) };
        my $simulate_hold = sub {

            my ( $id ) = @_;

            mkdir sprintf("%s/mods/%s", $path, $id);

            open my $hold, ">", sprintf("%s/mods/%s/hold", $path, $id);
            print $hold '2999-12-31 12:34:56';
            close $hold;
        };

        # start tests

        my $schema = $new->('

            group 001
                [ ] 11111
                group 002
                    [ ] 22222
                    [ ] 33333
                        [ ] 44444
                end
                    [ ] 55555
            end
                [ ] 66666

        ');

        my @available_mods = $schema->available_mods;

        ok (    @available_mods == 3
             && $available_mods[0]->id == 11111
             && $available_mods[1]->id == 22222
             && $available_mods[2]->id == 33333,

                "available_mods1" );

        $simulate_hold->(33333);

           @available_mods = $schema->available_mods;


        ok (    @available_mods == 2
             && $available_mods[0]->id == 11111
             && $available_mods[1]->id == 22222,

                "available_mods2" );

        $simulate_done->(33333);

           @available_mods = $schema->available_mods;

        ok (    @available_mods == 3
             && $available_mods[0]->id == 11111
             && $available_mods[1]->id == 22222
             && $available_mods[2]->id == 44444,

                "available_mods3" );

        $simulate_done->(22222);

           @available_mods = $schema->available_mods;

        ok (    @available_mods == 2
             && $available_mods[0]->id == 11111
             && $available_mods[1]->id == 44444,

                "available_mods4" );

        $simulate_done->(44444);

           @available_mods = $schema->available_mods;

        ok (    @available_mods == 2
             && $available_mods[0]->id == 11111
             && $available_mods[1]->id == 55555,

                "available_mods5" );

        $simulate_done->(11111);

           @available_mods = $schema->available_mods;

        ok (    @available_mods == 1
             && $available_mods[0]->id == 55555,

                "available_mods6" );

        $simulate_done->(55555);

           @available_mods = $schema->available_mods;

        ok (    @available_mods == 1
             && $available_mods[0]->id == 66666,

                "available_mods7" );

        $simulate_done->(66666);

           @available_mods = $schema->available_mods;

        ok ( @available_mods == 0, "available_mods8" );

        # cleanup test data

        unlink $path."/mods/33333/hold";
         rmdir $path."/mods/33333";
         rmdir $path."/mods";
         rmdir $path."/archive";
         rmdir $path."/archive/11111";
         rmdir $path."/archive/22222";
         rmdir $path."/archive/33333";
         rmdir $path."/archive/44444";
         rmdir $path."/archive/55555";
         rmdir $path."/archive/66666";
         rmdir $path."/archive";

        1;
    }

    return;
}

1;

#
# Dependency::Schema::Element
#
# Purpose:
#
#     Each instance acts as a single element in the dependency tree.
#     An element is either a mod, a group start, or a group end.
#
#     This package technically acts as a factory for more specific
#     element types.  Passing a line with content "mod 1234" to the
#     constructor, will actually return an instance of
#     Dependency::Schema::Element::Mod.
#
package Dependency::Schema::Element;

use strict;

#
# new
#
# Sent: $line ( object; Dependency::Schema::Line )
# Return: object (    Dependency::Schema::Element::Mod
#                  OR Dependency::Schema::Element::Group::Boundary )
# Purpose:
#
#     Contstructor for element objects.
#
# Notes:
#
#   * This method will only cast lines that represent valid dependency
#     tokens (examples: "mod 1234", "start 123", "end 123").
#
sub new {

    my $class = shift;

    my ( $line ) = @_;

    if ( $line->trim_offset =~ /^mod\s(\d+)/ ) {

        return Dependency::Schema::Element::Mod->new( $line, $1 );
    }
    elsif ( $line->trim_offset =~ /^(?:start|end)\s(\d+)/ ) {

        return Dependency::Schema::Element::Group::Boundary->new( $line, $1 );
    }

    die "invalid line supplied: $line, unable to cast as element (mod or group boundary)";
}


#
# test
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#     Perform tests on Dependency::Schema::Element.
#
sub test {

    require Test::More; Test::More->import;

    my $line = sub { Dependency::Schema::Line->new( @_ )    };
    my $new  = sub { Dependency::Schema::Element->new( @_ ) };

    ok ( ! eval { $new->( $line->("") )->type }, "element_type1" );
    ok ( ! eval { $new->( $line->("[ ] 12345") )->type }, "element_type2" );
    ok ( ! eval { $new->( $line->("# comment") )->type }, "element_type2" );
    ok ( ! eval { $new->( $line->("group 123") )->type }, "element_type3" );
    ok ( ! eval { $new->( $line->("end") )->type }, "element_type4" );
    ok ( $new->( $line->("mod 12345") )->type eq 'mod', "element_type5" );
    ok ( $new->( $line->("start 111") )->type eq 'group_boundary', "element_type6" );
    ok ( $new->( $line->("end 111") )->type eq 'group_boundary', "element_type7" );

    Dependency::Schema::Element::Mod::test();
    Dependency::Schema::Element::Group::Boundary::test();

    return;
}


#
# Dependency::Schema::Element::Mod
#
# Purpose:
#
#     Represents a single instance of a mod within a dependency schema.
#
package Dependency::Schema::Element::Mod;

use strict;

use overload '""' => "id"; # stringified form is the id

sub type { "mod"           } # attributes
sub id   { (shift)->{id}   }
sub line { (shift)->{line} }

#
# new
#
# Sent: $line, $id ( Dependency::Schema::Line, integer )
# Return: object
# Purpose:
#
#     Create and return a new mod instance.  The original line
#     will be accessible from the "line" attribute.  A unique id
#     is required.
#
sub new {

    my $class = shift;

    my ( $line, $id ) = @_;

    die "element id is required" unless $id;

    return bless { line => $line, id => $id }, ref($class) || $class;
}


#
# on_hold
#
# Sent: nothing
# Return: true/false (1/0)
# Purpose:
#
#     Return true if this mod is on hold.  The mod is on hold if
#     there exists a "hold" file in its directory and the last line of
#     the file is not a comment.
#
sub on_hold {

    my $class = shift;

    my $file = sprintf("%s/mods/%s/hold", $options->{dm_root}, $class->id);

    return 0 unless -f $file
                  && -r $file;

    my $last = `tail -1 $file`; chomp $last;

    return 0 unless $last;

    return 0 if $last =~ /^#/;     # Last line is commented

    return 1;
}


#
# is_done
#
# Sent: nothing
# Return: true/false (1/0)
# Purpose:
#
#     Return true if the mod is done.  The mod is done if it is
#     located within the archive/ subdirectory.
#
sub is_done {

    my $class = shift;

    my $path = sprintf("%s/archive/%s", $options->{dm_root}, $class->id);

    return -d $path ? 1 : 0;
}


#
# test
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#     Perform tests on this package.
#
sub test {

    require Test::More; Test::More->import;

    my $line = sub { Dependency::Schema::Line->new( @_ )    };
    my $new  = sub { Dependency::Schema::Element::Mod->new( @_ ) };

    my $mod = $new->( $line->("mod 123"), 123 );

    ok ( "$mod" eq "123", "overload1" );

    test_statuses: {

        #local $ENV{DM_ROOT} = "/tmp/dm";
        my $dm_root = $options->{dm_root};

        # create test data

        my $id = '000000001';

        mkdir "${dm_root}";
        mkdir "${dm_root}/mods";
        mkdir "${dm_root}/mods/$id";
        mkdir "${dm_root}/archive";

        # on_hold

        my $mod = $new->( $line->("mod 1"), $id );

        ok ( ! $mod->on_hold, "on_hold1" );

        my $hold = sprintf("%s/mods/%s/hold", $options->{dm_root}, $id );

        `echo '# 59 23 31 12 * \$HOME/dm/bin/take_of_hold.sh 12345' > $hold`;
        ok ( ! $mod->on_hold, "on_hold2" );      # crontab is commented out

        `echo '59 23 31 12 * \$HOME/dm/bin/take_of_hold.sh 12345' > $hold`;
        ok ( $mod->on_hold, "on_hold3" );


        # is_done

        ok ( ! $mod->is_done, "is_done1" );

        system("mv ${dm_root}/mods/$id ${dm_root}/archive/");

        ok ( $mod->is_done, "is_done2" );

        # clean up test data

        unlink "${dm_root}/archive/$id/hold";
         rmdir "${dm_root}/archive/$id";
         rmdir "${dm_root}/archive";
         rmdir "${dm_root}/mods";
    }

    return;
}

1;

#
# Dependency::Schema::Element::Group::Boundary
#
# Purpose:
#
#     Represents a single group boundary found within the schema
#     (ie. "start 123", "end 123").
#
package Dependency::Schema::Element::Group::Boundary;

use strict;

sub type { "group_boundary" } # attributes
sub id   { (shift)->{id}    }
sub line { (shift)->{line}  }

#
# new
#
# Sent: $line, $id ( Dependency::Schema::Line, integer )
# Return: object
# Purpose:
#
#    Create and return a new group boundary instance.
#
sub new {

    my $class = shift;

    my ( $line, $id ) = @_;

    return bless { line => $line, id => $id }, ref($class) || $class;
}


#
# test
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#     Perform tests on this package.
#
# Notes:
#
#   * Presently nothing to test.
#
sub test {

    require Test::More; Test::More->import;

    my $line = sub { Dependency::Schema::Line->new( @_ )    };
    my $new  = sub { Dependency::Schema::Element::Group::Boundary->new( @_ ) };

    return;
}

1;

__END__

=head1 NAME

dependency_schema.pl

=head1 SYNOPSIS

cat dependencies | dependency_schema.pl /path/to/dm/root [options]

Options:

    --mods,      -m    Display a list of all mods in the schema.
    --available, -a    Display a list of all available mods to be worked on (implies --mods).

    --test,      -t    Perform integrated tests, ignore input.
    --debug,     -d    Display debug information while validating.

    --help,      -?    Show usage instructions.
    --man              Show man page.

If no options are provided, the script will merely validate the schema.

Examples:

    $ cat dependencies | dependency_schema.pl

    $ cat dependencies | dependency_schema.pl --mods

    $ cat dependencies | dependency_schema.pl --available


=head1 DESCRIPTION

This script will validate a dependency tree and optionally print
a list of mods found within (either all mods, or only those available
to be worked on).  The script will exit with a status of one (1) if
the supplied dependency schema is not formatted correctly.  Errors will
be printed to STDERR.

B<Schema Formatting Rules>

1. The first non-whitespace characters of a line must be
   one of:

       # [ start end

2. If the first non-whitespace character of a line is [,
   it must have this syntax:

       [x] 12345 optional text

   (opening square bracket, one character, closing square bracket,
   one space, an integer, followed by anything)

3a. If the first non-whitespace character of a line is 'group', it
    must have this syntax:

        group 123 optional text

    (the word group, one space, an integer, followed by anything)


4a. Every group tag must have an end tag that follows at some point with the
    same indent level.


        # Good
        group 123
        end

        # Error
        group 123

        # Error
        group 123
            end

        # Good
        group 111
            group 222
            end
        end

4b. End tags must come in reverse order of group tags.

       # Good
       group 111
           group 222
           end
       end

       # Error
       group 111
           group 222
       end
           end


5. Every indent must be a multiple of 4 spaces and every child 4 spaces
   from the parent. Comment lines are exempt from this rule.

       # Good
       group 123
           [ ] 11111
               [ ] 22222
       end

       # Error
       [ ] 11111
         [ ] 22222

       # Error
       [ ] 11111
               [ ] 22222

       # Ok
       [ ] 11111
               #[ ] 22222


6. Dependencies cannot be recursive.

       # Error
       [ ] 11111
           [ ] 11111

       # Error
       [ ] 11111
           [ ] 22222
               [ ] 11111

       # Error
       [ ] 1111
           [ ] 2222
               [ ] 3333
       [ ] 3333
           [ ] 1111

       # Error
       [ ] 1111
           [ ] 2222
       [ ] 2222
           [ ] 3333
       [ ] 3333
           [ ] 1111

