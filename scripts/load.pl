#!/usr/bin/perl -w

use Data::Dumper;

local $Data::Dumper::Purity = 1;

my $c = `cat structure.pl`;
my $e = eval $c;
my $r = ref $e;
print $r."\n";
# print Dumper($e);
