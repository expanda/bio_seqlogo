#!perl -T

use Test::More tests => 1;

BEGIN {
  use_ok( 'Bio::SeqLogo' );
}

diag( "Testing Bio::SeqLogo $Bio::SeqLogo::VERSION, Perl $], $^X" );
