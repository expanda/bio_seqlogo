package Bio::SeqLogo::XML::Handlers;
use strict;
use warnings;
sub say ($) { print STDERR "$_[0]";}

my $docset = [];
my $tempclass = {};
my $temploc = [];
my $temploc_pos = 0;
my $tempsym = {};

sub clean {
    $docset = [];
    $tempclass = {};
    $temploc = [];
    $temploc_pos = 0;
    $tempsym = {};
}

sub docset {
  return $docset;
}

sub StartDocument {
  my ( $e , $name ) = @_;
  return;
}

sub StartTag {
  my ( $e , $name ) = @_;

  if ($name eq 'class') {

  }
  elsif ( $name eq 'loc' ) {
    $temploc_pos = $_{pos};
  }
  elsif ( $name eq 'symbol' ) {
    $tempsym = { type => $_{type} };
  }
}

sub EndTag {
  my ( $e , $name ) = @_;
  if ($name eq 'class') {
    ### Hard Code (bless) ###
    push @{$docset}, bless( $tempclass, 'Bio::SeqLogo::XML::Class');
    $tempclass = ();
  }
  elsif ( $name eq 'loc' ) {
    $tempclass->{$temploc_pos}->{symbols} = $temploc;
    $temploc = ();
    $temploc_pos = 0;
  }
  elsif ( $name eq 'symbol' ) {
    push @{$temploc}, $tempsym;
  }

}

sub Text {
  my ( $e , $name ) = @_;
  if ($e->current_element() eq 'entropy') {
    $tempclass->{$temploc_pos}->{entropy} = $_;
  }
  elsif ($e->current_element() eq 'symbol') {
    $tempsym->{score} = $_;
  }
}

sub PI {
  my ( $e , $name ) = @_;
  return;
}

sub EndDocument {
  my ( $e , $name ) = @_;
  return;
}

sub DESTROY {
    undef $docset;
}

1;
