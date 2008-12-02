package Bio::SeqLogo;

use vars qw{$VERSION $DEBUG};
$VERSION = '0.0.3';
$DEBUG = 0;

use warnings;
use strict;
use UNIVERSAL::require;
use Carp;
use File::Spec;
use Data::Dumper;
sub say ($) { print STDERR "SeqLogo.pm : $_[0]\n" if $DEBUG ; }

sub new {
    my $class = shift;
    my $args = {
        color => 'Bio::SeqLogo::Color',
        template => 'Bio::SeqLogo::Template',
        parser => {
            xml => 'Bio::SeqLogo::XML',
            symvec => 'Bio::SeqLogo::Symvec'
        },
        @_
    };

    my $this = bless { klass => $args }, $class;

    $DEBUG = 1 if $args->{debug};
    return $this;
}

sub createlogo {
    my $this = shift;
    my $opt = {
        "input"    => '',
        "output"   => 'logo.eps',
        "template" => 'default',
        "template_dir" => '../tmpl/',
        "maxsize"  => 'auto',
        "maxscore" => 'auto',
        "color"    => 'default',
        "graph"    => 'none' ,       #'line:dasshed:2px',
        "frequency" => 0 ,    
        "debug"    => 0,
        "config"  => '',
        @_
    };

    $this->{_option} = $opt;

    $this->check_options;

    # Parse

    my $source;

    if ( $this->opt("input") =~ m/\.(\w+?)$/ ) {
        $this->activate("parser.${1}");
        $source = $this->klass("parser.${1}")->new( file => $this->opt("input") );
    }
    else {
        my $msg = qq{[Fatal] Input file loading failed! Supported file format are };
        $msg .= ' $_ ,' for keys %{ $this->klass('parser') };
        say $msg;
    }

    say "Input : ".$this->opt("input");

    # Load template

    my $logo_tmpl;
    $this->activate('template');
    if ($this->opt("config") && -e $this->opt("config")) {
        say "Load config from YAML...";
        $logo_tmpl = $this->klass('template')->new('setting_file' => $this->opt("config"));
    }
    else {
        say "No Config file...";

        $logo_tmpl = $this->klass('template')->new(
            'template_dir' => $this->opt("template_dir"),
            'template'     => $this->opt("template"),
            'debug'        => $this->opt("debug"),
            'output'       => $this->opt("output"),
        );
    }

    # Color 

    $this->activate('color');
    my $color = $this->klass('color')->new($this->opt("color"));
    $logo_tmpl->color_allocation($color);

    say "Process Start";

    my @outfnames;

    for my $doc (@{ $source->docset() }) {

        $logo_tmpl->process(
            source    => $doc, 
            maxsize   => $this->opt("maxsize"),
            maxscore  => $this->opt("maxscore"),
            graph     => $this->opt("graph"),
            frequency => $this->opt("frequency"),
        );

        if ( $logo_tmpl->is_ok ) {
            my $fname = _output_filename($opt->{output});
            push @outfnames, $fname;
            $logo_tmpl->output($fname);
        } else {
            say $logo_tmpl->error;
        }

    }

    say "End.";
    say "Generate $_" for @outfnames;

    # clean up
    undef $this->{_option};
    undef $logo_tmpl;
    undef $color;
    undef $source;
    undef @outfnames;
}

{
    my $num = 1;

    sub _output_filename {
        my $name = shift;
        $num++;
        if ($name =~ /^(.+?)(\.[a-z]{1,3})$/) {
            return $1."_$num".$2;
        }
    }
}

sub check_options {
    my $this = shift;

    my $fpath = File::Spec->rel2abs( $this->opt("input") ); 
    croak qq{ [fatal] : $fpath No such file or directory. } unless -e $fpath;

    $this->opt("input", $fpath);

    return 1;
}

{ 
    my $cache;

    sub activate {
        my $this =shift;
        my $arg = shift || croak "no arg.";

        return 1 if $cache->{$arg};
        $cache->{$arg} = 1;

        if ($arg =~ /^[a-z]+$/i) {
            $this->{klass}->{$arg}->require;
        }
        elsif ($arg =~ /\./) {
            my @klass = split(/\./, $arg);
            $this->{klass}->{$klass[0]}->{$klass[1]}->require;
        }
    }

}

 # Accessors.
sub klass {
    my $this = shift;

    if ( scalar @_ == 2 ) {
        $this->{klass}->{$_[0]} = $_[1];
        return $this->{klass}->{$_[0]};
    }
    elsif ( scalar @_ == 1 ) {
        my $arg = shift;

        if ($arg =~ /^[a-z]+$/i) {
            return $this->{klass}->{$arg};
        }
        elsif ($arg =~ /\./) {
            my @klass = split(/\./, $arg);
            say qq{$klass[0] $klass[1]};
            return  $this->{klass}->{$klass[0]}->{$klass[1]};
        }
    }
}

sub opt {
    my $this = shift;

    if ( scalar @_ == 2 ) {
        $this->{_option}->{$_[0]} = $_[1];
        return $this->{_option}->{$_[0]};
    }
    elsif ( scalar @_ == 1 ) {
        return $this->{_option}->{(shift)};
    }
    else {
        return $this->{_option};
    }
}

1; # End of Bio::SeqLogo

__END__

=head1 NAME

Bio::SeqLogo - Yet another sequence logo generator.

=head1 VERSION

Version 0.02

=head1 SYNOPSIS

    use Bio::SeqLogo;

    my $generator = Bio::SeqLogo->new();

    $generator->createlogo('logo.symvec',
                           template_value => {
                                'title'        => 'logo',
                                'ylabelleft'   => 'bits'
                           },
                           graph => 'none',
                           color => 'color_file.txt',
                           output => 'logo.eps',
                          );

=head1 DESCRIPTION

Sequence logo is a grahical representaion of the sequence conservation of nucleotidees or amino acids (L<http://en.wikipedia.org/wiki/Sequence_logo>). This module was made as alternative of makelogo.p / makelogo.c, that is first program developed by Dr. Thomas D. Schneider. L<Bio::SeqLogo> is same input format that named 'symvec' as makelogo. L<Bio::SeqLogo> and L<seqlogo> is template-based logo generator, so its enable you to configure look as you like. More information of template, written in L<Bio::SeqLogo::Template>.

head1 METHODS

=head2 new

This is a constructor. Options are passed as keyword value pairs except for input. 

=head3 Input 

Input format is symvec or seq-logo xml.
Definition of file format are in L<Bio::SeqLogo::Symvec> and L<Bio::SeqLogo::XML>.

=over 4

=item color 

Color definition file path or L<Bio::SeqLogo::Color> Object. Definition of color file is written in L<Bio::SeqLogo::Color>.

=item graph String

'solid' or 'curve' or 'none' (default is 'none')

Your configuration file path. Configration File format is L<YAML>

=item template_value HashRef

L<Bio::SeqLogo::Template> construct options.

=item output FilePath

Output format is EPS.

=back

=head1 AUTHOR

Hiroyuki Nakamura, C<< <hryk at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-bio-seqlogo at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Bio-SeqLogo>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Bio::SeqLogo

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Bio-SeqLogo>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Bio-SeqLogo>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Bio-SeqLogo>

=item * Search CPAN

L<http://search.cpan.org/dist/Bio-SeqLogo>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Hiroyuki Nakamura, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

