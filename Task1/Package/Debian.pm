package Task1::Package::Debian;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw /  /

  ];

sub init {
  my ($s,%a) = @_;
}

Source: clear
Section: unknown
Priority: optional
Maintainer: Andrew J. Dougherty <ajd@frdcsa.org>
Build-Depends: debhelper (>= 4.0.0)
Standards-Version: 3.6.0

Package: clear
Architecture: any
Depends: ${shlibs:Depends}, ${misc:Depends}, boss, ccp,
 libhtml-linkextractor-perl, libwebfs-filecopy-perl,
 liblwp-version-perl, rss
Description: Cognitive LEarning ARchitecture
 Tracks belief in which documents the user has read so that the
 computer has another modality, in addition to things like expected
 background knowledge, apparent knowledge, to model which axioms the
 user is familiar with.  By modelling the reading flux, a much better
 mental model can be created and the system can behave contingently.


1;
