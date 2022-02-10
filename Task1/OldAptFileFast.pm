package Task1::AptFileFast;

use Manager::Dialog qw(ApproveCommands);
use PerlLib::MySQL;

use Data::Dumper;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw / MyMySQL /

  ];

sub init {
  my ($s,%a) = @_;
  $s->MyMySQL
    (PerlLib::MySQL->new
     (DBName => "apt_file_fast"));
}

sub Update {
  my ($s,%a) = @_;
  # delete everything from the database
  ApproveCommands(Commands => ["sudo apt-file update"]);
  $s->MyMySQL->Do
    (Statement => "delete from contents");
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
  my @statements;
  foreach my $line (split /\n/, $c) {
    if ($line =~  /^(.*?)\s+(\S+)$/) {
      my ($a,$b) = ($1,$2);
      push @statements,
	"insert into contents values (".
	  $s->MyMySQL->Quote($a).",".
	    $s->MyMySQL->Quote($b).");";
    }
  }
  $s->MyMySQL->Do
    (Statement => join("\n",@statements));
}

sub Search {
  my ($s,%a) = @_;
  my $statement = "select * from contents where filename like '%$a{Search}%'";
  print $statement."\n";
  my $res = $s->MyMySQL->Do
    (
     Statement => $statement,
     KeyField => "filename",
    );
  # now let's line up the options
  if (scalar keys %$res > 250) {
    print "To many results\n";
  } else {
    foreach my $item (keys %$res) {
      # $res->{$item}->{package};
    }
  }
}

1;
