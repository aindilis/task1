#!/usr/bin/perl -w

foreach my $line (split /\n/, `dpkg -l`) {
  my ($thing,$package,$version,@junk) = split /\s+/, $line;
  if ($package =~ /\-perl\b/) {
    print $package."\n";
  }
}

foreach $line (split /\n/, `perldoc perllocal`) {
  if ($line =~ /(Sun|Mon|Tue|Wed|Thu|Fri|Sat) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (\d+) ([\d\:]+) (\d{4}): "Module" (.+)$/) {
    print $6."\n";
  }
}
