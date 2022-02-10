package Task1::File;

use Data::Dumper;
use File::Stat;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw / Name Contents /

  ];

sub init {
  my ($s,%a) = @_;
  $s->Name($a{Name});
  $s->Contents($a{Contents});
}

sub Save {
  my ($s,%a) = @_;
  my $OUT;
  my $fn = $s->Name;
  # first check to see if the contents of the existing file are any different
  if (-f $fn) {
    my $data = `cat "$fn"`;
    if ($data ne $s->Contents) {
      $s->Write;
    } else {
      print "No change.\n";
    }
  } else {
    $s->Write;
  }
}

sub Write {
  my ($s,%a) = @_;
  my $fn = $s->Name;
  if (open(OUT,">$fn")) {
    print OUT $s->Contents;
    close OUT;
  } else {
    print "Cannot save this file: $fn\n";
  }
}

sub Print {
  my ($s,%a) = @_;
  my $marker = ("-"x80)."\n";
  print $marker.$s->Name."\n".$marker.$s->Contents."\n".$marker;
}

sub LastModified {
  my ($s,%a) = @_;
  my $stat = File::Stat->new
    ($s->Name);
  return $stat->mtime;
}

1;
