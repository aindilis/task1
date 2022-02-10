package Task1::ICodeBase;

use Manager::Dialog qw(ApproveCommands);
use Task1::File;

use Data::Dumper;
use File::Stat;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw / Name Packages Descriptions ControlFileContents DistDir
   DebianDir CPANDir ChangesFile OrigTarGzFile NeedsToBeBuilt Debug
   LastBuildTime SpecialFiles Live BuildStatus /

  ];

sub init {
  my ($s,%a) = @_;
  $s->BuildStatus({});
  $s->Name($a{Name});
  $s->Packages($a{Packages});
  $s->Descriptions($a{Descriptions});

  # get the debian dir
  my $icodebase = $s->Name;
  if (-d "/var/lib/myfrdcsa/codebases/internal/$icodebase") {
    my $distdir = "/var/lib/myfrdcsa/codebases/internal/$icodebase";
    $distdir = `chase "$distdir"`;
    chomp $distdir;
    my $debiandir = "$distdir/debian";
    my $cpandir = "$distdir/cpan";
    $s->DistDir($distdir);
    $s->DebianDir($debiandir);
    $s->CPANDir($cpandir);
    $s->SpecialFiles({});
  } elsif (-d "/var/lib/myfrdcsa/codebases/minor/$icodebase") {
    my $distdir = "/var/lib/myfrdcsa/codebases/minor/$icodebase";
    $distdir = `chase "$distdir"`;
    chomp $distdir;
    my $debiandir = "$distdir/debian";
    my $cpandir = "$distdir/cpan";
    $s->DistDir($distdir);
    $s->DebianDir($debiandir);
    $s->CPANDir($cpandir);
    $s->SpecialFiles({});
  }
}

sub MakePackage {
  my ($s,%a) = @_;
  if ($a{Type} eq "Debian") {
    $s->MakeDebianPackage(%a);
  } elsif ($a{Type} eq "CPAN") {
    $s->MakeCPANDistributions(%a);
  }
}

sub MakeDebianPackage {
  my ($s,%a) = @_;
  $s->Debug($a{Debug});
  $s->Live($a{Live});
  $s->OrigTarGzFile($s->GetOrigTarGzFile);
  if (! -d $s->DebianDir or ! -f $s->OrigTarGzFile) {
    print "It is a new build\n";
    $s->Debianize;
  }
  if (-d $s->DebianDir) {
    $s->GenerateSpecialFilesAndSave;
    if ($s->Live) {
      $s->GetLastBuildTime;
      # are there changes to the code?
      # are there changes to the special files?
      if ($s->ChangesToTheCodeP or
	  $s->ChangesToTheSpecialFilesP) {
	print "There have been changes to the code or special files\n";
	$s->NeedsToBeBuilt(1);
      }
      if ($s->NeedsToBeBuilt) {
	print "Building the package\n";
	$s->BuildStatus($s->Build);
	if (exists $s->BuildStatus->{UnrepresentableChanges}) {
	  $s->CleanDebian;
	  return 0;
	}
	$s->Upload;
      }
    }
  } else {
    print "No debian dir\n";
  }
}

sub MakeCPANDistributions {
  my ($s,%a) = @_;
  $s->Debug($a{Debug});
  $s->Live($a{Live});
  my $conf = $UNIVERSAL::task1->Config->CLIConfig;
  if (exists $conf->{'-c'}) {
    print "Howdy!\n";
    $s->CleanCPAN;
  }
  if (! -d $s->CPANDir) {
    print "It is a new build\n";
    mkdir $s->CPANDir;
  }
  if (-d $s->CPANDir) {
    $s->GenerateCPANFilesAndSave;
  } else {
    print "No cpan dir\n";
  }
}

sub GetLastBuildTime {
  my ($s,%a) = @_;
  # what about when there is no changes file or it is older than a
  # given cutoff?
  my $changesfile = $s->GetChangesFile;
  # $s->ChangesFile($changesfile);
  my $time;
  if (-f $changesfile) {
    my $fs = File::Stat->new
      ($changesfile);
    $time = $fs->mtime;
  } else {
    $time = 0;
  }
  $s->LastBuildTime($time);
}

sub ChangesToTheCodeP {
  my ($s,%a) = @_;
  my $max = -1;
  foreach my $package (values %{$s->Packages}) {
    foreach my $module ($package->Distribution->Modules->Values) {
      my $lm = $module->LastModified;
      if ($lm > $s->LastBuildTime) {
	print "recent changes to ".$module->Name." ($lm > ".$s->LastBuildTime.")\n";
      }
      if ($lm > $max) {
	$max = $lm;
      }
    }
  }
  return $max > $s->LastBuildTime;
}

sub ChangesToTheSpecialFilesP {
  my ($s,%a) = @_;
  my $max = -1;
  my @specialfiles = values %{$s->SpecialFiles};
  foreach my $package (values %{$s->Packages}) {
    foreach my $sf (values %{$package->SpecialFiles}) {
      push @specialfiles, $sf;
    }
  }
  foreach my $sf (@specialfiles) {
    my $lm = $sf->LastModified;
    if ($lm > $s->LastBuildTime) {
      print "recent changes to ".$sf->Name." ($lm > ".$s->LastBuildTime.")\n";
    }
    if ($lm > $max) {
      $max = $lm;
    }
  }
  return $max > $s->LastBuildTime;
}

sub GenerateSpecialFilesAndSave {
  my ($s,%a) = @_;
  $s->GenerateMakefile;
  $s->GenerateControlFile;
  $s->GenerateDebianFiles;
}

sub GenerateCPANFilesAndSave {
  my ($s,%a) = @_;
  foreach my $package (values %{$s->Packages}) {
    # go ahead and generate a distribution for each package
    $package->MakeCPANDistribution
      (
       Descriptions => $s->Descriptions,
       CPANDir => $s->CPANDir,
       Debug => $s->Debug,
       Live => $s->Live,
      );
  }
}

sub CleanDebian {
  my ($s,%a) = @_;
  my @commands;
  if (-f $s->OrigTarGzFile) {
    push @commands, "sudo rm \"".$s->OrigTarGzFile."\"";
  }
  if (-d $s->DebianDir) {
    push @commands, "sudo rm -rf \"".$s->DebianDir."\"";
  }

  # auto approve in the future
  ApproveCommands
    (
     Commands => \@commands,
     Method => "parallel",
    );
}

sub CleanCPAN {
  my ($s,%a) = @_;
  my @commands;
  if (-d $s->CPANDir) {
    push @commands, "sudo rm -rf \"".$s->CPANDir."\"";
  }

  # auto approve in the future
  ApproveCommands
    (
     AutoApprove => 1,
     Commands => \@commands,
     Method => "parallel",
    );
}

sub Debianize {
  my ($s,%a) = @_;
  if ($s->Live) {
    system "cd ".$s->DistDir." && (yes | dh_make --createorig --multi)";
  }
  $s->NeedsToBeBuilt(1);
}

sub Build {
  my ($s,%a) = @_;
  print $s->DistDir." is building\n";
  if ($s->Live) {
    my $dir = `pwd`;
    chdir $s->DistDir;
    # ((echo out >&1; echo err >&2) 3>&2 2>&1 1>&3) 2>&1 |  tee combined.txt
    # ((sudo dpkg-buildpackage) 3>&2 2>&1 1>&3) 2>&1 |  tee buildlog
    my $command = "((sudo dpkg-buildpackage) 3>&2 2>&1 1>&3) 2>&1 |  tee buildlog";
    system $command;
    my $c = `cat buildlog`;
    chdir $dir;
    if ($c =~ /unrepresentable changes to source/) {
      return {
	      UnrepresentableChanges => 1,
	      Repeat => 1,
	     };
    } # else if there is an error
    return {};
  }
}

sub Upload {
  my ($s,%a) = @_;
  print "Uploading\n";
  if ($s->Live) {
    # compute the name of the latest changes file
    my $changesfile = $s->GetChangesFile;
    if (-f $changesfile) {
      # next upload it using dput and mini-dinstall to the local package archive
      my $c = "dput -f -c /var/lib/myfrdcsa/codebases/internal/task1/conf-files/dput.cf -u local $changesfile";
      print "$c\n";
      system $c;
    }
  }
}


sub GenerateMakefile {
  my ($s,%a) = @_;
  # make the makefile
  my @installcommands = ();
  #   my @files = ();
  #   foreach my $file (@files) {
  #     push @installcommands, "cp \"$file\" \$(DESTDIR)/usr/share/perl5";
  #   }
  my $makefilename = $s->DistDir."/Makefile";
  my $templatefile = "/var/lib/myfrdcsa/codebases/internal/task1/data/files/template";
  my $template = `cat $templatefile`;
  # convert to using the perl specific templating language
  my $sysname = $s->Name;
  my $install = join("\n",map {"\t$_"} @installcommands);
  $template =~ s/<SYSNAME>/$sysname/g;
  $template =~ s/<INSTALL>/$install/g;
  my $makefile = Task1::File->new
    (
     Name => $makefilename,
     Contents => $template,
    );
  $makefile->Save if $s->Live;
  $makefile->Print if $s->Debug;
  $s->SpecialFiles->{MakeFile} = $makefile;
}

sub GenerateControlFile {
  my ($s,%a) = @_;
  my @items;
  my $icodebase = $s->Name;
  push @items, $s->GenerateControlFileSource;
  push @items, $s->GenerateControlFilePackages;
  foreach my $package (values %{$s->Packages}) {
    push @items, $package->Generate
      (Self => $s,
       %a);
  }
  $s->ControlFileContents(join("\n\n",@items));
  # print $s->ControlFileContents."\n";

  my $controlfile = Task1::File->new
    (Name => $s->DebianDir."/control",
     Contents => $s->ControlFileContents);
  if (-d $s->DebianDir) {
    $controlfile->Save if $s->Live;
  }
  $controlfile->Print if $s->Debug;
  $s->SpecialFiles->{ControlFile} = $controlfile;
}

sub GenerateControlFileSource {
  my ($s,%a) = @_;
  my $icodebase = $s->Name;
  return "Source: $icodebase
Section: unknown
Priority: optional
Maintainer: FRDCSA project <andrewdo\@frdcsa.org>
Build-Depends: debhelper (>= 4.1.46)
Build-Depends-Indep: perl (>= 5.8.8)";
}

sub GenerateControlFilePackages {
  my ($s,%a) = @_;
  my $icodebase = $s->Name;
  my $shortdesc = $s->Descriptions->{Short} || "FRDCSA $icodebase system (no description)";
  my $longdesc = $s->Descriptions->{Medium} ||
    $s->Descriptions->{Long} ||
      "FRDCSA $icodebase system (no description)";
  $longdesc =~ s/^$/./gm;
  $longdesc =~ s/^/ /gm;
  my $depends = join(", ",("myfrdcsa-base",sort map {$_->Name} values %{$s->Packages}));
  return "Package: $icodebase
Architecture: any
Depends: $depends
Description: $shortdesc
$longdesc";
}

sub GenerateDebianFiles {
  my ($s,%a) = @_;
  foreach my $package (values %{$s->Packages}) {
    $package->GenerateDebianFiles
      (
       DebianDir => $s->DebianDir,
       Debug => $s->Debug,
       Live => $s->Live,
      );
  }
}


# util

sub GetChangesFile {
  my ($s,%a) = @_;  
  my $distdir = $s->DistDir;
  my @res = split /\n/,`ls $distdir/../*.changes`;
  if (@res) {
    my $changesfile = shift @res;
    return $changesfile;
  }
}

sub GetOrigTarGzFile {
  my ($s,%a) = @_;  
  my $distdir = $s->DistDir;
  my @res = split /\n/,`ls $distdir/../*.orig.tar.gz`;
  if (@res) {
    my $origtargzfile = shift @res;
    return $origtargzfile;
  }
}

1;
