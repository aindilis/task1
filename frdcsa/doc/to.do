(create myfrdcsa-base package)
(fix Exporter being called libexporter-perl instead of perl-base)

(find out why mini-dinstall is taking forever
 (something needs to be changed in the config file to expedite it)
 )
(find out how to know when to rebuild a package)
(find out how to know when to remove the orig file and the debian dir)

(some of the things I want
 (generate a mega package (myfrdcsa-complete) which contains all
 the files that the FRDCSA really needs.) 
 )

http://svn.donarmstrong.com/don/trunk/home_modules/development/.pbuilder_hooks/

(the uml machines should go into packager)

dput -f -c ~/dput.cf -u local clear_0.4-1_i386.changes

(find/create list of packages that need to be created)