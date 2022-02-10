package Task1;

# this program refactors distributions in order to expedite the
# packaging of the FRDCSA for CPAN and Debian

# currently does not handle scripts, but at is has a record of
# refactorings, should not be difficult to apply them at a later stage

use Task1::Distribution;
use Task1::Module;
use Task1::Package;
use Task1::ICodeBase;

use BOSS::Config;
use BOSS::ICodebase qw(GetDescriptions2);
use Manager::Dialog qw(Approve QueryUser ChooseByProcessor);
use MyFRDCSA;
use PerlLib::Collection;
use PerlLib::SwissArmyKnife;
use PerlLib::UI;
use Sayer;

use CPANPLUS::Backend;
use Data::Dumper;
use File::Stat;
use Graph::Directed;
use IO::File;
use Text::Wrapper;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw / Config MyCPANPLUS DistributionRefactorings
	iDistributionRefactorings Modules Distributions
	InterDependencyGraph Program2DebPackage ICodebaseDescriptions
	PackagingOrder ICodeBases MyUI Distribution2DebPackage
	Essential AptCacheCache Packages ReverseSpecs
	ReverseUnsatSpecs MySayer Codes /

  ];

sub init {
  my ($s,%a) = @_;
  $specification = "
	-r				Reindex systems
	--clear-cache			Clear the Sayer Cache
	-b				List missing debian packages

	-p [<icodebase>...]		Make packages
	-a				Make all packages
	-t <type>			Type: (CPAN or Debian)

	-d				Debug
	-l				Live (actually build packages and write files)

	-c				Force clean

	-m <item>			Look up all modules for a distribution or package
	--dist-depends-on <item>	Look up all distributions that depend on a given module
	--module-depends-on <item>	Look up all modules that depend on a given module

	--list-modules			Make a list of all the modules in the system

	--list-required-cpan-modules	Make a list of all CPAN modules that the FRDCSA uses, with their apt-get names if they exist
";
  $UNIVERSAL::systemdir = ConcatDir(Dir("internal codebases"),"task1");
  $s->Config(BOSS::Config->new
	     (Spec => $specification,
	      ConfFile => ""));
  my $conf = $s->Config->CLIConfig;

  $s->Distribution2DebPackage({});
  if (-f "data/files/distribution-debians.pl") {
    my $c = `cat data/files/distribution-debians.pl`;
    my $e = MyEval($c);
    $s->Distribution2DebPackage($e);
  }
  if (-f "data/files/essential.pl") {
    my $c = `cat data/files/essential.pl`;
    my $e = MyEval($c);
    $s->Essential($e);
  }
}

sub Execute {
  my ($s,%a) = @_;
  my $config = $s->Config;
  my $conf = $s->Config->CLIConfig;
  my $savefile = "data/files/structure.pl";
  local $Data::Dumper::Purity = 1;
  $s->MySayer
    (Sayer->new
     (
      DBName => "sayer_task1",
      Quiet => 1,
     ));
  if (exists $conf->{'--clear-cache'}) {
    $s->MySayer->ClearCache;
  }

  my $hascycles;
  if (! -f $savefile or exists $conf->{'-r'}) {
    $s->Codes
      ({
	ProcessFile => sub {
	  my $file = $_[0]->{File};
	  my $icodebase = $_[0]->{ICodeBase};
	  my $module = Task1::Module->new
	    (
	     File => $file,
	     ICodeBase => $icodebase,
	    );
	  my $validity = $module->IsValid();
	  return {
		  Module => $module,
		  Validity => $validity,
		 };
	},
	InstallInfo => sub {
	  my $installinfo = CheckForInstallInformation
	    (
	     File => $_[0]->{File},
	     ICodeBase => $_[0]->{ICodeBase},
	    );
	  return $installinfo;
	},
       });
    $s->Modules
      (PerlLib::Collection->new
       (Type => "Task1::Module"));
    $s->Modules->Contents({});
    $s->LoadFRDCSAPerlDistributions;
    if (1) {
      my $OUT;
      open OUT, ">$savefile";
      print OUT Dumper($s);
      close(OUT);
    }
  } else {
    my $c = `cat "$savefile"`;
    $s = MyEval($c);
    $UNIVERSAL::task1 = $s;
    $UNIVERSAL::task1->Config($config);
  }

  $s->MyCPANPLUS(CPANPLUS::Backend->new);

  do {
    $s->Distributions
      (PerlLib::Collection->new
       (Type => "Task1::Distribution"));
    $s->Distributions->Contents({});
    $s->LoadDistributionRefactorings;
    $s->iDistributionRefactorings({});
    foreach $distribution (keys %{$self->DistributionRefactorings}) {
      my $moduleinfo = $self->DistributionRefactorings->{$distribution};
      my $ref = ref($moduleinfo);
      if ($ref eq "") {
	if ($moduleinfo == 1) {
	  $self->iDistributionRefactorings->{$distribution} = $distribution;
	} else {
	  $self->iDistributionRefactorings->{$moduleinfo} = $distribution;
	}
      } elsif ($ref eq "HASH") {
	foreach my $module (keys %{$self->DistributionRefactorings->{$moduleinfo}}) {
	  $self->iDistributionRefactorings->{$module} = $moduleinfo;
	}
      }
    }
    my $seen = {};
    foreach my $module ($s->Modules->Values) {
      my $distribution = $s->GetModuleDistribution
	(Module => $module);
      my $dumper = Dumper($distribution);
      if (! exists $seen->{$dumper}) {
	$distribution->InstallInfo(undef);
	$seen->{$dumper} = 1;
      }
      if (defined $module->InstallInfo and scalar keys %{$module->InstallInfo}) {
	$distribution->InstallInfo($module->InstallInfo);
      }
    }
    $s->CalculateDistributionDependencies;
    # eliminate cycles
    $hascycles = $s->DetectCycles();
  } while ($hascycles);

  $s->Explode;
  if (exists $conf->{'-p'}) {
    print Dumper($conf);
    my @icodebases;
    my @wanted;
    if (exists $conf->{'-a'}) {
      @wanted = keys %{$s->ICodeBases};
    } else {
      @wanted = @{$conf->{'-p'}};
    }
    foreach my $name (@wanted) {
      if (exists $s->ICodeBases->{$name}) {
	push @icodebases, $s->ICodeBases->{$name};
      } else {
	print "No icodebase by that name\n";
      }
    }
    $s->MakePackages
      (
       ICodeBases => \@icodebases,
       Live => exists $conf->{'-l'},
       Debug => exists $conf->{'-d'},
       Type => $conf->{'-t'},
      );

  } elsif (
	   exists $conf->{'-b'} or
	   exists $conf->{'--dist-depends-on'} or
	   exists $conf->{'--module-depends-on'}
	  ) {
    $s->MakePackages
      (
       Live => 0,
       Debug => 0,
       Type => $conf->{'-t'},
      );
  }
  $s->PopulatePackages;
  $s->GenerateToBeBuiltList if (exists $conf->{'-b'} or
				exists $conf->{'--dist-depends-on'} or
				exists $conf->{'--module-depends-on'}
			       );

  if (exists $conf->{'-m'}) {
    print Dumper([sort $s->Distributions->Keys]);
    # lookup this distributions information
    $s->Distributions->Contents->{$conf->{'-m'}}->PrintModules;
  }

  if (exists $conf->{'--dist-depends-on'} or exists $conf->{'--module-depends-on'}) {
    if (exists $conf->{'--dist-depends-on'}) {
      my $module = $conf->{'--dist-depends-on'};
      my $myspec;
      foreach my $spec (sort keys %{$s->ReverseSpecs}) {
	foreach my $item (split / \| /,$spec) {
	  if ($item eq $module) {
	    $myspec = $spec;
	  }
	}
      }
      if (! $myspec) {
	print "No matching spec found\n";
	print Dumper([sort keys %{$s->ReverseSpecs}]);
      } else {
	print Dumper($s->ReverseSpecs->{$myspec});
      }
    }
    if (exists $conf->{'--module-depends-on'}) {

    }
  }
  if (exists $conf->{'--list-modules'}) {
    foreach my $module (sort {$a->Name cmp $b->Name} $s->Modules->Values) {
      print $module->Name."\n";
    }
  }
}

sub DetectCycles {
  my ($s,%a) = @_;
  if (1) {
    my $OUT;
    open OUT, ">data/files/graph";
    print OUT Dumper($s->InterDependencyGraph);
    close(OUT);
  }
  my @cycle = $s->InterDependencyGraph->find_a_cycle;
  if (scalar @cycle) {
    print "Cycle(s) detected\n";
    print Dumper(\@cycle);
    # now's the time to trace this linkages
    $s->PrintCycle
      (Cycle => \@cycle);
    print "Please edit the data/files/distributions file and press enter\n";
    GetSignalFromUserToProceed();
    return 1;
  }
  return 0;
}

sub PopulatePackages {
  my ($s,%a) = @_;
  my $packages = {};
  foreach my $icodebase (values %{$s->ICodeBases}) {
    foreach my $package (values %{$icodebase->Packages}) {
      $packages->{$package->Name} = $package;
    }
  }
  $s->Packages($packages);
}

sub LoadDistributionRefactorings {
  my ($s,%a) = @_;
  my $c = `cat data/files/distributions`;
  my $e = MyEval($c);
  $e ||= {};
  $s->DistributionRefactorings($e);
}

sub GetModuleDistribution {
  my ($s,%a) = @_;
  # for a given FRDCSA perl module, check
  my $mod = $a{Module};
  my $dist;
  if (exists $s->iDistributionRefactorings->{$mod->Name}) {
    $dist = $s->iDistributionRefactorings->{$mod->Name};
    # $s->iDistributionRefactorings->{$mod->Name};
  } else {
    $dist = $mod->Name;
    $dist =~ s/::.*//;
  }
  my $distribution;
  if (exists $s->Distributions->Contents->{$dist}) {
    $distribution = $s->Distributions->Contents->{$dist};
  } else {
    $distribution = Task1::Distribution->new
      (
       Name => $dist,
       Type => "FRDCSA",
       ICodeBase => $mod->ICodeBase,
      );
    $s->Distributions->Add($distribution->Name => $distribution);
  }
  $distribution->Modules->Add($mod->Name => $mod);
  $mod->Distribution($distribution);
  return $distribution;
}

sub LoadFRDCSAPerlDistributions {
  # find the perl modules that are contained immediately within an
  # icodebase
  my ($s,%a) = @_;
  my $conf = $s->Config->CLIConfig;
  my @modules;
  foreach my $icodebase (split /\n/, `ls /var/lib/myfrdcsa/codebases/internal`) {
    print "<$icodebase>\n";
    foreach my $file (split /\n/, `find /var/lib/myfrdcsa/codebases/internal/$icodebase/`) {
      if ($file =~ /\.pm$/) {
	$s->ProcessFile
	  (
	   File => $file,
	   ICodeBase => $icodebase,
	  );
      }
    }
  }
  foreach my $minorcodebase (split /\n/, `ls /var/lib/myfrdcsa/codebases/minor`) {
    print "<$minorcodebase>\n";
    foreach my $file (split /\n/, `find /var/lib/myfrdcsa/codebases/minor/$minorcodebase/`) {
      if ($file =~ /\.pm$/) {
	$s->ProcessFile
	  (
	   File => $file,
	   ICodeBase => $minorcodebase,
	  );
      }
    }
  }
}

sub ProcessFile {
  my ($s,%a) = @_;
  my $file = $a{File};
  my $icodebase = $a{ICodeBase};
  my $stat = File::Stat->new($file);
  my @results =
    $s->MySayer->ExecuteCodeOnData
      (
       CodeRef => $s->Codes->{ProcessFile},
       Data => [{
		 File => $file,
		 ICodeBase => $icodebase,
		 FileInfo => $stat->mtime,
		}],
       # Overwrite => 0,
       # NoRetrieve => $a{NoRetrieve},
       # Skip => $a{Skip},
      );
  my $module = $results[0]->{Module};
  my $validity = $results[0]->{Validity};
  if ($validity) {
    $s->Modules->Add($module->Name => $module);
    my @results2 =
      $s->MySayer->ExecuteCodeOnData
	(
	 CodeRef => $s->Codes->{InstallInfo},
	 Data => [{
		   File => $file,
		   ICodeBase => $icodebase,
		   FileInfo => $stat->mtime,
		  }],
	);
    # do some additional checks for files that we should use
    my $installinfo = $results2[0];
    # print Dumper($installinfo);
    if (scalar keys %$installinfo) {
      $module->InstallInfo($installinfo);
    }
  }
}

sub CheckForInstallInformation {
  my (%a) = @_;
  my $file = $a{File};
  my $icodebase = $a{ICodeBase};
  my $installinfo = {};
  my $icodebasedir = "var/lib/myfrdcsa/codebases/internal";
  my $minorcodebasedir = "var/lib/myfrdcsa/codebases/minor";
  if ($file =~ /$icodebasedir\/$icodebase\/([^\/]+)$/) {
    # this file is a root .pm file or directory
    my $t1 = $1;
    if ($t1 =~ /^(.+)\.pm$/) {
      my $c = "grep \"use $1;\" /$icodebasedir/$icodebase/*";
      # there may be a file including this in the home dir, grep it
      foreach my $line (split /\n/, `$c`) {
	if ($line =~ /(.+)?:use.*/) {
	  my $exec = $1;
	  if ($exec !~ /~/) {
	    $installinfo->{Exec}->{$exec} = 1;
	  }
	}
      }
    }
    $installinfo->{Links}->{$t1} = 1;
  } elsif ($file =~ /$minorcodebasedir\/$icodebase\/([^\/]+)$/) {
    # this file is a root .pm file or directory
    my $t1 = $1;
    if ($t1 =~ /^(.+)\.pm$/) {
      my $c = "grep \"use $1;\" /$minorcodebasedir/$icodebase/*";
      # there may be a file including this in the home dir, grep it
      foreach my $line (split /\n/, `$c`) {
	if ($line =~ /(.+)?:use.*/) {
	  my $exec = $1;
	  if ($exec !~ /~/) {
	    $installinfo->{Exec}->{$exec} = 1;
	  }
	}
      }
    }
    $installinfo->{Links}->{$t1} = 1;
  }

  return $installinfo;
}

sub CalculateDistributionDependencies {
  my ($s,%a) = @_;
  # an interdistribution dependency consists of a link
  # distribution1 contains module1 dependson module2 containedby distribution2
  # we need to calculate a list of these
  $s->InterDependencyGraph(Graph::Directed->new);
  $s->Program2DebPackage({});
  if (-f "data/files/program-debians.pl") {
    my $c = `cat data/files/program-debians.pl`;
    my $e = MyEval($c);
    $s->Program2DebPackage($e);
  }
  foreach my $distribution ($s->Distributions->Values) {
    foreach my $module1 ($distribution->Modules->Values) {
      foreach my $mn2 (keys %{$module1->ModuleDependencies}) {
	if (exists $s->Modules->Contents->{$mn2}) {
	  my $module2 = $s->Modules->Contents->{$mn2};
	  $module2->IModuleDependencies->{$module1->Name} = 1;
	  # this module belongs to an FRDCSA distribution
	  # print $module2->Name."\n";
	  $distribution2 = $module2->Distribution;
	  if ($distribution->Name ne $distribution2->Name) {
	    # print "adding: ".$distribution->Name.", ".$distribution2->Name."\n";
	    $s->InterDependencyGraph->add_edge
	      ($distribution->Name,$distribution2->Name);
	    $distribution->DistributionDependencies->{$distribution2->Name} = 1;
	    $distribution->DistributionDependencies2->{$distribution2->Name}->{$module1->Name}->{$mn2} = 1;
	    # print $distribution2->Name."###\n";
	  }
	} else {
	  # this is an external module and should just be added
	  if ($mn2 =~ /^(IO::(Socket|Handle|Select))$/) {
	    $distribution->PackageDependencies->{"perl-base"} = 1;
	  } else {
	    $distribution->DistributionDependencies->{$mn2} = 1;
	  }
	}
      }
      foreach my $prog (keys %{$module1->ProgramDependencies}) {
	my $package = $s->GetPackageForProgram
	  (Module => $module1,
	   Program => $prog);
	$distribution->PackageDependencies->{$package} = 1 if $package;
      }
    }
  }
  my $OUT;
  open OUT, ">data/files/program-debians.pl";
  print OUT Dumper($s->Program2DebPackage);
  close OUT;
}

sub Explode {
  my ($s,%a) = @_;
  # compute a total ordering on the FRDCSA distributions
  my @ts = reverse $s->InterDependencyGraph->topological_sort;
  $s->PackagingOrder(\@ts);

  # now we want to iterate over this list and enumerate the stuff
  my $icodebases = {};
  foreach my $distribution1 (@ts) {
    # come up with the instructions for packaging this

    # print "# packaging $distribution1\n";

    # we want to list all the distributions it depends on
    my $dist1 = $s->Distributions->Contents->{$distribution1};
    my $frdcsadists = {};
    my $cpandists = {};
    my $unknowndists = {};
    my $distindex = {};
    foreach my $distribution2 (keys %{$dist1->DistributionDependencies}) {
      if (exists $s->Distributions->Contents->{$distribution2}) {
	# this is an frdcsa distribution
	my $xdist = $s->Distributions->Contents->{$distribution2};
	$frdcsadists->{$xdist->Name} = $xdist;
      } else {
	# need to check here/somewhere which debian package if any
	# this is already in
	my $module_obj = $s->MyCPANPLUS->module_tree()->{$distribution2};
	if (exists $module_obj->{package}) {
	  # this is a cpan module
	  $cpandists->{$module_obj->{package}} = $module_obj;
	} else {
	  # this module belongs to an unknown distribution
	  # do a lookup to see if its in the irregular list
	  $unknowndists->{$distribution2} = 1;
	}
      }
    }
    my $dists = {
		 FRDCSA => $frdcsadists,
		 CPAN => $cpandists,
		 Unknown => $unknowndists,
		};
    # now we want to go ahead and engineer the results
    $icodebases->{$dist1->ICodeBase}->{$dist1} =
      Task1::Package->new
	  (
	   Distribution => $dist1,
	   Dists => $dists,
	   ICodeBase => $dist1->ICodeBase,
	  );
  }
  $s->ICodebaseDescriptions(GetDescriptions2());
  foreach my $icodebase (keys %$icodebases) {
    $icodebases->{$icodebase} =
      Task1::ICodeBase->new
	  (
	   Name => $icodebase,
	   Packages => $icodebases->{$icodebase},
	   Descriptions => $s->ICodebaseDescriptions->{$icodebase},
	  );
  }
  $s->ICodeBases($icodebases);
}

sub PrintCycle {
  my ($s,%a) = @_;
  my $list = $a{Cycle};
  for (my $i = -1; $i < scalar @$list - 1; ++$i) {
    my $dist1 = $s->Distributions->Contents->{$list->[$i]};
    print Dumper
      ({
	List => [$list->[$i],$list->[$i+1]],
	Mods => $dist1->DistributionDependencies2->{$list->[$i + 1]},
       });
  }
}

sub MakePackages {
  my ($s,%a) = @_;
  # iterate over icodebases, printing
  my @icodebases;
  if (exists $a{ICodeBases}) {
    @icodebases = @{$a{ICodeBases}};
  } else {
    @icodebases = values %{$s->ICodeBases};
  }
  foreach my $icodebase (@icodebases) {
    do {
      $icodebase->MakePackage
	(
	 Live => $a{Live},
	 Debug => $a{Debug},
	 Type => $a{Type},
	);
    } while (exists $icodebase->BuildStatus->{Repeat});
  }
  if ($a{Live}) {
    system "mini-dinstall --batch";
  }
}

sub GetPackageForProgram {
  my ($s,%a) = @_;
  local $prog = $a{Program};
  if (0) {
    print $a{Module}->Name."\n";
    print $prog."\n";
    print "\n";
  }
  local $package;
  if (exists $s->Program2DebPackage->{$prog}) {
    $package = $s->Program2DebPackage->{$prog};
  } else {
    my $file = `which $prog`;
    chomp $file;
    if (-f $file) {
      my $res = `dlocate $file`;
      foreach my $line (split /\n/,$res) {
	if ($line =~ /^(.+):\s+$file$/) {
	  $package = $1;
	  last;
	}
      }
    }
    if (! $package) {
      $package = "package-for-$prog";
    }
    while (! $package) {
      print "Module: ".$a{Module}->Name."\n";
      print "Requires program: $prog\n";
      $package = "";
      if (! $s->MyUI) {
	$s->MyUI
	  (PerlLib::UI->new
	   (Menu => [
		     "Main Menu", [
				   "apt-file",
				   sub {$package = $s->GetPackageForProgramAptFile
					  (Program => $prog)},
				   "Manual",
				   sub {$package = QueryUser("What package does $prog belong to?")},
				   "Not packaged yet",
				   sub {print "Not packaged yet\n"},
				   "No package needed",
				   sub {print "No package needed\n"},
				   "Unknown package",
				   sub {print "Unknown package\n"},
				   "Use current package",
				   sub {print "Using current package <$package>\n";
					$s->MyUI->ExitEventLoop;},
				  ],
		    ],
	    CurrentMenu => "Main Menu",
	    Hooks => {
		      Refresh => sub {print "Current Package: <$package>\n";},
		     },
	   ));
      }
      $s->MyUI->BeginEventLoop;
      print "Using package: <$package>\n";
    }
    $s->Program2DebPackage->{$prog} = $package;
  }
  return $package;
}

sub GetPackageForProgramAptFile {
  my ($s,%a) = @_;
  my $prog = $a{Program};
  if ($prog !~ q|/|) {
    $prog = "bin/$prog";
  }
  print "using $prog\n";
  my $res = `apt-file search $prog`;
  my @matches;
  foreach my $line (split /\n/, $res) {
    if ($line =~ /(.+?): (.+$prog)$/) {
      push @matches, [$1,$2];
    }
  }
  $res = ChooseByProcessor
    (Values => \@matches,
     Processor => sub {$_->[0].": ".$_->[1]});
  print Dumper($res);
  if (@$res) {
    return $res->[0]->[0];
  }
}

sub AptCaching {
  my ($s,%a) = @_;
  print "AptCaching\n";
  my $aptcache = {};
  foreach my $line (split /\n/, `apt-cache search .`) {
    if ($line =~ /^(.+?) - /) {
      $aptcache->{$1} = 1;
    }
  }
  $s->AptCacheCache($aptcache);
  print "Done\n";
}

sub GenerateToBeBuiltList {
  my ($s,%a) = @_;
  # here we build a list of all packages, their interdependencies, and
  # make a list of items to be packaged in order to maximize how many
  # or which in particular we can install
  $s->AptCaching;
  my $wrapper = Text::Wrapper->new(columns => 80);
  # calc immediate dependencies
  foreach my $package (values %{$s->Packages}) {
    if (defined $package->Depends) {
      foreach my $source (qw(CPAN Package Unknown)) {
	foreach my $spec (values %{$package->Depends->{$source}}) {
	  if ($spec) {
	    $package->Specs->{Immediate}->{$spec} = 1;
	  }
	}
      }
      foreach my $spec (values %{$package->Depends->{FRDCSA}}) {
	$package->Specs->{Recursive}->{$spec} = 1;
      }
    } else {
      print "No depends defined for ".$package->Name."?\n";
    }
  }

  # there should be no cycles so we should be able to recurse
  # $ideps->{$spec}->{$package->Name} = 1;
  # now calculate all dependencies
  my $specs = {};
  my $unsatspecs = {};
  foreach my $package (values %{$s->Packages}) {
    $package->GetSpecs;

    # add up results for most depended on missing dependency here
    foreach my $spec (keys %{$package->Specs->{Immediate}}) {
      $specs->{$spec}->{Immediate}->{$package->Name} = 1;
      $specs->{$spec}->{All}->{$package->Name} = 1;
    }
    foreach my $spec (keys %{$package->Specs->{Rest}}) {
      $specs->{$spec}->{Rest}->{$package->Name} = 1;
      $specs->{$spec}->{All}->{$package->Name} = 1;
    }
    foreach my $spec (keys %{$package->UnsatSpecs->{Immediate}}) {
      $unsatspecs->{$spec}->{Immediate}->{$package->Name} = 1;
      $unsatspecs->{$spec}->{All}->{$package->Name} = 1;
    }
    foreach my $spec (keys %{$package->UnsatSpecs->{Rest}}) {
      $unsatspecs->{$spec}->{Rest}->{$package->Name} = 1;
      $unsatspecs->{$spec}->{All}->{$package->Name} = 1;
    }
  }
  $s->ReverseSpecs($specs);
  $s->ReverseUnsatSpecs($unsatspecs);

  # now that we've built that we can display it
  print "Unsatisfied dependencies per package.\n";
  my @dependencies;
  foreach my $package (values %{$s->Packages}) {
    print "\t".$package->Name."\n";
    print "\t\tImmediate\n";
    print "\t\t\t".$wrapper->wrap(join(", ",sort keys %{$package->UnsatSpecs->{Immediate}}))."\n";
    # print Dumper($package->Specs->{Recursive});
    print "\t\tRest\n";
    print "\t\t\t".$wrapper->wrap(join(", ",sort keys %{$package->UnsatSpecs->{Rest}}))."\n";
    print "\n";
    if ($package->NoUnsatSpecsP) {
      push @dependencies, $package->Name;
    }
  }
  # generate and upload the dummy package myfrdcsa-all
  # $s->GenerateAndUploadDummyPackage(Dependencies => \@dependencies);

  print "\n";
  print "Sorted list of dependencies based on most needed.\n";
  foreach my $spec (sort {scalar keys %{$specs->{$b}->{All}} <=> scalar keys %{$specs->{$a}->{All}}} keys %$specs) {
    print "\t".$spec."\n";
    print "\t\tImmediate\n";
    print "\t\t\t".$wrapper->wrap(join(", ",sort keys %{$s->ReverseUnsatSpecs->{$spec}->{Immediate}}))."\n";
    print "\t\tRest\n";
    print "\t\t\t".$wrapper->wrap(join(", ",sort keys %{$s->ReverseUnsatSpecs->{$spec}->{Rest}}))."\n";
    print "\n";
  }
  print "\n";

  # THIS IS WRONG FOR SOME REASON

  print "Installation commands for most needed dependencies.\n";
  foreach my $spec (sort {scalar keys %{$s->ReverseUnsatSpecs->{$b}} <=> scalar keys %{$s->ReverseUnsatSpecs->{$a}}} keys %$specs) {
    foreach my $item (split / \| /,$spec) {
      if ($item !~ /^(cpan-|package-for-)/) {
	if ($item =~ /^lib(.*)-perl$/) {
	  my $perlmod = $1;
	  $perlmod =~ s/-/::/g;
	  # perl mod
	  print "sudo radar -m 'Perl Module' install $perlmod\n";
	} else {
	  print "# package for $item\n";
	}
      }
    }
  }
}

sub MyEval {
  my $c = shift @_;
  $VAR1 = undef;
  eval $c;
  my $item = $VAR1;
  $VAR1 = undef;
  return $item;
}

sub SpecIsUnsatisfied {
  my ($s,%a) = @_;
  foreach my $item (split / \| /,$a{Spec}) {
    if (exists $s->AptCacheCache->{$item}) {
      return 0;
    }
  }
  return 1;
}

1;
