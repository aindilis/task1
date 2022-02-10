#!/usr/bin/perl -w

my $c = `cat structure.pl`;
eval $c;

if (defined $VAR1) {
  my $ref = ref $VAR1;
  print $ref."\n";
}
