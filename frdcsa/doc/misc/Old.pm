sub OldGenerateToBeBuiltList {
  my ($s,%a) = @_;
  # need to find the names of all packages that have to be created
  my @res;
  foreach my $icodebase (values %{$s->ICodeBases}) {
    # read the icodebase control file
    $controlfile = "/var/lib/myfrdcsa/codebases/internal/".$icodebase->Name."/debian/control";
    my $c = `cat "$controlfile"`;
    foreach my $line (split /\n/, $c) {
      if ($line =~ /^Package: (.+)$/) {
	push @res, $1;
      }
      if ($line =~ /^Depends: (.+)$/) {
	push @res, $1;
      }
    }
  }
  my %hash = @res;
  my $hash2 = {};
  my $potential = {};
  foreach my $key (keys %hash) {
    foreach my $key2 (split /, /, $hash{$key}) {
      if ($key2 !~ /\|/) {
	$hash2->{$key}->{$key2} = 1;
	if (! exists $hash{$key2}) {
	  # this is a potentially to be built package
	  $potential->{$key2} = 1;
	}
      }
    }
  }
  my $aptcache = {};
  foreach my $line (split /\n/, `apt-cache search .`) {
    if ($line =~ /^(.+?) - /) {
      $aptcache->{$1} = 1;
    }
  }
  $s->AptCacheCache($aptcache);
  foreach my $packagename (sort keys %$potential) {
    if (! exists $aptcache->{$packagename}) {
      if ($packagename !~ /^package-for-/) {
	# this should be found and packaged
	if ($packagename =~ /^lib(.+)-perl$/) {
	  # this is a perl package, try to find what it is called
	  my $perlmod = $1;
	  $perlmod =~ s/-/::/g;
	  print "sudo radar install $perlmod\n";
	} else {
	  print "# package for $packagename\n";
	}
      }
    }
  }
}
