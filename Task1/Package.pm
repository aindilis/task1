package Task1::Package;

use Task1::File;

use Data::Dumper;
use IO::File;
use String::ShellQuote;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw / Name ICodeBase Distribution Dists DebianPackage CPANPackage
   Depends Specs UnsatSpecs SpecialFiles /

  ];

sub init {
  my ($s,%a) = @_;
  $s->ICodeBase($a{ICodeBase});
  $s->Distribution($a{Distribution});
  $s->Name
    ($s->Distribution2PackageName
     (Distribution => $s->Distribution->Name));
  $s->Dists($a{Dists});
  $s->Specs({});
  $s->UnsatSpecs({});
  $s->SpecialFiles({});
}

# now we want to populate this with all sorts of useful stuff

sub Generate {
  my ($s,%a) = @_;
  my $package = $s->Name;
  my $depends = $s->GenerateDepends(%a);
  my $shortdesc = "Perl modules for ".$s->ICodeBase;
  # this causes a lintian error, need to add more here
  my $longdesc = $shortdesc."\n.\n";
  $longdesc .= $a{Self}->Descriptions->{Medium} ||
    $a{Self}->Descriptions->{Long} ||
      "FRDCSA $icodebase system (no description)";
  $longdesc =~ s/^$/./gm;
  $longdesc =~ s/^/ /gm;
  return
    "Package: $package
Section: perl
Architecture: any
Depends: $depends
Description: $shortdesc
$longdesc";
}

sub Distribution2PackageName {
  my ($s,%a) = @_;
  my $package = $a{Distribution};
  if ($package !~ /^lib(.+)-perl$/) {
    $package =~ s/\.pm$//;
    $package =~ s/::/-/g;
    $package =~ s/\+/-/g;
    $package =~ s/_//g;
    return lc("lib$package-perl");
  }
  return $package;
}

sub GenerateDepends {
  my ($s,%a) = @_;
  my $depends = {};
  my @tmp1;
  foreach my $distribution (keys %{$s->Dists->{FRDCSA}}) {
    my $package = $s->Distribution2PackageName
      (Distribution => $distribution);
    $depends->{FRDCSA}->{$distribution} = $package;
    push @tmp1, $package;
  }
  my @tmp2;
  foreach my $distribution (keys %{$s->Dists->{CPAN}}) {
    $distribution =~ s/^(.+)-.+?\.tar\.gz/$1/;
    my $irregular = {"perl" => 1};
    my $package;
    my $dependency;
    if (exists $irregular->{$distribution}) {
      $package = $distribution;
      $dependency = $package;
    } else {
      $package = $s->Distribution2PackageName
	(Distribution => $distribution);
      $dependency = "$package | cpan-$package";
    }
    $depends->{CPAN}->{$distribution} = $dependency;
    push @tmp2, $dependency;
  }
  my @tmp3;
  foreach my $package (keys %{$s->Distribution->PackageDependencies}) {
    if (! $s->MaskEssentialPackages
	(Package => $package)) {
      $depends->{Package}->{$package} = $package;
      push @tmp3, $package;
    }
  }
  my @tmp4;
  foreach my $distribution (keys %{$s->Dists->{Unknown}}) {
    # do an actual package lookup here
    my $package;
    my $res = $s->LookupDistribution2DebPackage
      (Distribution => $distribution);
    if (defined $res) {
      $package = $res;
    } else {
      $distribution =~ s/::/-/g;
      $package = "package-for-".lc($distribution);
    }
    $depends->{Unknown}->{$distribution} = $package;
    push @tmp4, $package;
  }
  print Dumper($depends) if $a{Debug};
  $s->Depends($depends);
  return join(", ", ((sort @tmp1),(sort @tmp2),(sort @tmp3),(sort @tmp4)));
}

sub GenerateDebianFiles {
  my ($s,%a) = @_;
  my @install;
  my $icodebase = $s->ICodeBase;
  foreach my $module ($s->Distribution->Modules->Values) {
    # get the file name
    my $file = $module->File;
    if ($file =~ s|/var/lib/myfrdcsa/codebases/internal/$icodebase/(.+)$||) {
      my $file2 = $1;
      if ($file2 =~ /((.+)\/)?([^\/]+.pm)/) {
	my $adjustment = "";
	if ($2) {
	  $adjustment = "/$2";
	}
	push @install, "$file2 usr/share/perl5$adjustment";
      }
    } elsif ($file =~ s|/var/lib/myfrdcsa/codebases/minor/$icodebase/(.+)$||) {
      my $file2 = $1;
      if ($file2 =~ /((.+)\/)?([^\/]+.pm)/) {
	my $adjustment = "";
	if ($2) {
	  $adjustment = "/$2";
	}
	push @install, "$file2 usr/share/perl5$adjustment";
      }
    } else {
      # print "FILE: <$icodebase><$file>\n";
      # these are fringe cases
    }
  }
  foreach my $key (keys %{$s->Distribution->InstallInfo->{Exec}}) {
    if ($key =~ /.+\/(.+)$/) {
      push @install, "$1 usr/bin";
    }
  }
  my $installfile =
    Task1::File->new
	(
	 Name => $a{DebianDir}."/".$s->Name.".install",
	 Contents => join("\n",sort @install),
	);
  if (-d $a{DebianDir}) {
    $installfile->Save if $a{Live};
  }
  $installfile->Print if $a{Debug};
  $s->SpecialFiles->{InstallFile} = $installfile;

  # Clear/* usr/share/perl5/Clear
  # Clear.pm usr/share/perl5

  #   # do the dirs file thing
  #   my $dirsfilename = "$debiandir/dirs";
  #   my $dirsfileindex = {};
  #   foreach my $s (split /\n/, `cat $dirsfilename`) {
  #     $dirsfileindex->{$s} = 1;
  #   }
  #   $dirsfileindex->{"usr/share/perl5"} = 1;
  #   my $dirsfile = Task1::File->new
  #     (
  #      Name => $dirsfilename,
  #      Contents => join("\n",sort keys %$dirsfileindex)."\n",
  #     );
  #   $dirsfile->Save;
}

sub LookupDistribution2DebPackage {
  my ($s,%a) = @_;
  if (exists $UNIVERSAL::task1->Distribution2DebPackage->{$a{Distribution}}) {
    return $UNIVERSAL::task1->Distribution2DebPackage->{$a{Distribution}};
  }
}

sub MaskEssentialPackages {
  my ($s,%a) = @_;
  return exists $UNIVERSAL::task1->Essential->{$a{Package}};
}

sub GetSpecs {
  my ($s,%a) = @_;
  if (! exists $s->Specs->{All}) {
    $s->Specs->{All} = {};
    foreach my $spec (keys %{$s->Specs->{Immediate}}) {
      $s->Specs->{All}->{$spec} = 1;
    }
    foreach my $packagename (keys %{$s->Specs->{Recursive}}) {
      my $package = $UNIVERSAL::task1->Packages->{$packagename};
      foreach my $spec 
	(keys %{$package->GetSpecs}) {
	$s->Specs->{All}->{$spec} = 1;
      }
    }
  }
  if (! exists $s->Specs->{Rest}) {
    $s->Specs->{Rest} = {};
    foreach my $key (sort keys %{$s->Specs->{All}}) {
      if (! exists $s->Specs->{Immediate}->{$key}) {
	$s->Specs->{Rest}->{$key} = 1;
      }
    }
  }
  if (! exists $s->UnsatSpecs->{All}) {
    $s->UnsatSpecs->{All} = {};
    foreach my $item (qw(Immediate Rest All)) {
      foreach my $spec (keys %{$s->Specs->{$item}}) {
	if ($UNIVERSAL::task1->SpecIsUnsatisfied(Spec => $spec)) {
	  $s->UnsatSpecs->{$item}->{$spec} = 1;
	}
      }
    }
  }
  return $s->Specs->{All};
}

sub NoUnsatSpecsP {
  my ($s,%a) = @_;
  return ! scalar keys %{$s->UnsatSpecs->{All}};
}

sub MakeCPANDistribution {
  my ($s,%a) = @_;
  my @install;
  my $res = $s->GetModuleNameString;
  my $names = $res->{Names};
  my $modulenamesstring = join(",",@$names);
  my $distro = $res->{Distro};
  my $licensestring = shell_quote "This library is free software; you can redistribute it and/or modify it under the terms of the GPL version 3 or later.\n\nSee the LICENSE file for a copy of the GPL 3.";
  if (-d $a{CPANDir}) {
    # we need to copy $module to FRDCSA::$module

    my $command = "cd ".$a{CPANDir}." && ".
      "module-starter --distro=$distro --module=$modulenamesstring --author=\"Andrew J. Dougherty\" --email=andrewdo\@frdcsa.org --license $licensestring";
    print "$command\n";
    system $command;

    # now edit the files

    # MANIFEST
    # 	add additional files

    # README
    #	add dependency information
    #	add license information

    # now copy the files into lib, and change them around
    foreach my $module (@{$res->{Modules}}) {
      my $name = $module->ToCPANName;
      my $temp = $name;
      $temp =~ s/::/\//g;
      my $newfile = join("/",($a{CPANDir},$distro,"lib",$temp)).".pm";
      my $command = "cp ".$module->File." ".$newfile;
      print "$command\n";
      system $command;

      # now edit the file
      $s->EditTheNewFile
	(
	 NewFile => $newfile,
	 Module => $module,
	);

      system "diff ".$module->File." ".$newfile;

      # add the pod documentation

      # include information on which modules use this module for reference
      if ($res->{Modules}->[0]->ToCPANName eq $name) {
	# this is the main one, throw in all the documentation
	$s->GeneratePod(Descriptions => $a{Descriptions});
      }

      my @predepends = map {$s->ToCPANName($_)} sort keys %{$module->IModuleDependencies};
      if (scalar @predepends) {
	print "In lieu of the documentation being written, to see examples of $name in use see these modules which depend on it: ".join(", ",@predepends)."\n";
      } else {
	print "The documentation has not been written and there are no modules which depend on it to use as an example :(\n";
      }
    }

    # add dependency information for CPAN to figure out which packages need to be installed with this
  }
}

sub GeneratePod {
  my ($s,%a) = @_;
  print Dumper(\%a);
}

sub GetModuleNameString {
  my ($s,%a) = @_;
  my @modulenames;
  my $minlength = 1000;
  my @modules = sort {$a->Name cmp $b->Name} $s->Distribution->Modules->Values;
  my $module = $modules[0];
  my $distro = $module->ToCPANName;
  $distro =~ s/::/-/g;
  foreach my $module (@modules) {
    my $n = $module->ToCPANName;
    push @modulenames, $n;
  }
  return {
	  Distro => $distro,
	  Modules => \@modules,
	  Names => \@modulenames,
	 };
}

sub ToCPANName {
  my ($s,$m) = @_;
  return "Org::FRDCSA::Alpha::$m";
}

sub FromCPANName {
  my ($s,$m) = @_;
  $m =~ s/^Org::FRDCSA::Alpha:://;
  return $m;
}

sub EditTheNewFile {
  my ($s,%a) = @_;
  my $newfile = $a{NewFile};
  my $c = `cat "$newfile"`;
  # do substitutions
  # iterate over all FRDCSA module names and do a replace
  my @tocheck = keys %{$a{Module}->ModuleDependencies};
  push @tocheck, $a{Module}->Name;
  foreach my $name (@tocheck) {
    if (exists $UNIVERSAL::task1->Modules->Contents->{$name}) {
      my $cname = $s->ToCPANName($name);
      $c =~ s/([^\w:])$name([^\w:])/$1$cname$2/g;
    }
  }
  my $fh = IO::File->new;
  $fh->open(">$newfile");
  print $fh $c;
  $fh->close;
  # add the pod for this item to the end
}

1;

