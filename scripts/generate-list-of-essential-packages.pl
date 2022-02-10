#!/usr/bin/perl -w

use Data::Dumper;

my $essential = {};
foreach my $item (split /\n\n/,`apt-cache search . -f`) {
  if ($item =~ /Essential: yes/si) {
    if ($item =~ /^Package: (.*)$/m) {
      $essential->{$1} = 1;
    }
  }
}

print Dumper($essential);
