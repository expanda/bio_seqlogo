package Bio::SeqLogo::DataSet;

use strict;
use warnings;
use Carp;

sub new {
	my $pkg = shift;
	my $base_str = shift || undef;
	my $this = {};

	if ($base_str) {
		push @{$this->{_docset}}, ( bless $base_str ,'Bio::SeqLogo::DataSet::Class' );
	}

	bless $this , $pkg;

	return $this;
}

sub docset {
    my $this = shift;
    return $this->{_docset};
}

package Bio::SeqLogo::DataSet::Class;
use strict;
use warnings;
use Carp;

sub iterate_position {
  my $this = shift;
  return ( sort {$a <=> $b} keys %{$this} );
;
}

sub entropy {
  my $this = shift;
  croak __PACKAGE__." [fatal]: No Argument. entropy require position number." if scalar(@_) == 0;
  my $pos = shift;
  return $this->{$pos}->{entropy};
}

sub symbols {
  my $this = shift;
  croak __PACKAGE__." [fatal]: No Argument. symbols require position number." if scalar(@_) == 0;
  my $pos = shift;
  return ( @{$this->{$pos}->{symbols}} );
}


1;
__END__



