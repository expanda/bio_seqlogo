package Bio::SeqLogo::XML::Class;

use strict;
use warnings;
use Carp;
# No Constructor defined.

sub iterate_position {
  my $this = shift;
  return ( sort {$a <=> $b} keys %{$this} );
}

sub entropy {
  my $this = shift;
  croak "Bio::SeqLogo::XML::Class [fatal]: No Argument. entropy require position number." if scalar(@_) == 0;
  my $pos = shift;
  return $this->{$pos}->{entropy};
}

sub symbols {
  my $this = shift;
  croak "Bio::SeqLogo::XML::Class [fatal]: No Argument. symbols require position number." if scalar(@_) == 0;
  my $pos = shift;
  return ( @{$this->{$pos}->{symbols}} );
}

1;

__END__
