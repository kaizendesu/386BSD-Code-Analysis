# Generated automatically from Makefile.in by configure.
# Master Makefile for the GNU file utilities.
# Copyright (C) 1990, 1991, 1992 Free Software Foundation, Inc.

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

#### Start of system configuration section. ####

srcdir = .


# If you use gcc, you should either run the fixincludes script that
# comes with it or else use gcc with the -traditional option.  Otherwise
# ioctl calls will be compiled incorrectly on some systems.
CC = gcc -O
AR = ar
# Set RANLIB = echo if your system doesn't have or need ranlib.
RANLIB = ranlib 

# Things you might add to DEFS:
# -DSTDC_HEADERS	If you have ANSI C headers and libraries.
# -DHAVE_UNISTD_H	If you have unistd.h.
# -DHAVE_LIMITS_H	If you have limits.h, but not all ANSI C headers.
# -DUSG			If you have System V/ANSI C string and
#			memory functions and headers, ndir.h,
#			sys/sysmacros.h, no sys/times.h, fcntl.h,
#			getcwd.
# -DSIGTYPE=int		If your signal handlers return int, not void.
# -DDIRENT		If you have dirent.h.
# -DSYSNDIR		Old Xenix systems (selects sys/ndir.h).
# -DVOID_CLOSEDIR	If your closedir function returns void, not int.
# -DMAJOR_IN_MKDEV	If major, minor, makedev defined in sys/mkdev.h.
# -DMAJOR_IN_SYSMACROS	If major, minor, makedev defined in sys/sysmacros.h.
# -DINT_16_BITS		If sizeof long > sizeof int.
# -DSTRERROR_MISSING	If you lack strerror function.
# -DVPRINTF_MISSING	If you lack vprintf function (but have _doprnt).
# -DDOPRNT_MISSING	If you lack _doprnt function.  Also need to define
#			-DVPRINTF_MISSING.
# -DMKFIFO_MISSING	If you lack mkfifo system call, but have FIFOs.
# -DFTRUNCATE_MISSING	If you lack ftruncate system call.
# -DFCHMOD_MISSING	If you lack fchmod system call.
# -DMVDIR=\"$(libdir)/mvdir\"
#			If you lack rename system call.
# -DST_BLOCKS_MISSING	If your `struct stat' lacks st_blocks and st_blksize.
# -DUTIME_NULL_MISSING	If your utime system call does not use the
#			current time when passed a null time pointer.
# -DNEED_TZSET		If you lack ftime system call and
#			need to call tzset to set the timezone.
# Define zero or one of the following; you need one to compile df.
# The numbers after STATFS are the number of args it's passed.
# See lib/fsusage.c for more details.
# STAT_STATFS2_BSIZE	4.3BSD, SunOS 4, HP-UX.
# STAT_STATFS2_FSIZE	4.4BSD.
# STAT_STATFS2_FS_DATA	Ultrix.
# STAT_READ		SVR2.
# STAT_STATFS4		SVR3, Dynix, Irix.
# STAT_STATVFS		SVR4.
# Define zero or one of the following; you need one to compile df.
# The numbers after GETMNTENT are the number of args it's passed.
# See lib/mountlist.c for more details.
# MOUNTED_GETMNTENT1	4.3BSD, SunOS 4, HP-UX, Dynix, Irix.
# MOUNTED_GETMNTINFO	4.4BSD.
# MOUNTED_GETMNT	Ultrix.
# MOUNTED_FREAD		SVR2.
# MOUNTED_FREAD_FSTYP	SVR3.
# MOUNTED_GETMNTENT2	SVR4.

DEFS =  -DHAVE_LIMITS_H -DDIRENT -DMOUNTED_GETMNTINFO -DSTAT_STATFS2_FSIZE -DSTDC_HEADERS -DHAVE_UNISTD_H -DFTIME_MISSING -DUTIME_NULL_MISSING
LIBS = 
LIBPROGS = 

CDEBUG = -g
CFLAGS = $(CDEBUG) -I. -I../lib -I$(srcdir)/lib $(DEFS)
LDFLAGS = -g

prefix = /usr/src/public/fileutils-3.2
# Prefix for each installed program, normally empty or `g'.
binprefix = 
# Prefix for each installed man page, normally empty or `g'.
manprefix = 

# Where to install the executables.
bindir = $(prefix)/bin

# Where to put mvdir, if your system lacks the rename system call.
libdir = $(prefix)/lib

# Where to put the manual pages.
mandir = $(prefix)/man/man1
# Extension (not including `.') for the installed manual page filenames.
manext = 1

#### End of system configuration section. ####

MDEFINES = bindir='$(bindir)' libdir='$(libdir)' mandir='$(mandir)' \
manext='$(manext)' binprefix='$(binprefix)' manprefix='$(manprefix)' \
LIBS='$(LIBS)' LIBPROGS='$(LIBPROGS)' AR='$(AR)' RANLIB='$(RANLIB)' \
CFLAGS='$(CFLAGS)' LDFLAGS='$(LDFLAGS)' LIBS='$(LIBS)' CC='$(CC)'

DISTFILES = COPYING COPYING.LIB ChangeLog Makefile.in README configure \
configure.in 

# Redundant stuff for making only selected programs.
PROGS = chgrp chown chmod cp dd du ginstall ln dir vdir ls mkdir \
mkfifo mknod mv rm rmdir touch  df

# Subdirectories to run make in for the primary targets.
SUBDIRS = lib src man

all:
	for dir in $(SUBDIRS); do echo making $@ in $$dir; cd $$dir; $(MAKE) $(MDEFINES) $@; cd ..; done
.PHONY: all

$(PROGS):
	cd lib; $(MAKE) $(MDEFINES) all
	cd src; $(MAKE) $(MDEFINES) $@

install:
	for dir in $(SUBDIRS); do echo making $@ in $$dir; cd $$dir; $(MAKE) $(MDEFINES) $@; cd ..; done
.PHONY: install

tags:
	for dir in $(SUBDIRS); do echo making $@ in $$dir; cd $$dir; $(MAKE) $(MDEFINES) $@; cd ..; done
.PHONY: tags

TAGS:
	for dir in $(SUBDIRS); do echo making $@ in $$dir; cd $$dir; $(MAKE) $(MDEFINES) $@; cd ..; done
.PHONY: TAGS

mostlyclean:
	for dir in $(SUBDIRS); do echo making $@ in $$dir; cd $$dir; $(MAKE) $(MDEFINES) $@; cd ..; done
.PHONY: mostlyclean

clean:
	for dir in $(SUBDIRS); do echo making $@ in $$dir; cd $$dir; $(MAKE) $(MDEFINES) $@; cd ..; done
	rm -f Makefile config.status
.PHONY: clean

realclean:
	for dir in $(SUBDIRS); do echo making $@ in $$dir; cd $$dir; $(MAKE) $(MDEFINES) $@; cd ..; done
	rm -f Makefile config.status
.PHONY: realclean

dist:
	echo fileutils-`sed -e '/version_string/!d' -e 's/[^0-9.]*\([0-9.]*\).*/\1/' -e q src/version.c` > .fname
	rm -rf `cat .fname`
	mkdir `cat .fname`
	ln $(DISTFILES) `cat .fname`
	for dir in $(SUBDIRS); do mkdir `cat .fname`/$$dir; cd $$dir; $(MAKE) $@; cd ..; done
	tar chZf `cat .fname`.tar.Z `cat .fname`
	rm -rf `cat .fname` .fname
