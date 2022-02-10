package Task1::Module;

use File::Stat;
use Test::Compile tests => 1;
use Data::Dumper;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw / File Name Distribution ICodeBase IsValid ModuleDependencies
   IModuleDependencies ProgramDependencies InstallInfo /

  ];

sub init {
  my ($s,%a) = @_;
  $s->File($a{File});
  $s->ICodeBase($a{ICodeBase});
  $s->IsValid
    ($s->BelongsToAValidFRDCSAPerlDistribution and
     $s->PerlModuleCompiles);
  if ($s->IsValid) {
    $s->GetModuleDependencies;
  }
  $s->IModuleDependencies({});
  $s->InstallInfo({});
}

sub BelongsToAValidFRDCSAPerlDistribution {
  my ($s,%a) = @_;
  my $file = $s->File;
  my $name = `grep -E '^package' "$file"`;
  if ($name =~ /^\s*package\s*(.+);\s*$/) {
    $packagename = $1;
    $fn = $packagename;
    $fn =~ s/::/\//g;
    $fn .= ".pm";
    my $icodebase = $s->ICodeBase;
    if ($file eq "/var/lib/myfrdcsa/codebases/internal/$icodebase/$fn") {
      if ($file !~ /#/) {
	print "\t$file\n";
	$s->Name($packagename);
	return 1;
      }
    } elsif ($file eq "/var/lib/myfrdcsa/codebases/minor/$icodebase/$fn") {
      if ($file !~ /#/) {
	print "\t$file\n";
	$s->Name($packagename);
	return 1;
      }
    }
  }
  return 0;
}

sub PerlModuleCompiles {
  my ($s,%a) = @_;
  return 1;
  return pm_file_ok($s->File, "Valid Perl module file") or 0;
}

sub GetModuleDependencies {
  my ($s,%a) = @_;
  $s->ModuleDependencies({});
  $s->ProgramDependencies({});
  my $file = $s->File;
  foreach my $line (split /\n/,`grep -E '^use ' $file`) {
    if ($line =~ /^use (.*?)[ ;]/) {
      $s->ModuleDependencies->{$1} = 1;
    }
  }
  foreach my $line (`grep '\`' $file`) {
    if ($line =~ /\`([^\`]+?)\s/) {
      my $programname = $1;
      if ($programname =~ /^[\w_\-\/]+$/) {
	$s->ProgramDependencies->{$programname} = 1;
      }
    }
  }
  foreach my $line (`grep 'system "' $file`) {
    if ($line =~ /system \"([^\"]+?)\s/) {
      my $programname = $1;
      if ($programname =~ /^[\w_\-\/]+$/) {
	$s->ProgramDependencies->{$programname} = 1;
      }
    }
  }
}

sub LastModified {
  my ($s,%a) = @_;
  my $stat = File::Stat->new
    ($s->File);
  return $stat->mtime;
}

sub ToCPANName {
  my ($s,%a) = @_;
  return "Org::FRDCSA::Alpha::".$s->Name;
}

1;
