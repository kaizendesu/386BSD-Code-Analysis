#	@(#)Makefile	5.15 (Berkeley) 6/29/90

PROG=	fsck
MAN8=	fsck.0
SRCS=	dir.c inode.c main.c pass1.c pass1b.c pass2.c pass3.c pass4.c \
	pass5.c preen.c setup.c utilities.c ufs_subr.c ufs_tables.c
.PATH:	${.CURDIR}/../../sys.386bsd/ufs

.include <bsd.prog.mk>
