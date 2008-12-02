package Bio::SeqLogo::Color;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use utf8;

my $internal_data = [];

=head1 NAME

Bio::SeqLogo::Color - Parser for sequence logo color file.

=head1 SYNOPSIS

    use Bio::SeqLogo::Color;
    
    $color = Bio::SeqLogo::Color('default');
    
    $color->as_ps_def();

=head1 Color File

Color file is color schema for sequence logo. You can write character and rgb score separated by tab.

=head2 Example

    # AA	R	G	B
    G	0	112	49
    S	83	186	222
    T	83	186	222
    Y	112	60	121
    C	243	153	44
    N	161	49	87
    Q	161	49	87
    K	184	42	50
    R	184	42	50
    H	184	42	50
    D	0	82	129
    E	0	82	129
    P	0	112	49
    A	243	153	44
    W	112	60	121
    F	112	60	121
    L	19	20	19
    I	19	20	19
    M	19	20	19
    V	19	20	19

This is default color schema of Bio::SeqLogo::Color.

=cut

=head1 METHODS

=over 4

=item new

=cut

sub new {
    my $pkg = shift;
    my $color_from = shift;

    my $this = bless {
        prefix => 'color_',
    }, $pkg;

    if ( $color_from eq 'default' ) {
        $this->default_color;
    }
    elsif ( -e $color_from  ) {
        $this->load_color($color_from);
    }
    else {
        carp 'no argument. use default setting';
        $this->default_color;
    }

    return $this;
}

{
    my $default_data = undef;

    sub _load_def {
        unless ($default_data) {
            while (<DATA>) {
                chomp;
                push @{$default_data}, $_;
            }
        }

        return $default_data;
    }
}

=item default_color

=cut

sub default_color {
    my $this = shift;
    for (@{_load_def()}) {
        $this->read_color_line($_);
    }

    return $this;
}

=item load_color

=cut

sub load_color {
    my $this = shift;
    my $file = shift;
    open my $fh, "$file";

    $this->load_color_from_fh($fh);
}

=item load_color_from_fh

=cut

sub load_color_from_fh {
    my $this = shift;
    my $handle = shift;

    while (<$handle>) {
        $this->read_color_line($_);
    }
    return $this;
}

=item read_color_line

=cut

sub read_color_line {
    my $this = shift;
    my $line = shift;

    if ( $line ) {
        if ( $line =~ /^([A-Z])\t(\d+?)\t(\d+?)\t(\d+)$/ ) {
            $this->{color}->{$1}->{r} = $2 / 255;
            $this->{color}->{$1}->{g} = $3 / 255;
            $this->{color}->{$1}->{b} = $4 / 255;
            #print qq{/color_$1 [ }.( $2 / 255 )." ". ($3 / 255 )." ".( $4 / 255 )." ] def\n";
        }
        elsif ( $line =~ /^([A-Z])\t\#([a-zA-Z0-9]{2})([a-zA-Z0-9]{2})([a-zA-Z0-9]{2})$/) {
            $this->{color}->{$1}->{r} = hex($2) / 255;
            $this->{color}->{$1}->{g} = hex($3) / 255;
            $this->{color}->{$1}->{b} = hex($4) / 255;
        }
        elsif( $line !~ /^\#/ ){
            carp q{Wrong line in color definition file.
            Format:
            ^([A-Z])\t\#([a-zA-Z0-9]{2})([a-zA-Z0-9]{2})([a-zA-Z0-9]{2})$/   OR
        /^([A-Z])\t(\d+?)\t(\d+?)\t(\d+)$/
    };
}
  }
  else {
      return 0;
  }

  return $this;
}

=item as_ps_def

=back

=cut

sub as_ps_def {
    my $this = shift;
    my $ps_def = '';
    my $ps_dict = '';
    return $this->{ps_def} if $this->{ps_def};

    $ps_dict = "/colorDict << \n";
    while ( my ( $char , $colorstr) = each %{$this->{color}}) {
        $ps_def .= qq{/}.$this->{prefix}.$char."[ ".
        $colorstr->{r}. ' ' .
        $colorstr->{g}. ' ' .
        $colorstr->{b}. ' ] def'."\n";
        $ps_dict .= ' ('.$char.') '.$this->{prefix}.$char."\n";
    }
    $ps_dict .= ">> def\n";
    $this->{ps_def} = $ps_def;
    $this->{ps_def} .= "% Color_dict \n";
    $this->{ps_def} .= $ps_dict;

    return  $this->{ps_def};
}

sub DESTROY {
    my $this = shift;
    undef($this);
}

1;

=head1 AUTHOR

Hiroyuki Nakamura <t04632hn@sfc.keio.ac.jp>

=cut



__DATA__
# AA	R	G	B
G	0	112	49
S	83	186	222
T	83	186	222
Y	112	60	121
C	243	153	44
N	161	49	87
Q	161	49	87
K	184	42	50
R	184	42	50
H	184	42	50
D	0	82	129
E	0	82	129
P	0	112	49
A	243	153	44
W	112	60	121
F	112	60	121
L	19	20	19
I	19	20	19
M	19	20	19
V	19	20	19
