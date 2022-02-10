package Task1::Distribution;

use Data::Dumper;
use PerlLib::Collection;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw / Name Type ICodeBase Modules DistributionDependencies
   DistributionDependencies2 CPANObj AptDepends CPANDepends
   PackageDependencies InstallInfo /

  ];

sub init {
  my ($s,%a) = @_;
  $s->Name($a{Name});
  $s->Type($a{Type});
  $s->ICodeBase($a{ICodeBase});
  $s->PackageDependencies({});
  if ($a{Type} eq "FRDCSA") {
    $s->Modules
      (PerlLib::Collection->new
       (Type => "Task1::Module"));
    $s->Modules->Contents({});
    $s->DistributionDependencies({});
    $s->DistributionDependencies2({});
    $s->InstallInfo({});
  } elsif ($a{Type} eq "CPAN") {
    $s->CPANObj($a{CPANObj});
  }
  $s->SPrint;
}

sub SPrint {
  my ($s,%a) = @_;
  print Dumper({
		Name => $s->Name,
		Type => $s->Type,
		ICodeBase => $s->ICodeBase,
	       });
}

sub PrintModules {
  my ($s,%a) = @_;
  print Dumper($s->DistributionDependencies);
}


1;


