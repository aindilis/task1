package Task1::AptFileFast;

# Turn this into a unilang agent, move it to perllib?

use Manager::Dialog qw(ApproveCommands);

use Data::Dumper;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw / Packages Files /

  ];

sub init {
  my ($s,%a) = @_;
  $s->Packages({});
  $s->Files({});
}

sub Update {
  my ($s,%a) = @_;
  # delete everything from the database
  ApproveCommands(Commands => ["sudo apt-file update"]);
  # load in each and every file
  my $cache = "/var/cache/apt/apt-file";
  foreach my $file (split /\n/, `ls $cache`) {
    print "<$file>\n";
    $s->Parse(File => "$cache/$file");
  }
}

sub Parse {
  my ($s,%a) = @_;
  my $c = `zcat $a{File}`;
  $c =~ s/.*?FILE\s+LOCATION.*?\n//s;
  foreach my $line (split /\n/, $c) {
    if ($line =~  /^(.*?)\s+(\S+)$/) {
      my ($a,$b) = ($1,$2);
      $s->Packages->{$a}->{$b} = 1;
      $s->Files->{$b} = $a;
    }
  }
}

sub Search {
  my ($s,%a) = @_;
  # do the search here
  if (scalar keys %$res > 250) {
    print "To many results\n";
  } else {
    foreach my $item (keys %$res) {
      # $res->{$item}->{package};
    }
  }
}

1;
