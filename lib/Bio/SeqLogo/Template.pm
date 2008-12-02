package Bio::SeqLogo::Template;
use vars qw{$DEBUG};
use strict;
use warnings;
use Template;
use File::Spec;
use Data::Dumper;
use YAML;
use Carp;

use base qw{Exporter};
our @EXPORT = qw(generate_template);

use Bio::SeqLogo::XML::Class;
use Bio::SeqLogo::Color;
sub say ($) { print STDERR "$_[0]\n";}

=head1 NAME

Bio::SeqLogo::Template - Create SequenceLogo PostScript file

=head1 SYNOPSIS

    use Bio::SeqLogo::Template;

    my $logo = Bio::SeqLogo::Template->new(setting_file => './setting.yml');

    # process logo with data.
    $logo->process( source => $source ); # <- source is Bio::SeqLogo::XML::Class or Bio::SeqLogo::Symvec

    # ...or process with file (TODO)
    $logo->process( source => './data.txt' );

    if ( $logo->is_ok ) {
       # output sequence logo as PostScript.
       $logo->output('seqlogo.ps');
    }

    # In command-line
    % perl -MBio::SeqLogo::Template -e "generate_template()"
    # print built-in template to STDOUT

=head1 METHODS

=over 4

=item setter/getter

template variable setter or getter.

method name is tmplvars_(variable name).
avairable template variable is in DESCRIPTION.

=cut

# Auto Setter/Getter.
sub AUTOLOAD {
    my $this = shift;
    my $name = our $AUTOLOAD;
    my $strpoint;
    $name =~ s/.*:://;
    if ( $name =~ m/^tmplvars_(.+?)$/ ) {
        if ( scalar(@_) > 0 && defined($this->{vars}->{$1}) ) {
            $this->{vars}->{$1} = shift @_;
            return $this->{vars}->{$1};
        }
        elsif( scalar(@_) == 0 && defined($this->{vars}->{$1}) ) {
            return $this->{vars}->{$1};
        }
        else {
            carp "Template Variable '$1' is not defined.";
            return undef;
        }
    }
    else {
        carp "Bio::SeqLogo::Template [fatal]: method not found $name";
        return undef;
    }
}

=item new

This function is constructor.

=cut

# Constructor.
sub new {
    my $pkg = shift;
    my $args = {
        'setting_file' => '',
        'template_dir' => '',
        'template' => '',
        'debug' => 0,
        'output' => 'a.ps',
        @_
    };

    my $config = {
        INCLUDE_PATH => $args->{template_dir}, # or list ref
        INTERPOLATE  => 1, # expand "$var" in plain text
        POST_CHOMP   => 1, # cleanup whitespace 
        EVAL_PERL    => 1, # evaluate Perl code blocks
        RELATIVE     => 1, # evaluate Perl code blocks
        OUTPUT_PATH  => '.' ,
    };

    my $this =  bless {
        'config' => $config,
        'output_file' => $args->{output},
        'template_file' => $args->{template},
        'color_obj' => '',
        'color' => '',
        'display_max' => 100,
        '_graph_heights_data' => [],
        '_graph_heights' => {},
        'vars' => {
            'title'        => '',
            'ylabelleft'   => 'bits',
            'ylabelright'  => 'bits',
            'yaxis'   => 'true',
            'yaxisright'   => 'false',
            'yaxislabel'   => 1,
            'yaxislabelright'   => 0,
            'ymax'         => 1,
            'ymaxright'    => 100,
            'ymaxleft'    => 100,
            'ticbits'      => '',
            'ticbitsright' => '',
            'canvasstroke' => 'false',
            'showpmark'    => 'false', # Show PMark true/false
            'pmarkheight'  => 25,
            'titlefont'    => 'GaramondPremrPro',
            'logofont'     => 'Helvetica-Bold', #'MyriadPro-Bold',
            'numberfont'   => 'Helvetica',
            'stringfont'   => 'Helvetica',
            'endfont'      => 'Helvetica-Bold',
            'outline'      => 'false',
            'graphtype'    => 'solid',
            'charwidth'    => '',
            'bezier'       => {},
            'atcoord'      => [],
            'charsperline' => 0,
            'logowidth'    => 15,
            'rightmargin'  => 20,
            'stack_margin' => 1,
            'colordef'     => '',
        },
        '_is_ok' => 0,
        '_frequency' => 0,
        '_debug' => $args->{debug},
    }, $pkg;

    $this->load_config_as_yaml($args->{setting_file}) if -e $args->{setting_file};

    return $this;
}

=item color_allocation

 Color allocate function.

=cut

sub color_allocation {
    my $this = shift;
    my $color_obj = shift;

    $this->message('debug', 'subroutine color_allocation start');
    carp "argument have to be Bio::SeqLogo::Color Object." and
    return 0 if ref $color_obj !~ /Bio::SeqLogo::Color/;

    $this->{color_obj} = $color_obj;
    $this->{color} = $color_obj->as_ps_def;

    $this->tmplvars_colordef($this->{color});

    return $this;
}

=item process

 Pre-Processing template.

=cut

sub process {
    my $this = shift;
    my $args = {
        source  => '',
        maxsize => 100,
        maxscore => 100,
        graph => 'curve',
        frequency => 0,
        @_,
    };

    croak "Bio::SeqLogo::Template [fatal]: Empty source." if !$args->{source};

    if ( $args->{graph} eq 'curve' ||
        $args->{graph} eq 'solid' ||
        $args->{graph} eq 'none'
    ) {
        $this->tmplvars_graphtype($args->{graph});
    }

    $this->{_frequency} = $args->{frequency};

    if ( defined($args->{source}) &&
        ( ref ( my $c =  $args->{source} ) =~ m/Bio::SeqLogo::XML::Class|Bio::SeqLogo::Symvec::Accessor/ ) ) {
        # Bio::SeqLogo::XML
        $this->message('debug', 'process logoxml or symvec');
        return $this->process_logo(%{$args});
    }
    else {
        croak "Bio::SeqLogo::Template [fatal]: Empty source.";
    }
}

=item process_logoxml

 Pre-Processing template.

=cut

sub process_logo {
    my $this = shift;
    $this->message('debug', 'Start function process_logo');
    my $args = {
        source  => '',
        maxsize => 100,
        maxscore => 100,
        @_,
    };
    my $class = $args->{source};
    my ( @at_coord , @bezier_heights );
    my $maxsize = 0;

    for my $pos ( $class->iterate_position ) {
        my $sum;
        my @data;
        $maxsize = ( $class->entropy($pos) > $maxsize )
        ? $class->entropy($pos) : $maxsize if defined( $class->entropy($pos) );

        for my $symbol ( $class->symbols($pos) ) {
            carp qq{Void number in $$symbol{type}} unless defined($symbol->{score});
        $this->message( 'debug', qq{$$symbol{score} / $$args{source}{$pos}{entropy}} );
    push @data, {
        char => $symbol->{type},
        num  => ($args->{source}->{$pos}->{entropy} == 0 ) ? 0
        : $symbol->{score} / $args->{source}->{$pos}->{entropy},
    };

    $sum += $symbol->{score};
}

@data = sort { $b->{num} <=> $a->{num} } @data;

push @at_coord , {
    coordinate => $pos,
    data       => \@data,
    entoropy   => $sum,
};
$sum = 0;
  }

  $this->tmplvars_atcoord(\@at_coord);
  $this->tmplvars_charsperline(scalar(@at_coord));

  {
      @_ = ($this, $maxsize);
      goto &size_adjustment;
  }
}

=item size_adjustment

=cut

sub size_adjustment {
    croak "Bio::SeqLogo::Template [fatal]: Invalid argument for 'size_adjustment'." if scalar(@_) == 0;
    my ( $this , $maxsize ) = @_;
    my $maxent = 0;

    $this->message('debug', 'Start function size_adjustment');

    for my $d ( @{ $this->tmplvars_atcoord } ) {

        $maxent = ( $maxent < $d->{entoropy} ) ? $d->{entoropy} : $maxent;

#        if ($this->tmplvars_graphtype() eq "none") {
        unless ($this->{_frequency}) {
            $this->message('debug', 'Frequency Mode.');
            $_->{num} *= ( $d->{entoropy} * $this->{display_max} / $maxsize ) for @{$d->{data}};
        }
        else {
            $this->message('debug', 'Not Frequency Mode.');
            $_->{num} *= ( $this->{display_max} ) for @{$d->{data}};
        }

        my $dentoropy;
        $dentoropy = $d->{entoropy} * $this->{display_max} / $maxsize;
        push  @{ $this->{_graph_heights_data} },
        { entoropy =>  $dentoropy ,
            bitsnum => scalar(@{$d->{data}}) };
    }

    $this->message('info', "ymax is $maxent");
    $this->tmplvars_ymax( $this->{display_max} );

#    if ( $this->tmplvars_graphtype() eq "none" ) {
    unless ($this->{_frequency}) {
        $this->message('debug', 'Frequency Mode.');
        $this->tmplvars_ymaxleft( sprintf('%1.2f', $maxent) );
    }
    else {
        $this->message('debug', 'Not Frequency Mode.');
        $this->tmplvars_ymaxright( sprintf('%1.2f', $maxent) );
        $this->tmplvars_yaxisright( "true" );
    }

    $this->message('debug', 'Fail to define ymax') if $@;

    $this->tmplvars_charwidth($this->calc_charwidth());
    $this->message('debug',$this->tmplvars_graphtype() );

    $this->calc_graph_heights() if $this->tmplvars_graphtype() =~ m'curve|solid';

    {
        @_ = ($this);
        goto &check_tmplvars;
    }

}

=item calc_charwidth

Internal function.

=cut

sub calc_charwidth {
    my $this = shift;
    my $logowidth = $this->tmplvars_logowidth * 72 / 2.54;
    my $fontsize = 12 * $this->tmplvars_logowidth / 15;
    my $leftmargin = $fontsize * 3.5;

    return ( ( $logowidth - $leftmargin - $this->tmplvars_rightmargin )
        / $this->tmplvars_charsperline - $this->tmplvars_stack_margin );
}

=item calc_graph_heights

Internal function.

=cut

sub calc_graph_heights {
    my $this = shift;
    my $points = $this->{_graph_heights_data};
    my $coords;
    my $charwidth = $this->tmplvars_charwidth;

    push @{$coords}, {
        x1 => $charwidth / 2 + 1,
        y1 => 0,
        x2 => 0,
        y2 => $$points[0]->{entoropy},
        x3 => $charwidth / 2,
        y3 => $$points[0]->{entoropy},
    };

    my $stack_margin = $charwidth;
    my $num = 0;
    for my $point_y (@{$points}) {
        $num++;
        if ( $$points[$num] ) {
            push @{$coords}, {
                x1 => $stack_margin,
                y1 => $point_y->{entoropy},
                x2 => $stack_margin,
                y2 => $$points[$num]->{entoropy} || 0,
                x3 => $charwidth / 2 + $stack_margin + 1,
                y3 => $$points[$num]->{entoropy} || 0,
                bitsnum => $$points[$num]->{bitsnum},
            };
        }
        $stack_margin += $charwidth;
    }

    $this->tmplvars_bezier({
            'starts' => shift( @{$coords} ),
            'points' => $coords,
        });
    return $this;
}

=item check_tmplvars

Internal function.
This function check 'template variables' are valid.

=cut

sub check_tmplvars {
    croak "Bio::SeqLogo::Template [fatal]: Invalid argument for 'check_tmplvars'." if scalar(@_) == 0;
    my $this = shift;
    $this->message('debug', 'Start function check_tmplvars');

    while ( my ($directive , $val ) = each %{$this->{vars}}) {
        print STDERR "$directive ... ";
        if ( $val ) {
            if ( ref $val eq 'HASH' || ref $val eq 'ARRAY' ) {
                say 'ok ('.(ref $val).')';
            }
            elsif ( !(ref $val) && length $val < 20 ) {
                say "ok ($val)";
            }
            else {
                say "ok";
            }
        }
        else {
            say '? (empty)';
        }
    }

    return $this;
}

=item load_config_as_yaml

Internal.

=cut

# YAML Loader
sub load_config_as_yaml {
    my $this = shift;
    my $filename = shift;
    $this->message('debug', 'start subroutine load_config_as_yaml');
    $this->message('debug', "filename is $filename");

    carp "Bio::SeqLogo::Template [warn] : load_config_as_yaml , file path is empty"
        and return undef unless $filename;

    my $conf;
    $conf = LoadFile($filename);
    $this->message('debug', "file open error") and return undef if !$conf;

    $this->message('debug', "readfile");

    print Dump $conf;

    for ( 'config', 'output_file', 'template_file', 'color', 'vars' ) {
        if (/^vars$/) {
            for my $directive ( keys %{$conf->{vars}} ) {
                $this->{vars}->{$directive} = $conf->{vars}->{$directive};
            }
        }
        else {
            $this->{$_} = $conf->{$_};
        }

    }

    return $this;
}

=item dump_config_as_yaml

Dump template setting as yaml file.

=cut

# YAML Dumper
sub dump_config_as_yaml {
    my $this = shift;
    my $filename = 'logo_tmpl_config.yml';
    my $d;
    map {
        if ( $_ =~ m/^config|output_file|template_file|color|vars$/sx ) {
            $d->{$_} = $this->{$_};
        }
        $d;
    } keys %{$this};

    carp "no data dumped" unless $d;

    DumpFile( $filename, $d );
    return 1;
}

=item is_ok

TODO: Check Template Settings.

=cut

# Check Template Settings.
sub is_ok {
    my $this = shift;
    # TODO:
    return 1;
}

=item error

Return Error message if $this->{error} is not empty.

=cut

sub error {
    my $this = shift;

}

=item _load_def

Default template load function.

=cut

{
    my $default_data = undef;

    sub _load_def {
        unless ($default_data) {
            while (<DATA>) {
                $default_data .= $_;
            }
        }
        return $default_data;
    }
}

=item output

Output Sequence Logo to file.

=cut

sub output {
    my $this = shift;
    my $outpath = shift;

    if ( $this->{template_file} eq 'default' ) {
        $this->{template_file} = \_load_def();
    }

    my ( $volume, $directories, $file ) = File::Spec->splitpath( File::Spec->rel2abs($outpath) );

    $this->{config}->{OUTPUT_PATH} = $directories;

    my $tmpl = Template->new($this->{config});

    $tmpl->process( $this->{template_file}, $this->{vars}, $file )
    || croak $tmpl->error();
}

# Message for debug and error
#  $this->message('level', 'message text');
sub message {
    my $this = shift;
    my $level = shift;
    my $msg  = shift;
    my ($package, $file, $line, $subname) = @{ [ ( caller(1) ) ] }[0..3];


    if ( $level eq 'warn' ) {
        carp "$package : $subname : [warn] :$msg";
    }
    elsif($level eq 'fatal') {
        croak "$package : $subname : [fatal] :$msg";
    }
    elsif ($level eq 'debug') {
        print STDERR "$package : $subname : [debug] :$msg\n" if $DEBUG;
    }
    else {
        print STDERR "$package : $subname : [info] :$msg\n";
    }
}



=item generate_template



=cut

sub generate_template {
    print _load_def();
}

sub DESTROY {}

=back

=head1 DESCRIPTION

=head2 Template Variables

=over 4

=item title

string

=item leftylabel

string

=item rightylabel

string

=item yaxislabel

bool (1 or 0)

=item ymax

integer

=item ymaxright

integer

=item ticbits

integer

=item ticbitsright

integer

=item canvasstroke

bool (true or false)

=item parkheight

integer

=item titlefont

string

=item logofont

string

=item numberfont

string

=item stringfont

string

=item endfont

string

=item outline

bool (true or false)

=item logowidth

integer

=back

=head1 AUTHOR

Hiroyuki Nakamura <t04632hn@sfc.keio.ac.jp>

=cut

1;

# Built-In Template

__DATA__
%!PS-Adobe-3.0 EPSF-3.0
%%Title: [% title %]

%%Creator: 
%%CreationDate: 
%%BoundingBox:   0  0  [% logowidth * ( 72 / 2.54 ) + 20 %] [% ( logowidth * 72 / 2.54 ) / 1.618 / 2 + pmarkheight %]
%%Pages: 0
%%DocumentFonts: 
%%EndComments

% ---- CONSTANTS ----
/cmfactor 72 2.54 div def % defines points -> cm conversion
/cm {cmfactor mul} bind def % defines centimeters

% ---- VARIABLES ----

true setoverprint

% ---- Color Allocation ----
/black [0 0 0] def

[% colordef %]

% ---- axis ----

/logoWidth [% logowidth %] cm def
/logoHeight [% logowidth / 1.618 / 2 %] cm [% pmarkheight %] add def
/CanvasHeight [% logowidth / 1.618 / 2 %] cm [% pmarkheight %] add def
/logoTitle ([% title %]) def
/pMarkHeight [% pmarkheight %] def

/yaxis [% yaxis %] def
/yaxisright [% yaxisright %] def
/yaxisLabel ([% ylabelleft %]) def
/yaxisLabelRight ([% ylabelright %]) def

/yaxisBits [% ymax %] def % percentage to bits
/yaxisTicBits [% IF ticbits %][% ticbits %][% ELSE %][% ymax / 2 %][% END %] def
/yaxisBitsRight [% ymaxright %] def % percentage to bits
/yaxisTicBitsRight [% IF ticbitsright %][% ticbitsright %][% ELSE %][% ymaxright / 2 %][% END %] def

/xaxis true def
/xaxisLabel ([% xlabel %]) def
/showEnds (p) def % d: DNA, p: PROTEIN, -: none

/showFineprint false def
/fineprint (weblogo.berkeley.edu) def

/charsPerLine [% charsperline %] def
/logoLines 1 def

/showingBox (n) def    %n s f
/shrinking false def
/shrink  0.5 def
/outline [% outline %] def

/IbeamFraction  1 def
/IbeamGray      0.50 def
/IbeamLineWidth 0.5 def

/fontsize       [% 12 * logowidth / 15 %] def
/titleFontsize  [% 14 * logowidth / 15 %] def
/smallFontsize  [% 10 * logowidth / 15 %] def

/defaultColor black def 

% ---- DERIVED PARAMETERS ----

[% SET yticsleft = ymaxleft / 2 %]
[% SET yleftlongernum = ymaxleft %]
[% IF  ymaxleft.length < yticsleft.length %]
[% yleftlongernum = yticsleft %]
[%  END %]
 
/leftMargin
  smallFontsize [% yleftlongernum.length %] mul
def

/bottomMargin
  fontsize 0.75 mul

  % Add extra room for axis
  xaxis {fontsize 1.75 mul add } if
  xaxisLabel () eq {} {fontsize 0.75 mul add} ifelse
def

/topMargin 
  logoTitle () eq { pMarkHeight () eq { 10 }{ pMarkHeight 10 add } ifelse }{titleFontsize 4 add} ifelse
def

/rightMargin 
  %Add extra room if showing ends
  % bool  proc1  proc2 ifelse proc1 if bool is true, proc2 if false
  showEnds (-) eq { fontsize 1.5 mul }{fontsize 2.5 mul} ifelse
def

/yaxisHeight
  logoHeight
  bottomMargin sub
  topMargin sub
def

%/ticWidth fontsize 2 div def

/pointsPerBit yaxisHeight yaxisBits div def
/pointsPerBitRight yaxisHeight yaxisBitsRight div def

/isBoxed 
  showingBox (s) eq
  showingBox (f) eq or { 
    true
  } {
    false
  } ifelse
def

/stackMargin [% stack_margin %] def

% Do not add space aroung characters if characters are boxed
/charRightMargin 
  isBoxed { 0.0 } {stackMargin} ifelse
def

/charTopMargin 
  isBoxed { 0.0 } {stackMargin} ifelse
def

/charWidth
  logoWidth
  leftMargin sub
  rightMargin sub
  charsPerLine div
  charRightMargin sub
def

/charWidth4 charWidth 4 div def
/charWidth2 charWidth 2 div def

/stackWidth 
  charWidth charRightMargin add
def
 
/numberFontsize
  fontsize charWidth lt {fontsize}{charWidth} ifelse
def

/ticWidth numberFontsize 2 div def

% movements to place 5'/N and 3'/C symbols
/leftEndDeltaX  fontsize neg 2 mul         def
/leftEndDeltaY  fontsize 2 mul neg   def
/rightEndDeltaX fontsize 0.25 mul 3 mul    def
/rightEndDeltaY leftEndDeltaY      def

% Outline width is proporional to charWidth, 
% but no less that 1 point
/outlinewidth
  charWidth 32 div dup 1 gt  {}{pop 1} ifelse
def

% write Pmark. point 0.
% 
% ---- PROCEDURES ----

/ShowPmark {
  gsave
  /Pstr (P) def
  /Pstrwidth fontsize 2 div def
  /arcr pMarkHeight 1.618 div 2 div def
  /arcx logoWidth 2 div arcr add arcr 4 div sub def
  /arcy CanvasHeight arcr 1.5 mul sub def
  2 setlinejoin
  % Write stem %
  newpath
  3 setlinewidth
  arcx arcr 4 1.5 mul div sub arcy moveto
  arcx arcr 4 1.5 mul div add arcy lineto
  arcx arcr 4 1.5 mul div add arcy pMarkHeight arcr sub sub lineto
  arcx arcr 4 1.5 mul div sub arcy pMarkHeight arcr sub sub lineto
  arcx arcr 4 1.5 mul div sub arcy lineto
  closepath
  0 setgray
  fill
  stroke
  newpath
  arcx arcy arcr 0 360 arc
  closepath
  gsave
  0.952941176470588 0.941176470588235 0 setrgbcolor
  fill
  grestore
  gsave
  0.952941176470588 0.941176470588235 0 setrgbcolor
  1 setlinewidth
  stroke
  grestore

  SetSmallFont
  Pstrwidth 2 div neg arcx add
  Pstrwidth 1.6 div neg arcy add
  moveto
   % /[% IF logofont %][% logofont %][% ELSE %]Helvetica-Bold[% END %] findfont smallFontsize scalefont setfont
   Pstr show
  grestore
} bind def

/ShowCropArea {
    /margin 2.5 def
    gsave
    newpath
    0 margin add
    0 margin add  moveto
    0 margin add
    logoHeight margin sub lineto
    logoWidth margin sub
    logoHeight margin sub lineto
    logoWidth margin sub
    0 margin add lineto
    closepath
    0 setgray
    1 setlinewidth
    stroke
    grestore
} bind def



/StartLogo { 
  % Save state
  save 
  gsave 

  % Print Logo Title, top center 
  gsave 
    SetTitleFont

    logoWidth 2 div
    logoTitle
    stringwidth pop 2 div sub
    logoHeight logoLines mul  
    titleFontsize sub
    moveto

    logoTitle
    show
  grestore
  [% IF croparea %] ShowCropArea [% END %]
  [% IF graphtype.match('true') %]  ShowPmark [% END %]
  
  % Print X-axis label, bottom center
  gsave
    SetStringFont

    logoWidth 2 div
    xaxisLabel stringwidth pop 2 div sub
    fontsize 3 div
    moveto

    xaxisLabel
    show
  grestore

  % Show Fine Print
  showFineprint {
    gsave
      SetSmallFont
      logoWidth
        fineprint stringwidth pop sub
        smallFontsize sub
          smallFontsize 3 div
      moveto
    
      fineprint show
    grestore
  } if

  % Move to lower left corner of last line, first stack
  leftMargin bottomMargin translate

  % Move above first line ready for StartLine 
  0 logoLines logoHeight mul translate

  SetLogoFont
} bind def

/EndLogo { 
  grestore 
  showpage 
  restore 
} bind def


/StartLine{ 
  % move down to the bottom of the line:
  0 logoHeight neg translate
  
  gsave
    yaxis { MakeYaxis } if
    xaxis { ShowLeftEnd } if
} bind def

/EndLine{ 
    xaxis { ShowRightEnd } if
  grestore 
} bind def


/MakeYaxis {
  gsave    
    stackMargin neg 0 translate
    ShowYaxisBar
    ShowYaxisLabel
    % xaxisLabel () eq {} {fontsize 0.75 mul add} ifelse
  grestore
} bind def


/ShowYaxisBar {
  gsave
  %SetStringFont
  SetNumberFont
   /str [% yleftlongernum.length %] string def % string to hold number
    /smallgap stackMargin 2 div def

    % Draw first tic and bar
    gsave
      ticWidth neg 0 moveto
      ticWidth 0 rlineto
      0 yaxisHeight rlineto
      stroke
    grestore

    % Draw the tics
    % initial increment limit proc for
    % 0 yaxisTicBits yaxisBits abs      %cvi
    0 [% ymaxleft / 2 %] [% ymaxleft %] abs      %cvi
    {/loopnumber exch def

      % convert the number coming from the loop to a string
      % and find its width

      loopnumber 10 str cvrs
      % loopnumber str cvs
      /stringnumber exch def % string representing the number

      stringnumber stringwidth pop
      /numberwidth exch def % width of number to show

      /halfnumberheight
         stringnumber CharBoxHeight 2 div
      def

      numberwidth                     % move back width of number
      neg loopnumber pointsPerBit mul [%  ymax / ymaxleft  %] mul % shift on y axis
      halfnumberheight sub            % down half the digit

      moveto                          % move back the width of the string

      ticWidth neg smallgap sub       % Move back a bit more
      0 rmoveto                       % move back the width of the tic  

      stringnumber show
      smallgap 0 rmoveto              % Make a small gap  

      % now show the tic mark
      0 halfnumberheight rmoveto      % shift up again
      ticWidth 0 rlineto
      stroke
    } for

grestore
} bind def

/ShowYaxisLabel {
  gsave
    SetStringFont

    % How far we move left depends on the size of
    % the tic labels.
     /str 10 string def % string to hold number
     yaxisBits yaxisTicBits div cvi yaxisTicBits mul 
     str cvs stringwidth pop
     ticWidth 1.5 mul add neg  

    yaxisHeight
    yaxisLabel stringwidth pop
    sub 2 div

    translate
    90 rotate
    0  yaxisLabel stringwidth pop fontsize [% ymax.length %] mul add  moveto                     %%%%%%%%%%%%%%%%% HARD CODE
    yaxisLabel show
  grestore
} bind def

/ShowYaxisLabelRight {
  gsave
    SetStringFont

    % How far we move left depends on the size of
    % the tic labels.
     /str 10 string def % string to hold number

     yaxisBits yaxisTicBits div cvi yaxisTicBits mul 
     str cvs stringwidth pop
     ticWidth 1.5 mul add

    yaxisHeight
    yaxisLabelRight stringwidth pop
    add 2 div

    /halfnumberheight
      yaxisLabelRight CharBoxHeight 2 div
    def

    translate
    -90 rotate
    0 halfnumberheight moveto
    % yaxisLabelRight stringwidth pop neg yaxisLabelRight stringwidth pop moveto
    yaxisLabelRight show
  grestore
} bind def

/StartStack {  % <stackNumber> startstack
  xaxis {MakeNumber}{pop} ifelse
  gsave
} bind def

/EndStack {
  grestore
  stackWidth 0 translate
} bind def


% Draw a character whose height is proportional to symbol bits
/MakeSymbol{  % charbits character (rgbcolor) MakeSymbol
  gsave
    /char exch def
    /bits exch def

    /bitsHeight 
%   bits pointsPerBit mul [% ymax %] mul
    bits pointsPerBit mul
    def
    /charHeight
       bitsHeight charTopMargin sub
       dup
       0.0 gt {}{pop 0.0} ifelse % if neg replace with zero 
    def 
 
    charHeight 0.0 gt {
       char SetColor
 % ->      0.7000   0.7000 1 setrgbcolor <-
      
      charWidth charHeight char ShowChar

      showingBox (s) eq { % Unfilled box
        0 0 charWidth charHeight false ShowBox
      } if

      showingBox (f) eq { % Filled box
        0 0 charWidth charHeight true ShowBox
      } if

    } if

  grestore

  0 bitsHeight translate 
} bind def


/ShowChar { % <width> <height> <char> ShowChar
  gsave
    /tc exch def    % The character
    /ysize exch def % the y size of the character
    /xsize exch def % the x size of the character

    /xmulfactor 1 def 
    /ymulfactor 1 def

    % if ysize is negative, make everything upside down!
    ysize 0 lt {
      % put ysize normal in this orientation
      /ysize ysize abs def
      xsize ysize translate
      180 rotate
    } if

    shrinking {
      xsize 1 shrink sub 2 div mul
        ysize 1 shrink sub 2 div mul translate 

      shrink shrink scale
    } if

    % Calculate the font scaling factors
    % Loop twice to catch small correction due to first scaling
    2 {
      gsave
        xmulfactor ymulfactor scale
      
        ysize % desired size of character in points
        tc CharBoxHeight 
        dup 0.0 ne {
          div % factor by which to scale up the character
          /ymulfactor exch def
        } % end if
        {pop pop}
        ifelse

        xsize % desired size of character in points
        tc CharBoxWidth
        dup 0.0 ne {
          div % factor by which to scale up the character
          /xmulfactor exch def
        } % end if
        {pop pop}
        ifelse
      grestore
    } repeat

    % Adjust horizontal position if the symbol is an I
    tc (I) eq {
      charWidth 2 div % half of requested character width
      tc CharBoxWidth 2 div % half of the actual character
      sub 0 translate
      % Avoid x scaling for I 
      /xmulfactor 1 def 
    } if


    % ---- Finally, draw the character
  
    newpath
    xmulfactor ymulfactor scale

    % Move lower left corner of character to start point
    tc CharBox pop pop % llx lly : Lower left corner
    exch neg exch neg
    moveto

    outline {  % outline characters:
      outlinewidth setlinewidth
      tc true charpath
      gsave 1 setgray fill grestore
      clip stroke
    } { % regular characters
      tc show
    } ifelse

  grestore
} bind def


/ShowBox { % x1 y1 x2 y2 filled ShowBox
  gsave
    /filled exch def 
    /y2 exch def
    /x2 exch def
    /y1 exch def
    /x1 exch def
    newpath
    x1 y1 moveto
    x2 y1 lineto
    x2 y2 lineto
    x1 y2 lineto
    closepath

    clip
    
    filled {
      fill
    }{ 
      0 setgray stroke   
    } ifelse

  grestore
} bind def

% number MakeNumber
/MakeNumber { 
  gsave
    SetNumberFont
    stackWidth 1.25 sub 0 translate
%     stackWidth logoHeight (0) CharBoxHeight sub topMargin 1.5 mul sub translate
     90 rotate            % rotate so the number fits
    dup stringwidth sub          % find the length of the number
%    dup stringwidth pop 1.5 mul  % find the length of the number
    neg                          % prepare for move
    stackMargin sub              % Move back a bit
    charWidth (0) CharBoxHeight  % height of numbers
    sub 2 div                    %
    moveto                       % move back to provide space
    show
  grestore
} bind def


/Ibeam{ % heightInBits Ibeam
  gsave
    % Make an Ibeam of twice the given height in bits
    /height exch  pointsPerBit mul def 
    /heightDRAW height IbeamFraction mul def

    IbeamLineWidth setlinewidth
    IbeamGray setgray 

    charWidth2 height neg translate
    ShowIbar
    newpath
      0 0 moveto
      0 heightDRAW rlineto
    stroke
    newpath
      0 height moveto
      0 height rmoveto
      currentpoint translate
    ShowIbar
    newpath
    0 0 moveto
    0 heightDRAW neg rlineto
    currentpoint translate
    stroke
  grestore
} bind def


/ShowIbar { % make a horizontal bar
  gsave
    newpath
      charWidth4 neg 0 moveto
      charWidth4 0 lineto
    stroke
  grestore
} bind def


/ShowLeftEnd {
  gsave
%    SetStringFont
    SetEndFont
    leftEndDeltaX leftEndDeltaY moveto
    showEnds (d) eq {(5) show ShowPrime} if
    showEnds (p) eq {(N) show} if
  grestore
} bind def

/ShowYaxisBarRight {
  gsave
  SetNumberFont
    /str 10 string def % string to hold number
    /smallgap stackMargin 2 div def

    % Draw first tic and bar
    gsave
      stackWidth neg 0 moveto
      stackWidth 0 rmoveto
      0 yaxisHeight rlineto
      stroke
    grestore


    % Draw the tics
    % initial increment limit proc for
    0 yaxisTicBitsRight yaxisBitsRight abs      %cvi
    {/loopnumber exch def

      % convert the number coming from the loop to a string
      % and find its width

      loopnumber 10 str cvrs
      /stringnumber exch def % string representing the number

      stringnumber stringwidth pop
      /numberwidth exch def % width of number to show

      /halfnumberheight
         stringnumber CharBoxHeight 2 div
      def

      numberwidth                     % move back width of number
      neg loopnumber pointsPerBitRight mul % shift on y axis
      halfnumberheight sub            % down half the digit

      moveto                          % move back the width of the string

      ticWidth neg smallgap sub           % Move back a bit more  
      0 rmoveto                       % move back the width of the tic

      ticWidth 2 mul smallgap 2 mul add numberwidth add 0 rmoveto
      
      stringnumber show
      smallgap 2 mul neg  0 rmoveto              % Make a small gap  

      % now show the tic mark
      numberwidth ticWidth add neg halfnumberheight rmoveto      % shift up again
      ticWidth 0 rlineto
      stroke
    } for

grestore
    gsave
    ShowYaxisLabelRight
    grestore
} bind def

/MakeYaxisRight {
    ShowYaxisBarRight
} bind def

/ShowRightEnd {
  gsave
%    SetStringFont
    SetEndFont
    rightEndDeltaX rightEndDeltaY moveto
    showEnds (d) eq {(3) show ShowPrime} if
    showEnds (p) eq {(C) show} if
  grestore
  yaxisright { MakeYaxisRight } if
} bind def


/ShowPrime {
  gsave
    SetPrimeFont
    (\242) show 
  grestore
} bind def


% <char> SetColor
/SetColor{
  dup colorDict exch known {
    colorDict exch get aload pop setrgbcolor
  } {
    pop
    defaultColor aload pop setrgbcolor
  } ifelse 
} bind def

% define fonts
/SetTitleFont {/[% IF titlefont %][% titlefont %][% ELSE %]Times-Bold[% END %] findfont titleFontsize scalefont setfont} bind def
/SetLogoFont  {/[% IF logofont %][% logofont %][% ELSE %]Helvetica-Bold[% END %] findfont charWidth  scalefont setfont} bind def
/SetStringFont{/[% IF stringfont %][% stringfont %][% ELSE %]Helvetica-Bold[% END %] findfont fontsize scalefont setfont} bind def
/SetEndFont{/[% IF endfont %][% endfont %][% ELSE %]Helvetica-Bold[% END %] findfont [% 16 * logowidth / 15 %] scalefont setfont} bind def
/SetPrimeFont {/Symbol findfont fontsize scalefont setfont} bind def
/SetSmallFont {/Helvetica findfont smallFontsize scalefont setfont} bind def

/SetNumberFont {
    /[% numberfont %] findfont 
    numberFontsize
    scalefont
    setfont
} bind def

%Take a single character and return the bounding box
/CharBox { % <char> CharBox <lx> <ly> <ux> <uy>
  gsave
    newpath
    0 0 moveto
    % take the character off the stack and use it here:
    true charpath
    flattenpath 
    pathbbox % compute bounding box of 1 pt. char => lx ly ux uy
    % the path is here, but toss it away ...
  grestore
} bind def


% The height of a characters bounding box
/CharBoxHeight { % <char> CharBoxHeight <num>
  CharBox
  exch pop sub neg exch pop
} bind def


% The width of a characters bounding box
 /CharBoxWidth { % <char> CharBoxHeight <num>
   CharBox
   pop exch pop sub neg 
 } bind def


% Deprecated names
/startstack {StartStack} bind  def
/endstack {EndStack}     bind def
/makenumber {MakeNumber} bind def
/numchar { MakeSymbol }  bind def

[% IF graphtype.match('curve|solid') %]
/ShowGraph {
    gsave
      logoWidth leftMargin sub rightMargin sub neg 0 translate
      gsave
      newpath
      [% bezier.starts.x3 %] [% bezier.starts.y3 %] pointsPerBit mul moveto

      [% FOREACH i= bezier.points %]
	[% IF graphtype.match('solid') %]
%	 charWidth 2 div stackMargin sub [% i.x3 %] add [% i.y3 %] pointsPerBit mul
	 [% i.x3 %] [% i.y3 %] pointsPerBit mul lineto
	[% ELSIF graphtype.match('curve')%]
	 [% i.x1 %] [% i.y1 %] [% i.x2 %] [% i.y2 %] [% i.x3 %] [% i.y3 %] pointsPerBit mul
	 curveto
	[% END %]
      [% END %]

      0.952941176470588 0.941176470588235 0 setrgbcolor
      4 setlinewidth
      [4 3] 0 setdash
      stroke
      grestore

      [% IF graphpoint %]
      gsave
      0 0 1 setrgbcolor
      [% bezier.starts.x3 %] [% bezier.starts.y3 %] pointsPerBit mul
      4 0 360 arc
      fill
      % 0 setgray
      stroke
      [% FOREACH i = bezier.points %]
         gsave
	 % 0.952941176470588 0.6 0.172549019607843 setrgbcolor
	 % 0 setgray
	 % 0 1 setrgbcolor
	 [% i.x3 %] [% i.y3 %] pointsPerBit mul
	 4 0 360 arc
	 fill
	 0 setgray
	 stroke
	 grestore
       [% END %]
      grestore
      [% END %]

     grestore
} bind def
[% END %]

%%EndProlog

%%Page: 1 1
StartLogo
StartLine % line number 1

[% FOREACH variable = atcoord %]
 ( [% variable.coordinate %] ) startstack
 gsave
 [% FOREACH i = variable.data %]
 [% i.num %]([% i.char %]) numchar
 [% END %]
 grestore
 gsave
 grestore
 endstack
[% END %]

[% IF graphtype.match('curve|solid') %]
ShowGraph
[% END %]

EndLine
EndLogo

%%EOF
