package Bio::SeqLogo::XML;

use strict;
use warnings;
use Carp;
use XML::Parser;
use File::Spec;
use Data::Dumper;
use Bio::SeqLogo::XML::Handlers;

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
    my $p = XML::Parser->new(Style => 'Stream',
        Pkg => 'Bio::SeqLogo::XML::Handlers',
    );

    open my $source , $$this{_file}
    || croak "Cannot open file $$this{_file}, Die";

    my $str = "";
    {
        local $/;
        $str = <$source>;
    }

    $p->parse($str);

    $this->{_docset} = Bio::SeqLogo::XML::Handlers->docset();
    Bio::SeqLogo::XML::Handlers->clean();

    return $this;
}

1;

__END__

=pod

=head1 NAME

Bio::SeqLogo::XML - Input file parser for Bio::SeqLogo

=head1 SYNOPSIS

    use Bio::SeqLogo::XML

    my $xml = Bio::SeqLogo::XML->new( file => 'file.xml' );

    for my $class ( $class->docset ) {
     # now $class is instance of Bio::SeqLogo::XML::Class.
     ...
    }

=head1 SeqLogo XML Format

=head2 DEFINITION

SeqLogo XML is simple file format for representation of sequence logo. Definition of elements are below.

=head3 class

Root element of SeqLogo XML, required.

=head4 Children

L</"loc"> required.

=head3 loc

=head4 Attribute

=over 4

=item pos Integer

A position number of the location, required.

=back

=head4 Children

L</"entropy"> required.
L</"symbol"> required.


=head3 entropy Float

Sum of each symbol's score at the position.
This element has no attribute and child.

=head3 symbol Float

# 一個の文字が持つスコアって書きたかったんだよ！
Represent score which is belong to one character.

=head4 Attribute

=over 4

=item type Character

The character. required.

=back

=head1 EXAMPLE

    <class>
    <loc pos='-6'>
    <entropy>0.975488750216348</entropy>
    <symbol type='A'>0.0975488750216348</symbol>
    <symbol type='D'>0.0975488750216348</symbol>
    <symbol type='E'>0.0975488750216348</symbol>
    <symbol type='G'>0.0975488750216348</symbol>
    <symbol type='L'>0.0487744375108174</symbol>
    <symbol type='M'>0.0487744375108174</symbol>
    <symbol type='N'>0.0487744375108174</symbol>
    <symbol type='P'>0.146323312532452</symbol>
    <symbol type='R'>0.146323312532452</symbol>
    <symbol type='S'>0.0487744375108174</symbol>
    <symbol type='T'>0.0975488750216348</symbol>
    </loc>
    ....
    </class>

=head1 Methods

=over 4

=item new

=item docset

=item parse_file

=back

=head1 AUTHOR

Hiroyuki Nakamura, C<< <hryk at cpan.org> >>

=cut
