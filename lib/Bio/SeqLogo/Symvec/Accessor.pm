package Bio::SeqLogo::Symvec::Accessor;

use strict;
use warnings;
use Carp;

sub new {
  my $pkg = shift;
  my $class = shift;

  return bless $class, $pkg;
}

sub iterate_position {
  my $this = shift;
  return ( sort {$a <=> $b} keys %{$this} );
}

sub entropy {
  my $this = shift;
  croak "Bio::SeqLogo::Symvec::Accessor [fatal]: No Argument. entropy require position number." if scalar(@_) == 0;
  my $pos = shift;
  return $this->{$pos}->{entropy};
}

sub symbols {
  my $this = shift;
  croak "Bio::SeqLogo::Symvec::Accessor [fatal]: No Argument. symbols require position number." if scalar(@_) == 0;
  my $pos = shift;
  return ( @{$this->{$pos}->{symbols}} );
}

1;
