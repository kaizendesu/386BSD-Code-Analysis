# Generated automatically from Makefile.in by configure.
# Makefile for GNU CVS documentation.
# Do not use this makefile directly, but only from `../Makefile'.
# Copyright (C) 1986-1992 Free Software Foundation, Inc.

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

SHELL = /bin/sh

srcdir = .


MAN1FILES = cvs.1 mkmodules.1
MAN5FILES = cvs.5
MANFILES = $(MAN1FILES) $(MAN5FILES)

DISTFILES = Makefile.in $(MANFILES)
INSTALL = install -c
INSTALL_DATA = $(INSTALL)
mandir = $(prefix)/man
man1dir = $(mandir)/man1
man5dir = $(mandir)/man5

all:
.PHONY: all

install: all
	for f in $(MAN1FILES); do \
		$(INSTALL_DATA) $(srcdir)/$$f $(man1dir)/$$f; \
	done
	for f in $(MAN5FILES); do \
		$(INSTALL_DATA) $(srcdir)/$$f $(man5dir)/$$f; \
	done
.PHONY: install

tags:
.PHONY: tags

TAGS:
.PHONY: TAGS

ls:
	@true
.PHONY: ls

clean:
.PHONY: clean

distclean: clean
	rm -f Makefile
.PHONY: distclean

realclean: distclean
.PHONY: realclean

dist:
	ln $(DISTFILES) ../`cat ../.fname`/man
.PHONY: dist
