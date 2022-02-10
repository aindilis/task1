#!/usr/bin/make -f

SYSNAME=task1

configure: configure-stamp

configure-stamp:
	touch configure-stamp

build: build-stamp

build-stamp: configure-stamp 
	touch build-stamp

clean:
	(find . | grep '~$$' | xargs rm) || true
	rm *-stamp

etags:
	find . | grep -E '(pm|pl)$$' | etags -

install:


.PHONY: build clean install configure
