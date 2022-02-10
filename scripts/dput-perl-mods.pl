#!/usr/bin/perl -w

my $dir1 = "/var/tmp/debaux-root";
foreach my $dir (split /\n/, `ls $dir1`) {
  foreach my $file (split /\n/,`ls $dir1/$dir/*.changes`) {
    $file =~ s|.*/||;
    chdir "$dir1/$dir";
    my $c = "dput -f -c /var/lib/myfrdcsa/codebases/internal/task1/conf-files/dput.cf local $file\n";
    print "$c\n";
    system $c;
  }
}
