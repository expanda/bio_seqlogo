package Bio::SeqLogo::Symvec;

use strict;
use warnings;
use Carp;
use Bio::SeqLogo::Symvec::Accessor;
use Data::Dumper;

sub new {
    my $pkg = shift;

    my $args = {
        file => '',
        @_
    };

    my $this = bless {
        _file => $args->{file},
    }, $pkg;

    $this->parse_file;

    return $this;
}

sub docset {
    my $this = shift;
    return $this->{_docset};
}

sub parse_file {
    my $this = shift;

    open my $source , $this->{_file}
    || croak "Cannot open file $$this{_file}, Die";

    my ( $class, $tmploc_pos , $tmploc, $tmpsym,
        $num_seq, $bits, $variance );

    while(<$source>) {
        if ( /^\*/ ) {
            next;
        }
        elsif ( /^\s+?([0-9\-]+)\s*(\d+)\s*([0-9\.\-]+)\s*([0-9\.e\-]+)/ ) {
            print qq{$1\t$2\t$3\t$4\n};
            # Position header
            # Save position information
            if ( defined($tmploc) && scalar(@{$tmploc}) > 0 ) {
                $class->{$tmploc_pos}->{symbols} = $tmploc;
                $class->{$tmploc_pos}->{entropy} = $bits;
                $class->{$tmploc_pos}->{variance} = $variance;
            }

            # Clear position information
            ( $tmploc_pos, $num_seq, $bits, $variance, $tmploc ) = ();

            # Save $tmploc_pos and $score, $entropy
            ( $tmploc_pos, $num_seq, $bits, $variance ) = ($1, $2, $3, $4);
        }
        elsif ( /^([a-zA-Z])\s*(\d+)/ ) {
            # Character / Count
            print qq{$1\t$2\n};
            $tmpsym->{type} = uc $1;
            $tmpsym->{score} = $2 / $num_seq * $bits; #( $2 / $num_seq ) * $bits;
            push @{$tmploc}, $tmpsym;
            undef $tmpsym;

        }
    }

    push @{$this->{_docset}}, Bio::SeqLogo::Symvec::Accessor->new($class);

    return $this;
}


1;

__END__

=pod

=head1 NAME

Bio::SeqLogo::Symvec - Input file parser for Bio::SeqLogo

=head1 SYNOPSIS

    use Bio::SeqLogo::Symvec

    my $xml = Bio::SeqLogo::Symvec->new( file => 'file.xml' );

    for my $class ( $class->docset ) {
     # now $class is instance of Bio::SeqLogo::Symvec::Class.
     ...
    }

=head1 Symvec Format

=head2 DEFINITION

A "symbol vector" file usually created by the alpro or dalvec program.  Makelogo will ignore any number of header lines that beginwith "*".  The next line contains one number (k) that defines the number of letters in the alphabet.  and then defines the composition of letters at each position in the set of aligned sequences.
Each composition begins with 4 numbers on one line:

=over 4

=item 1. position (integer);

=item 2. number of sequences at that position (integer);

=item 3. information content of the position (real);

=item 4. variance of the information content (real).

=back

This is followed by k lines.  The first character on the line is the character.  This is followed by the number of that character at that position.

=head2 Example

    * position, number of sequences, information Rs, variance of Rs
    4 number of symbols in DNA or RNA
    -100       86 -0.00820  6.3319e-04
    a   27
    c   18
    g   20
    t   21
    -99       86 -0.00436  6.3319e-04
    a   26
    c   19
    g   17
    t   24

=head1 Methods

=over 4

=item new

=item docset

=item parse_file

=back

=head1 SEE ALSO

L<http://www.ccrnp.ncifcrf.gov/~toms/delila/makelogo.html>

=head1 AUTHOR

Hiroyuki Nakamura, C<< <hryk at cpan.org> >>

=cut
