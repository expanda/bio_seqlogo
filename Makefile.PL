use inc::Module::Install;

name     'Bio-SeqLogo';
author   'Hiroyuki Nakamura <hryk@cpan.org>';
version_from 'lib/Bio/SeqLogo.pm';
abstract 'Yet another makelogo';
license 'perl';
perl_version '5.006';

requires 'Pod::Usage' => 0;
requires 'YAML' => 0;
requires 'Template'   => 0;
requires 'XML::Parser' => 0;

# install script

install_script 'bin/seqlogo';

auto_install;

WriteAll;

