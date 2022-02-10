#!/usr/bin/perl -w

# convert a codebase from App::Module to Org::FRDCSA::App::Module

# here is what needs to be done

# develop unit tests to test the proper functionality of the software

# first, see that /usr/share/perl5/Org/FRDCSA/App exists and that
# /usr/share/perl5/App is removed

# then look at all perl files in the project, and find all instances
# of calls to App::Module.

# replace these with calls to Org::FRDCSA::App::Module

# detect all instances of Eval and also data that mentions the class,
# if possible, update the data

# to think about, if we make these changes here, they will affect the
# functioning of other frdcsa systems


