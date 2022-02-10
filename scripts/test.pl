#!/usr/bin/perl -w

use Task1::Module;

use Data::Dumper;

# my $file = "/var/lib/myfrdcsa/codebases/internal/radar/RADAR.pm";
my $file = "/var/lib/myfrdcsa/codebases/internal/packager/Packager/LearnTechniques.pm";

my $module = Task1::Module->new
  (
   File => $file,
   ICodeBase => 'packager',
  );

print Dumper($module->IsValid);
