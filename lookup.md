# Walkthrough of 386BSD's Pathname Translation Code

## Contents

1. Code Flow
2. Reading Checklist
3. Important Data Structures
4. Code Walkthrough

## Code Flow

```txt
lookup
	ufs_lookup
		ufs_access
		blkatoff
		iget
		bread
			getblk
				incore
				getnewbuf
			ufs_strategy
				bmap
				spec_strategy
					wdstrategy
						disksort
```

## Reading Checklist

This section lists the relevant functions for the walkthrough by filename,
where each function per filename is listed in the order that it is called.

The first '+' means that I have read the code or have a general idea of what it does.
The second '+' means that I have read the code closely and heavily commented it.
The third '+' means that I have added it to this document's code walkthrough.

```txt
File: vfs_lookup.c
	lookup				+++

File: ufs_lookup.c
	ufs_lookup			+++
	blkatoff			++-

File: ufs_vnops.c
	ufs_access			---
	ufs_strategy		+++

File: ufs_inode.c
	iget				+++

File: vfs__bio.c
	bread				+++
	getblk				++-
	incore				++-
	getnewbuf			++-

File: vfs_subr.c
	bgetvp				++-

File: ufs_bmap.c
	bmap				++-

File: kern/spec_vnops.c
	spec_strategy		++-

File: isa/wd.c
	wdstrategy			+++

File: ufs_disksubr.c
	disksort			+--
```

## Important Data Structures

### *vnode* Structure

```c
/* From /sys/sys/vnode.h */

struct vnode {
	u_long		v_flag;			/* vnode flags (see below) */
	short		v_usecount;		/* reference count of users */
	short		v_writecount;		/* reference count of writers */
	long		v_holdcnt;		/* page & buffer references */
	off_t		v_lastr;		/* last read (read-ahead) */
	u_long		v_id;			/* capability identifier */
	struct mount	*v_mount;		/* ptr to vfs we are in */
	struct vnodeops	*v_op;			/* vnode operations */
	struct vnode	*v_freef;		/* vnode freelist forward */
	struct vnode	**v_freeb;		/* vnode freelist back */
	struct vnode	*v_mountf;		/* vnode mountlist forward */
	struct vnode	**v_mountb;		/* vnode mountlist back */
	struct buf	*v_cleanblkhd;		/* clean blocklist head */
	struct buf	*v_dirtyblkhd;		/* dirty blocklist head */
	long		v_numoutput;		/* num of writes in progress */
	enum vtype	v_type;			/* vnode type */
	union {
		struct mount	*vu_mountedhere;/* ptr to mounted vfs (VDIR) */
		struct socket	*vu_socket;	/* unix ipc (VSOCK) */
		caddr_t		vu_vmdata;	/* private data for vm (VREG) */
		struct specinfo	*vu_specinfo;	/* device (VCHR, VBLK) */
		struct fifoinfo	*vu_fifoinfo;	/* fifo (VFIFO) */
	} v_un;
	enum vtagtype	v_tag;			/* type of underlying data */
	char v_data[VN_MAXPRIVATE];		/* private data for fs */
};
#define	v_mountedhere	v_un.vu_mountedhere
#define	v_socket	v_un.vu_socket
#define	v_vmdata	v_un.vu_vmdata
#define	v_specinfo	v_un.vu_specinfo
#define	v_fifoinfo	v_un.vu_fifoinfo
```

### *mount* Structure

```c
/*
 * Structure per mounted file system.
 * Each mounted file system has an array of
 * operations and an instance record.
 * The file systems are put on a doubly linked list.
 */
struct mount {
	struct mount	*mnt_next;		/* next in mount list */
	struct mount	*mnt_prev;		/* prev in mount list */
	struct vfsops	*mnt_op;		/* operations on fs */
	struct vnode	*mnt_vnodecovered;	/* vnode we mounted on */
	struct vnode	*mnt_mounth;		/* list of vnodes this mount */
	int		mnt_flag;		/* flags */
	uid_t		mnt_exroot;		/* exported mapping for uid 0 */
	struct statfs	mnt_stat;		/* cache of filesystem stats */
	qaddr_t		mnt_data;		/* private data */
};
```

### *buf* Structures

```c
/* From /sys/sys/buf.h */

/*
 * Bufhd structures used at the head of the hashed buffer queues.
 * We only need three words for these, so this abbreviated
 * definition saves some space.
 */
struct bufhd
{
	long	b_flags;				/* see defines below */
	struct	buf *b_forw, *b_back;	/* fwd/bkwd pointer in chain */
};

struct buf
{
	long	b_flags;		/* too much goes here to describe */
	struct	buf *b_forw, *b_back;	/* hash chain (2 way street) */
	struct	buf *av_forw, *av_back;	/* position on free list if not BUSY */
	struct	buf *b_blockf, **b_blockb;/* associated vnode */
#define	b_actf	av_forw			/* alternate names for driver queue */
#define	b_actl	av_back			/*    head - isn't history wonderful */
	long	b_bcount;		/* transfer count */
	long	b_bufsize;		/* size of allocated buffer */
#define	b_active b_bcount		/* driver queue head: drive active */
	short	b_error;		/* returned after I/O */
	dev_t	b_dev;			/* major+minor device name */
	union {
	    caddr_t b_addr;		/* low order core address */
	    int	*b_words;		/* words for clearing */
	    struct fs *b_fs;		/* superblocks */
	    struct csum *b_cs;		/* superblock summary information */
	    struct cg *b_cg;		/* cylinder group block */
	    struct dinode *b_dino;	/* ilist */
	    daddr_t *b_daddr;		/* indirect block */
	} b_un;
	daddr_t	b_lblkno;		/* logical block number */
	daddr_t	b_blkno;		/* block # on device */
	long	b_resid;		/* words not transferred after error */
#define	b_errcnt b_resid		/* while i/o in progress: # retries */
	struct  proc *b_proc;		/* proc doing physical or swap I/O */
	int	(*b_iodone)();		/* function called by iodone */
	struct	vnode *b_vp;		/* vnode for dev */
	int	b_pfcent;		/* center page when swapping cluster */
	struct	ucred *b_rcred;		/* ref to read credentials */
	struct	ucred *b_wcred;		/* ref to write credendtials */
	int	b_dirtyoff;		/* offset in buffer of dirty region */
	int	b_dirtyend;		/* offset of end of dirty region */
	caddr_t	b_saveaddr;		/* original b_addr for PHYSIO */
};
```

### *inode* Structure

```c
/* From /sys/ufs/inode.h */

/*
 * The inode is used to describe each active (or recently active)
 * file in the UFS filesystem. It is composed of two types of
 * information. The first part is the information that is needed
 * only while the file is active (such as the identity of the file
 * and linkage to speed its lookup). The second part is the 
 * permannent meta-data associated with the file which is read
 * in from the permanent dinode from long term storage when the
 * file becomes active, and is put back when the file is no longer
 * being used.
 */
struct inode {
	struct	inode *i_chain[2]; /* hash chain, MUST be first */
	struct	vnode *i_vnode;	/* vnode associated with this inode */
	struct	vnode *i_devvp;	/* vnode for block I/O */
	u_long	i_flag;		/* see below */
	dev_t	i_dev;		/* device where inode resides */
	ino_t	i_number;	/* the identity of the inode */
	struct	fs *i_fs;	/* filesystem associated with this inode */
	struct	dquot *i_dquot[MAXQUOTAS]; /* pointer to dquot structures */
	struct	lockf *i_lockf;	/* head of byte-level lock list */
	long	i_diroff;	/* offset in dir, where we found last entry */
	off_t	i_endoff;	/* end of useful stuff in directory */
	long	i_spare0;
	long	i_spare1;
	struct	dinode i_din;	/* the on-disk dinode */
};

#define	i_mode		i_din.di_mode
#define	i_nlink		i_din.di_nlink
#define	i_uid		i_din.di_uid
#define	i_gid		i_din.di_gid
#if BYTE_ORDER == LITTLE_ENDIAN || defined(tahoe) /* ugh! -- must be fixed */
#define	i_size		i_din.di_qsize.val[0]
#else /* BYTE_ORDER == BIG_ENDIAN */
#define	i_size		i_din.di_qsize.val[1]
#endif
#define	i_db		i_din.di_db
#define	i_ib		i_din.di_ib
#define	i_atime		i_din.di_atime
#define	i_mtime		i_din.di_mtime
#define	i_ctime		i_din.di_ctime
#define i_blocks	i_din.di_blocks
#define	i_rdev		i_din.di_db[0]
#define i_flags		i_din.di_flags
#define i_gen		i_din.di_gen
#define	i_forw		i_chain[0]
#define	i_back		i_chain[1]
```

### *fs* Structure

```c
/*
 * Super block for a file system.
 */
#define	FS_MAGIC	0x011954
#define	FSOKAY		0x7c269d38
struct	fs
{
	struct	fs *fs_link;		/* linked list of file systems */
	struct	fs *fs_rlink;		/*     used for incore super blocks */
	daddr_t	fs_sblkno;		/* addr of super-block in filesys */
	daddr_t	fs_cblkno;		/* offset of cyl-block in filesys */
	daddr_t	fs_iblkno;		/* offset of inode-blocks in filesys */
	daddr_t	fs_dblkno;		/* offset of first data after cg */
	long	fs_cgoffset;		/* cylinder group offset in cylinder */
	long	fs_cgmask;		/* used to calc mod fs_ntrak */
	time_t 	fs_time;    		/* last time written */
	long	fs_size;		/* number of blocks in fs */
	long	fs_dsize;		/* number of data blocks in fs */
	long	fs_ncg;			/* number of cylinder groups */
	long	fs_bsize;		/* size of basic blocks in fs */
	long	fs_fsize;		/* size of frag blocks in fs */
	long	fs_frag;		/* number of frags in a block in fs */
/* these are configuration parameters */
	long	fs_minfree;		/* minimum percentage of free blocks */
	long	fs_rotdelay;		/* num of ms for optimal next block */
	long	fs_rps;			/* disk revolutions per second */
/* these fields can be computed from the others */
	long	fs_bmask;		/* ``blkoff'' calc of blk offsets */
	long	fs_fmask;		/* ``fragoff'' calc of frag offsets */
	long	fs_bshift;		/* ``lblkno'' calc of logical blkno */
	long	fs_fshift;		/* ``numfrags'' calc number of frags */
/* these are configuration parameters */
	long	fs_maxcontig;		/* max number of contiguous blks */
	long	fs_maxbpg;		/* max number of blks per cyl group */
/* these fields can be computed from the others */
	long	fs_fragshift;		/* block to frag shift */
	long	fs_fsbtodb;		/* fsbtodb and dbtofsb shift constant */
	long	fs_sbsize;		/* actual size of super block */
	long	fs_csmask;		/* csum block offset */
	long	fs_csshift;		/* csum block number */
	long	fs_nindir;		/* value of NINDIR */
	long	fs_inopb;		/* value of INOPB */
	long	fs_nspf;		/* value of NSPF */
/* yet another configuration parameter */
	long	fs_optim;		/* optimization preference, see below */
/* these fields are derived from the hardware */
	long	fs_npsect;		/* # sectors/track including spares */
	long	fs_interleave;		/* hardware sector interleave */
	long	fs_trackskew;		/* sector 0 skew, per track */
	long	fs_headswitch;		/* head switch time, usec */
	long	fs_trkseek;		/* track-to-track seek, usec */
/* sizes determined by number of cylinder groups and their sizes */
	daddr_t fs_csaddr;		/* blk addr of cyl grp summary area */
	long	fs_cssize;		/* size of cyl grp summary area */
	long	fs_cgsize;		/* cylinder group size */
/* these fields are derived from the hardware */
	long	fs_ntrak;		/* tracks per cylinder */
	long	fs_nsect;		/* sectors per track */
	long  	fs_spc;   		/* sectors per cylinder */
/* this comes from the disk driver partitioning */
	long	fs_ncyl;   		/* cylinders in file system */
/* these fields can be computed from the others */
	long	fs_cpg;			/* cylinders per group */
	long	fs_ipg;			/* inodes per group */
	long	fs_fpg;			/* blocks per group * fs_frag */
/* this data must be re-computed after crashes */
	struct	csum fs_cstotal;	/* cylinder summary information */
/* these fields are cleared at mount time */
	char   	fs_fmod;    		/* super block modified flag */
	char   	fs_clean;    		/* file system is clean flag */
	char   	fs_ronly;   		/* mounted read-only flag */
	char   	fs_flags;   		/* currently unused flag */
	char	fs_fsmnt[MAXMNTLEN];	/* name mounted on */
/* these fields retain the current block allocation info */
	long	fs_cgrotor;		/* last cg searched */
	struct	csum *fs_csp[MAXCSBUFS];/* list of fs_cs info buffers */
	long	fs_cpc;			/* cyl per cycle in postbl */
	short	fs_opostbl[16][8];	/* old rotation block list head */
	long	fs_sparecon[55];	/* reserved for future constants */
	long	fs_state;		/* validate fs_clean field */
	quad	fs_qbmask;		/* ~fs_bmask - for use with quad size */
	quad	fs_qfmask;		/* ~fs_fmask - for use with quad size */
	long	fs_postblformat;	/* format of positional layout tables */
	long	fs_nrpos;		/* number of rotaional positions */
	long	fs_postbloff;		/* (short) rotation block list head */
	long	fs_rotbloff;		/* (u_char) blocks for each rotation */
	long	fs_magic;		/* magic number */
	u_char	fs_space[1];		/* list of blocks for each rotation */
/* actually longer */
};
```

### *disk* Structure

```c
/*
 * The structure of a disk drive.
 */
struct	disk {
	long	dk_bc;		/* byte count left */
	short	dk_skip;	/* blocks already transferred */
	char	dk_unit;	/* physical unit number */
	char	dk_state;	/* control state */
	u_char	dk_status;	/* copy of status reg. */
	u_char	dk_error;	/* copy of error reg. */
	short	dk_port;	/* i/o port base */
	
        u_long  dk_copenpart;   /* character units open on this drive */
        u_long  dk_bopenpart;   /* block units open on this drive */
        u_long  dk_openpart;    /* all units open on this drive */
	short	dk_wlabel;	/* label writable? */
	short	dk_flags;	/* drive characteistics found */
#define	DKFL_DOSPART	0x00001	 /* has DOS partition table */
#define	DKFL_QUIET	0x00002	 /* report errors back, but don't complain */
#define	DKFL_SINGLE	0x00004	 /* sector at a time mode */
#define	DKFL_ERROR	0x00008	 /* processing a disk error */
#define	DKFL_BSDLABEL	0x00010	 /* has a BSD disk label */
#define	DKFL_BADSECT	0x00020	 /* has a bad144 badsector table */
#define	DKFL_WRITEPROT	0x00040	 /* manual unit write protect */
	struct wdparams dk_params; /* ESDI/IDE drive/controller parameters */
	struct disklabel dk_dd;	/* device configuration data */
	struct	dos_partition
		dk_dospartitions[NDOSPART];	/* DOS view of disk */
	struct	dkbad	dk_bad;	/* bad sector table */
};

```

### *bdevsw* Structure

```c
/* From /sys/i386/i386/conf.c */

struct bdevsw	bdevsw[] =
{
	{ wdopen,	wdclose,	wdstrategy,	wdioctl,	/*0*/
	  wddump,	wdsize,		NULL },
	{ enodev,	enodev,		swstrategy,	enodev,		/*1*/
	  enodev,	enodev,		NULL },
	{ Fdopen,	fdclose,	fdstrategy,	fdioctl,	/*2*/
	  fddump,	fdsize,		NULL },
	{ wtopen,	wtclose,	wtstrategy,	wtioctl,	/*3*/
	  wtdump,	wtsize,		B_TAPE },
	{ asopen,	asclose,	asstrategy,	asioctl,	/*4*/
	  asdump,	assize,		NULL },
};
```

## Code Walkthrough

### Pseudo Code Walkthrough

**lookup**:

**ufs_lookup**:

**blkatoff**;

**bread**:

**getblk**:

**ufs_strategy**:

**bmap**:

**spec_strategy**:

### Documented Code

```c
/*
 * Search a pathname.
 * This is a very central and rather complicated routine.
 *
 * The pathname is pointed to by ni_ptr and is of length ni_pathlen.
 * The starting directory is taken from ni_startdir. The pathname is
 * descended until done, or a symbolic link is encountered. The variable
 * ni_more is clear if the path is completed; it is set to one if a
 * symbolic link needing interpretation is encountered.
 *
 * The flag argument is LOOKUP, CREATE, RENAME, or DELETE depending on
 * whether the name is to be looked up, created, renamed, or deleted.
 * When CREATE, RENAME, or DELETE is specified, information usable in
 * creating, renaming, or deleting a directory entry may be calculated.
 * If flag has LOCKPARENT or'ed into it, the parent directory is returned
 * locked. If flag has WANTPARENT or'ed into it, the parent directory is
 * returned unlocked. Otherwise the parent directory is not returned. If
 * the target of the pathname exists and LOCKLEAF is or'ed into the flag
 * the target is returned locked, otherwise it is returned unlocked.
 * When creating or renaming and LOCKPARENT is specified, the target may not
 * be ".".  When deleting and LOCKPARENT is specified, the target may be ".".
 * NOTE: (LOOKUP | LOCKPARENT) currently returns the parent vnode unlocked.
 * 
 * Overall outline of lookup:
 *
 * dirloop:
 *	identify next component of name at ndp->ni_ptr
 *	handle degenerate case where name is null string
 *	if .. and crossing mount points and on mounted filesys, find parent
 *	call VOP_LOOKUP routine for next component name
 *	    directory vnode returned in ni_dvp, unlocked unless LOCKPARENT set
 *	    component vnode returned in ni_vp (if it exists), locked.
 *	if result vnode is mounted on and crossing mount points,
 *	    find mounted on vnode
 *	if more components of name, do next level at dirloop
 *	return the answer in ni_vp, locked if LOCKLEAF set
 *	    if LOCKPARENT set, return locked parent in ni_dvp
 *	    if WANTPARENT set, return unlocked parent in ni_dvp
 */
lookup(ndp, p)
	register struct nameidata *ndp;
	struct proc *p;
{
	register char *cp;				/* pointer into pathname argument */
	register struct vnode *dp = 0;	/* the directory we are searching */
	struct vnode *tdp;				/* saved dp */
	struct mount *mp;				/* mount table entry */
	int docache;					/* == 0 do not cache last component */
	int flag;						/* LOOKUP, CREATE, RENAME or DELETE */
	int wantparent;					/* 1 => wantparent or lockparent flag */
	int rdonly;						/* mounted read-only flag bit(s) */
	int error = 0;

	/*
	 * Setup: break out flag bits into variables.
	 */
	flag = ndp->ni_nameiop & OPMASK;
	wantparent = ndp->ni_nameiop & (LOCKPARENT|WANTPARENT);
	docache = (ndp->ni_nameiop & NOCACHE) ^ NOCACHE;
	if (flag == DELETE || (wantparent && flag != CREATE))
		docache = 0;
	rdonly = MNT_RDONLY;
	if (ndp->ni_nameiop & REMOTE)
		rdonly |= MNT_EXRDONLY;
	ndp->ni_dvp = NULL;
	ndp->ni_more = 0;
	dp = ndp->ni_startdir;
	ndp->ni_startdir = NULLVP;
	VOP_LOCK(dp);

dirloop:
	/*
	 * Search a new directory.
	 *
	 * The ni_hash value is for use by vfs_cache.
	 * The last component of the filename is left accessible via
	 * ndp->ptr for callers that need the name. Callers needing
	 * the name set the SAVENAME flag. When done, they assume
	 * responsibility for freeing the pathname buffer.
	 */
	ndp->ni_hash = 0;

	/* Obtain the length of the next component */
	for (cp = ndp->ni_ptr; *cp != 0 && *cp != '/'; cp++)
		ndp->ni_hash += (unsigned char)*cp;
	ndp->ni_namelen = cp - ndp->ni_ptr;

	/* Handle component name that is too large */
	if (ndp->ni_namelen >= NAME_MAX) {
		error = ENAMETOOLONG;
		goto bad;
	}

	/* Decr component length from pathname len */
	ndp->ni_pathlen -= ndp->ni_namelen;

	/* Set the ptr to the next component */
	ndp->ni_next = cp;
	ndp->ni_makeentry = 1;

	if (*cp == '\0' && docache == 0)
		ndp->ni_makeentry = 0;

	/* Is the component the parent dir? */
	ndp->ni_isdotdot = (ndp->ni_namelen == 2 &&
		ndp->ni_ptr[1] == '.' && ndp->ni_ptr[0] == '.');
	/*
	 * Check for degenerate name (e.g. / or "")
	 * which is a way of talking about a directory,
	 * e.g. like "/." or ".".
	 */
	if (ndp->ni_ptr[0] == '\0') {
		/* Cannot RENAME, CREATE, or DELETE an empty pathname */
		if (flag != LOOKUP || wantparent) {
			error = EISDIR;
			goto bad;
		}
		if (dp->v_type != VDIR) {
			error = ENOTDIR;
			goto bad;
		}
		/* Unlock the leaf node if necessary */
		if (!(ndp->ni_nameiop & LOCKLEAF))
			VOP_UNLOCK(dp);
		ndp->ni_vp = dp;
		if (ndp->ni_nameiop & SAVESTART)
			panic("lookup: SAVESTART");
		return (0);
	}
	/*
	 * Handle "..": two special cases.
	 * 1. If at root directory (e.g. after chroot)
	 *    then ignore it so can't get out.
	 * 2. If this vnode is the root of a mounted
	 *    filesystem, then replace it with the
	 *    vnode which was mounted on so we take the
	 *    .. in the other file system.
	 */
	if (ndp->ni_isdotdot) {
		for (;;) {
			/*  chrooted root dir  || absolute root dir */
			if (dp == ndp->ni_rootdir || dp == rootdir) {
				ndp->ni_dvp = dp;
				ndp->ni_vp = dp;
				VREF(dp);
				goto nextname;
			}

			/* Break if dp is not a root dir or we set NOCROSSMOUNT */
			if ((dp->v_flag & VROOT) == 0 ||
			    (ndp->ni_nameiop & NOCROSSMOUNT))
				break;

			/* Save current dir ptr */
			tdp = dp;

			/* Obtain the vnode of the filesystem we are mounted on. */
			dp = dp->v_mount->mnt_vnodecovered;
			vput(tdp);

			/* Acquire a reference and lock on the mountpoint vnode */
			VREF(dp);
			VOP_LOCK(dp);
		}
	}
	/*
	 * We now have a segment name to search for, and a directory to search.
	 * 
	 * Call ufs_lookup to obtain the vnode of the component.
	 */
	if (error = VOP_LOOKUP(dp, ndp, p)) {
	/*
	 * We make it inside the loop if ufs_lookup did not a vnode.
	 */
		if (flag == LOOKUP || flag == DELETE ||
		    error != ENOENT || *cp != 0)
			goto bad;
		/*
		 * If creating and at end of pathname, then can consider
		 * allowing file to be created.
		 */
		if (ndp->ni_dvp->v_mount->mnt_flag & rdonly) {
			error = EROFS;
			goto bad;
		}
		/*
		 * We return with ni_vp NULL to indicate that the entry
		 * doesn't currently exist, leaving a pointer to the
		 * (possibly locked) directory inode in ndp->ni_dvp.
		 */
		if (ndp->ni_nameiop & SAVESTART) {
			ndp->ni_startdir = ndp->ni_dvp;
			VREF(ndp->ni_startdir);
		}
		return (0);
	}
	/*
	 * We make it here if ufs_lookup found the vnode of the component.
	 */
	dp = ndp->ni_vp;
	/*
	 * Check for symbolic link. Set ni_more and return 0 if the vnode
	 * we just found is a sym link.
	 */
	if ((dp->v_type == VLNK) &&
	    ((ndp->ni_nameiop & FOLLOW) || *ndp->ni_next == '/')) {
		ndp->ni_more = 1;
		return (0);
	}
	/*
	 * Check to see if the vnode has been mounted on;
	 * if so find the root of the mounted file system.
	 */
mntloop:
	while (dp->v_type == VDIR && (mp = dp->v_mountedhere) &&
	       (ndp->ni_nameiop & NOCROSSMOUNT) == 0)
	{
		while(mp->mnt_flag & MNT_MLOCK) {
			mp->mnt_flag |= MNT_MWAIT;
			sleep((caddr_t)mp, PVFS);
			goto mntloop;
		}
		/*
		 * Call VFS_ROOT to obtain the root of the mounted
		 * filesystem.
		 */
		if (error = VFS_ROOT(dp->v_mountedhere, &tdp))
			goto bad2;
		vput(dp);
		ndp->ni_vp = dp = tdp;
	}

nextname:
	/*
	 * Not a symbolic link.  If more pathname,
	 * continue at next component, else return.
	 */
	if (*ndp->ni_next == '/') {
		ndp->ni_ptr = ndp->ni_next;
		while (*ndp->ni_ptr == '/') {
			ndp->ni_ptr++;
			ndp->ni_pathlen--;
		}
		vrele(ndp->ni_dvp);
		goto dirloop;
	}
	/*
	 * Check for read-only file systems.
	 */
	if (flag == DELETE || flag == RENAME) {
		/*
		 * Disallow directory write attempts on read-only
		 * file systems.
		 */
		if ((dp->v_mount->mnt_flag & rdonly) ||
		    (wantparent && (ndp->ni_dvp->v_mount->mnt_flag & rdonly))) {
			error = EROFS;
			goto bad2;
		}
	}
	/* Save the parent dir ptr for SAVESTART */
	if (ndp->ni_nameiop & SAVESTART) {
		ndp->ni_startdir = ndp->ni_dvp;
		VREF(ndp->ni_startdir);
	}
	if (!wantparent)
		vrele(ndp->ni_dvp);
	if ((ndp->ni_nameiop & LOCKLEAF) == 0)
		VOP_UNLOCK(dp);
	return (0);

bad2:
	if ((ndp->ni_nameiop & LOCKPARENT) && *ndp->ni_next == '\0')
		VOP_UNLOCK(ndp->ni_dvp);
	vrele(ndp->ni_dvp);
bad:
	vput(dp);
	ndp->ni_vp = NULL;
	return (error);
}

/*
 * Convert a component of a pathname into a pointer to a locked inode.
 * This is a very central and rather complicated routine.
 * If the file system is not maintained in a strict tree hierarchy,
 * this can result in a deadlock situation (see comments in code below).
 *
 * The flag argument is LOOKUP, CREATE, RENAME, or DELETE depending on
 * whether the name is to be looked up, created, renamed, or deleted.
 * When CREATE, RENAME, or DELETE is specified, information usable in
 * creating, renaming, or deleting a directory entry may be calculated.
 * If flag has LOCKPARENT or'ed into it and the target of the pathname
 * exists, lookup returns both the target and its parent directory locked.
 * When creating or renaming and LOCKPARENT is specified, the target may
 * not be ".".  When deleting and LOCKPARENT is specified, the target may
 * be "."., but the caller must check to ensure it does an vrele and iput
 * instead of two iputs.
 *
 * Overall outline of ufs_lookup:
 *
 *	check accessibility of directory
 *	look for name in cache, if found, then if at end of path
 *	  and deleting or creating, drop it, else return name
 *	search for name in directory, to found or notfound
 * notfound:
 *	if creating, return locked directory, leaving info on available slots
 *	else return error
 * found:
 *	if at end of path and deleting, return information to allow delete
 *	if at end of path and rewriting (RENAME and LOCKPARENT), lock target
 *	  inode and return info to allow rewrite
 *	if not at end, add name to cache; if at end and neither creating
 *	  nor deleting, add name to cache
 *
 * NOTE: (LOOKUP | LOCKPARENT) currently returns the parent inode unlocked.
 */
ufs_lookup(vdp, ndp, p)
	register struct vnode *vdp;
	register struct nameidata *ndp;
	struct proc *p;
{
	register struct inode *dp;	/* the directory we are searching */
	register struct fs *fs;		/* file system that directory is in */
	struct buf *bp = 0;			/* a buffer of directory entries */
	register struct direct *ep;	/* the current directory entry */
	int entryoffsetinblock;		/* offset of ep in bp's buffer */
	enum {NONE, COMPACT, FOUND} slotstatus;
	int slotoffset = -1;		/* offset of area with free space */
	int slotsize;				/* size of area at slotoffset */
	int slotfreespace;			/* amount of space free in slot */
	int slotneeded;				/* size of the entry we're seeking */
	int numdirpasses;			/* strategy for directory search */
	int endsearch;				/* offset to end directory search */
	int prevoff;				/* ndp->ni_ufs.ufs_offset of previous entry */
	struct inode *pdp;			/* saved dp during symlink work */
	struct inode *tdp;			/* returned by iget */
	off_t enduseful;			/* pointer past last used dir slot */
	int flag;					/* LOOKUP, CREATE, RENAME, or DELETE */
	int lockparent;				/* 1 => lockparent flag is set */
	int wantparent;				/* 1 => wantparent or lockparent flag */
	int error;

	ndp->ni_dvp = vdp;
	ndp->ni_vp = NULL;

	/* VTOI(vp)	:= ((struct inode *)(vp)->v_data) */
	dp = VTOI(vdp);
	fs = dp->i_fs;
	lockparent = ndp->ni_nameiop & LOCKPARENT;
	flag = ndp->ni_nameiop & OPMASK;
	wantparent = ndp->ni_nameiop & (LOCKPARENT|WANTPARENT);

	/*
	 * Check accessiblity of directory.
	 *
	 * i_mode refers to the disk inode's mode and type of file.
	 */
	if ((dp->i_mode&IFMT) != IFDIR)
		return (ENOTDIR);

	/* Call ufs_access to obtain the permissions of the file */
	if (error = ufs_access(vdp, VEXEC, ndp->ni_cred, p))
		return (error);

	/*
	 * We now have a segment name to search for, and a directory to search.
	 *
	 * Before tediously performing a linear scan of the directory,
	 * check the name cache to see if the directory/name pair
	 * we are looking for is known already.
	 *
	 * We will skip the cache lookup case for now and focus on the ufs code.
	 */
	if (error = cache_lookup(ndp)) {
		int vpid;	/* capability number of vnode */

		if (error == ENOENT)
			return (error);
#ifdef PARANOID
		if (vdp == ndp->ni_rdir && ndp->ni_isdotdot)
			panic("ufs_lookup: .. through root");
#endif
		/*
		 * Get the next vnode in the path.
		 * See comment below starting `Step through' for
		 * an explaination of the locking protocol.
		 */
		pdp = dp;
		dp = VTOI(ndp->ni_vp);
		vdp = ndp->ni_vp;
		vpid = vdp->v_id;
		if (pdp == dp) {
			VREF(vdp);
			error = 0;
		} else if (ndp->ni_isdotdot) {
			IUNLOCK(pdp);
			error = vget(vdp);
			if (!error && lockparent && *ndp->ni_next == '\0')
				ILOCK(pdp);
		} else {
			error = vget(vdp);
			if (!lockparent || error || *ndp->ni_next != '\0')
				IUNLOCK(pdp);
		}
		/*
		 * Check that the capability number did not change
		 * while we were waiting for the lock.
		 */
		if (!error) {
			if (vpid == vdp->v_id)
				return (0);
			iput(dp);
			if (lockparent && pdp != dp && *ndp->ni_next == '\0')
				IUNLOCK(pdp);
		}
		ILOCK(pdp);
		dp = pdp;
		vdp = ITOV(dp);
		ndp->ni_vp = NULL;
	}
	/*
	 * Suppress search for slots unless creating
	 * file and at end of pathname, in which case
	 * we watch for a place to put the new file in
	 * case it doesn't already exist.
	 */
	slotstatus = FOUND;

	/*
	 * If the namei op is CREATE or RENAME and there is no other
	 * component to translate, we search for a slot to store the 
	 * newly created/renamed file in the directory.
	 */
	if ((flag == CREATE || flag == RENAME) && *ndp->ni_next == 0) {
		slotstatus = NONE;
		slotfreespace = 0;
		slotneeded = ((sizeof (struct direct) - (MAXNAMLEN + 1)) +
			((ndp->ni_namelen + 1 + 3) &~ 3));
	}
	/*
	 * If there is cached information on a previous search of
	 * this directory, pick up where we last left off.
	 * We cache only lookups as these are the most common
	 * and have the greatest payoff. Caching CREATE has little
	 * benefit as it usually must search the entire directory
	 * to determine that the entry does not exist. Caching the
	 * location of the last DELETE or RENAME has not reduced
	 * profiling time and hence has been removed in the interest
	 * of simplicity.
	 *
	 * NOTE: ufs_offset is the offset of free space in a directory
	 * that is saved from previous searches.
	 */
	if (flag != LOOKUP || dp->i_diroff == 0 || dp->i_diroff > dp->i_size) {
		ndp->ni_ufs.ufs_offset = 0;

		/* Only need to pass through once if we start at beg */
		numdirpasses = 1;
	} else {
		ndp->ni_ufs.ufs_offset = dp->i_diroff;

		/* blkoff(fs,loc) ((loc) & ~(fs)->fs_bmask) */
		entryoffsetinblock = blkoff(fs, ndp->ni_ufs.ufs_offset);

		/*
		 * Returns a buffer with the contents of the block at the
		 * offset.
		 */
		if (entryoffsetinblock != 0) {
			if (error = blkatoff(dp, ndp->ni_ufs.ufs_offset,
			    (char **)0, &bp))
				return (error);
		}
		/* Pass through twice since we start at the offset */
		numdirpasses = 2;
		nchstats.ncs_2passes++;
	}
	endsearch = roundup(dp->i_size, DIRBLKSIZ);
	enduseful = 0;

searchloop:
	while (ndp->ni_ufs.ufs_offset < endsearch) {
		/*
		 * If offset is on a block boundary,
		 * read the next directory block.
		 * Release previous if it exists.
		 */
		if (blkoff(fs, ndp->ni_ufs.ufs_offset) == 0) {
			/* Free the buffer */
			if (bp != NULL)
				brelse(bp);

			/* Read in the next dir block */
			if (error = blkatoff(dp, ndp->ni_ufs.ufs_offset,
			    (char **)0, &bp))
				return (error);

			/* Reset the offset */
			entryoffsetinblock = 0;
		}
		/*
		 * If still looking for a slot, and at a DIRBLKSIZE
		 * boundary, have to start looking for free space again.
		 */
		if (slotstatus == NONE &&
		    (entryoffsetinblock & (DIRBLKSIZ - 1)) == 0) {
			slotoffset = -1;
			slotfreespace = 0;
		}
		/*
		 * Get pointer to next entry.
		 * Full validation checks are slow, so we only check
		 * enough to insure forward progress through the
		 * directory. Complete checks can be run by patching
		 * "dirchk" to be true.
		 */
		ep = (struct direct *)(bp->b_un.b_addr + entryoffsetinblock);

		/*
		 * If the dir entry is invalid and mangled, call dirbad and
		 * increment offset to the next dir entry.
		 */
		if (ep->d_reclen == 0 ||
		    dirchk && dirbadentry(ep, entryoffsetinblock)) {
			int i;

			dirbad(dp, ndp->ni_ufs.ufs_offset, "mangled entry");
			i = DIRBLKSIZ - (entryoffsetinblock & (DIRBLKSIZ - 1));
			ndp->ni_ufs.ufs_offset += i;
			entryoffsetinblock += i;
			continue;
		}

		/*
		 * If an appropriate sized slot has not yet been found,
		 * check to see if one is available. Also accumulate space
		 * in the current block so that we can determine if
		 * compaction is viable.
		 */
		if (slotstatus != FOUND) {
			int size = ep->d_reclen;

			/* Decr free space if entry is used */
			if (ep->d_ino != 0)
				size -= DIRSIZ(ep);

			/*
			 * If there is free space in the directory block,
			 * determine whether its large enough for a new
			 * entry before and after compaction.
			 */
			if (size > 0) {
				if (size >= slotneeded) {
					slotstatus = FOUND;
					slotoffset = ndp->ni_ufs.ufs_offset;
					slotsize = ep->d_reclen;
				} else if (slotstatus == NONE) {
					/* Incr free space in dir block */
					slotfreespace += size;
					/* Set ptr to free space if isn't set */
					if (slotoffset == -1)
						slotoffset =
						      ndp->ni_ufs.ufs_offset;
					/*
					 * Set slotstatus to COMPACT and rearrange
					 * entries later.
					 */
					if (slotfreespace >= slotneeded) {
						slotstatus = COMPACT;
						slotsize =
						      ndp->ni_ufs.ufs_offset +
						      ep->d_reclen - slotoffset;
					}
				}
			}
		}

		/*
		 * Check for a name match.
		 */
		if (ep->d_ino) {
			if (ep->d_namlen == ndp->ni_namelen &&
			    !bcmp(ndp->ni_ptr, ep->d_name,
				(unsigned)ep->d_namlen)) {
				/*
				 * Save directory entry's inode number and
				 * reclen in ndp->ni_ufs area, and release
				 * directory buffer.
				 */
				ndp->ni_ufs.ufs_ino = ep->d_ino;
				ndp->ni_ufs.ufs_reclen = ep->d_reclen;
				goto found;
			}
		}
		prevoff = ndp->ni_ufs.ufs_offset;
		ndp->ni_ufs.ufs_offset += ep->d_reclen;
		entryoffsetinblock += ep->d_reclen;
		if (ep->d_ino)
			enduseful = ndp->ni_ufs.ufs_offset;
	}
/* notfound: */
	/*
	 * If we started in the middle of the directory and failed
	 * to find our target, we must check the beginning as well.
	 */
	if (numdirpasses == 2) {
		numdirpasses--;
		ndp->ni_ufs.ufs_offset = 0;
		endsearch = dp->i_diroff;
		goto searchloop;
	}
	if (bp != NULL)
		brelse(bp);
	/*
	 * If creating, and at end of pathname and current
	 * directory has not been removed, then can consider
	 * allowing file to be created.
	 */
	if ((flag == CREATE || flag == RENAME) &&
	    *ndp->ni_next == 0 && dp->i_nlink != 0) {
		/*
		 * Access for write is interpreted as allowing
		 * creation of files in the directory.
		 */
		if (error = ufs_access(vdp, VWRITE, ndp->ni_cred, p))
			return (error);
		/*
		 * Return an indication of where the new directory
		 * entry should be put.  If we didn't find a slot,
		 * then set ndp->ni_ufs.ufs_count to 0 indicating
		 * that the new slot belongs at the end of the
		 * directory. If we found a slot, then the new entry
		 * can be put in the range from ndp->ni_ufs.ufs_offset
		 * to ndp->ni_ufs.ufs_offset + ndp->ni_ufs.ufs_count.
		 */
		if (slotstatus == NONE) {
			ndp->ni_ufs.ufs_offset = roundup(dp->i_size, DIRBLKSIZ);
			ndp->ni_ufs.ufs_count = 0;
			enduseful = ndp->ni_ufs.ufs_offset;
		} else {
			ndp->ni_ufs.ufs_offset = slotoffset;
			ndp->ni_ufs.ufs_count = slotsize;
			if (enduseful < slotoffset + slotsize)
				enduseful = slotoffset + slotsize;
		}
		ndp->ni_ufs.ufs_endoff = roundup(enduseful, DIRBLKSIZ);
		dp->i_flag |= IUPD|ICHG;
		/*
		 * We return with the directory locked, so that
		 * the parameters we set up above will still be
		 * valid if we actually decide to do a direnter().
		 * We return ni_vp == NULL to indicate that the entry
		 * does not currently exist; we leave a pointer to
		 * the (locked) directory inode in ndp->ni_dvp.
		 * The pathname buffer is saved so that the name
		 * can be obtained later.
		 *
		 * NB - if the directory is unlocked, then this
		 * information cannot be used.
		 */
		ndp->ni_nameiop |= SAVENAME;
		if (!lockparent)
			IUNLOCK(dp);
	}
	/*
	 * Insert name into cache (as non-existent) if appropriate.
	 */
	if (ndp->ni_makeentry && flag != CREATE)
		cache_enter(ndp);
	return (ENOENT);

found:
	if (numdirpasses == 2)
		nchstats.ncs_pass2++;
	/*
	 * Check that directory length properly reflects presence
	 * of this entry.
	 */
	if (entryoffsetinblock + DIRSIZ(ep) > dp->i_size) {
		dirbad(dp, ndp->ni_ufs.ufs_offset, "i_size too small");
		dp->i_size = entryoffsetinblock + DIRSIZ(ep);
		dp->i_flag |= IUPD|ICHG;
	}

	/* Release the dir block now that we found the entry */
	brelse(bp);

	/*
	 * Found component in pathname.
	 * If the final component of path name, save information
	 * in the cache as to where the entry was found.
	 */
	if (*ndp->ni_next == '\0' && flag == LOOKUP)
		dp->i_diroff = ndp->ni_ufs.ufs_offset &~ (DIRBLKSIZ - 1);

	/*
	 * If deleting, and at end of pathname, return
	 * parameters which can be used to remove file.
	 * If the wantparent flag isn't set, we return only
	 * the directory (in ndp->ni_dvp), otherwise we go
	 * on and lock the inode, being careful with ".".
	 */
	if (flag == DELETE && *ndp->ni_next == 0) {
		/*
		 * Write access to directory required to delete files.
		 */
		if (error = ufs_access(vdp, VWRITE, ndp->ni_cred, p))
			return (error);
		/*
		 * Return pointer to current entry in ndp->ni_ufs.ufs_offset,
		 * and distance past previous entry (if there
		 * is a previous entry in this block) in ndp->ni_ufs.ufs_count.
		 * Save directory inode pointer in ndp->ni_dvp for dirremove().
		 */
		if ((ndp->ni_ufs.ufs_offset&(DIRBLKSIZ-1)) == 0)
			ndp->ni_ufs.ufs_count = 0;
		else
			ndp->ni_ufs.ufs_count = ndp->ni_ufs.ufs_offset - prevoff;

		/* Handle "." case */
		if (dp->i_number == ndp->ni_ufs.ufs_ino) {
			VREF(vdp);
			ndp->ni_vp = vdp;
			return (0);
		}

		/* Call iget to obtain the inode we are about to delete */
		if (error = iget(dp, ndp->ni_ufs.ufs_ino, &tdp))
			return (error);
		/*
		 * If directory is "sticky", then user must own
		 * the directory, or the file in it, else she
		 * may not delete it (unless she's root). This
		 * implements append-only directories.
		 */
		if ((dp->i_mode & ISVTX) &&
		    ndp->ni_cred->cr_uid != 0 &&
		    ndp->ni_cred->cr_uid != dp->i_uid &&
		    tdp->i_uid != ndp->ni_cred->cr_uid) {
			iput(tdp);
			return (EPERM);
		}

		/*
		 * Assign the inode we wish to delete to ndp->ni_vp 
		 * and return.
		 */
		ndp->ni_vp = ITOV(tdp);
		if (!lockparent)
			IUNLOCK(dp);
		return (0);
	}

	/*
	 * If rewriting (RENAME), return the inode and the
	 * information required to rewrite the present directory
	 * Must get inode of directory entry to verify it's a
	 * regular file, or empty directory.
	 */
	if (flag == RENAME && wantparent && *ndp->ni_next == 0) {
		if (error = ufs_access(vdp, VWRITE, ndp->ni_cred, p))
			return (error);
		/*
		 * Careful about locking second inode.
		 * This can only occur if the target is ".".
		 */
		if (dp->i_number == ndp->ni_ufs.ufs_ino)
			return (EISDIR);

		/* Call iget to obtain the inode we wish to rename */
		if (error = iget(dp, ndp->ni_ufs.ufs_ino, &tdp))
			return (error);

		/*
		 * Assign the inode we wish to rename to ndp->ni_vp,
		 * set SAVENAME, and return.
		 */
		ndp->ni_vp = ITOV(tdp);
		ndp->ni_nameiop |= SAVENAME;
		if (!lockparent)
			IUNLOCK(dp);
		return (0);
	}

	/*
	 * Step through the translation in the name.  We do not `iput' the
	 * directory because we may need it again if a symbolic link
	 * is relative to the current directory.  Instead we save it
	 * unlocked as "pdp".  We must get the target inode before unlocking
	 * the directory to insure that the inode will not be removed
	 * before we get it.  We prevent deadlock by always fetching
	 * inodes from the root, moving down the directory tree. Thus
	 * when following backward pointers ".." we must unlock the
	 * parent directory before getting the requested directory.
	 * There is a potential race condition here if both the current
	 * and parent directories are removed before the `iget' for the
	 * inode associated with ".." returns.  We hope that this occurs
	 * infrequently since we cannot avoid this race condition without
	 * implementing a sophisticated deadlock detection algorithm.
	 * Note also that this simple deadlock detection scheme will not
	 * work if the file system has any hard links other than ".."
	 * that point backwards in the directory structure.
	 */
	pdp = dp;
	if (ndp->ni_isdotdot) {
		IUNLOCK(pdp);	/* race to get the inode */

		/* Call iget to obtain the inode of the parent dir */
		if (error = iget(dp, ndp->ni_ufs.ufs_ino, &tdp)) {
			ILOCK(pdp);
			return (error);
		}
		if (lockparent && *ndp->ni_next == '\0')
			ILOCK(pdp);

		/* Assign the inode of the parent dir to ndp->ni_vp */
		ndp->ni_vp = ITOV(tdp);
	} /* "." case */
	  else if (dp->i_number == ndp->ni_ufs.ufs_ino) {
		VREF(vdp);	/* we want ourself, ie "." */
		ndp->ni_vp = vdp;
	} /* Successful lookup */
	  else {
		/* Call iget to obtain the inode of the file we looked up */
		if (error = iget(dp, ndp->ni_ufs.ufs_ino, &tdp))
			return (error);
		if (!lockparent || *ndp->ni_next != '\0')
			IUNLOCK(pdp);

		/* Assign the inode to ndp->ni_vp */
		ndp->ni_vp = ITOV(tdp);
	}

	/*
	 * Insert name into cache if appropriate.
	 */
	if (ndp->ni_makeentry)
		cache_enter(ndp);
	return (0);
}



/*
 * Find the block in the buffer pool.
 * If the buffer is not present, allocate a new buffer and load
 * its contents according to the filesystem fill routine.
 */
int
bread(struct vnode *vp, daddr_t blkno, int size, struct ucred *cred,
	struct buf **bpp)
{
	struct buf *bp;
	int rv = 0;
	/*
	 * Obtain a buffer. If the buffer was in the cache,
	 * its size can be >= the size we ask for.
	 */
	bp = getblk (vp, blkno, size);

	/* if not found in cache, do some I/O */
	if ((bp->b_flags & B_CACHE) == 0 || (bp->b_flags & B_INVAL) != 0) {
		bp->b_flags |= B_READ;
		bp->b_flags &= ~(B_DONE|B_ERROR|B_INVAL);
		if (cred != NOCRED) crhold(cred);
		bp->b_rcred = cred;

		/* Calls ufs_strategy to complete i/o */
		VOP_STRATEGY(bp);
		rv = biowait (bp);
	}
	*bpp = bp;
	
	return (rv);
}

/*
 * Calculate the logical to physical mapping if not done already,
 * then call the device strategy routine.
 */
int checkoverlap = 0;

ufs_strategy(bp)
	register struct buf *bp;
{
	register struct inode *ip = VTOI(bp->b_vp);
	struct vnode *vp;
	int error;

	/* Why is a vnode of type VBLK a panic? */
	if (bp->b_vp->v_type == VBLK || bp->b_vp->v_type == VCHR)
		panic("ufs_strategy: spec");
	/*
	 * These variables are set to the same value in getblk
	 * for a non-cached buffer. It simply means we need to
	 * obtain the actual block number on the disk with bmap.
	 */
	if (bp->b_blkno == bp->b_lblkno) {
		if (error = bmap(ip, bp->b_lblkno, &bp->b_blkno))
			return (error);
		if ((long)bp->b_blkno == -1)
			clrbuf(bp);
	}
	/* Block was not found on the disk */
	if ((long)bp->b_blkno == -1) {
		biodone(bp);
		return (0);
	}
#ifdef DIAGNOSTIC
	if (checkoverlap) {
		register struct buf *ep;
		struct buf *ebp;
		daddr_t start, last;

		ebp = &buf[nbuf];
		start = bp->b_blkno;
		last = start + btodb(bp->b_bcount) - 1;
		for (ep = buf; ep < ebp; ep++) {
			if (ep == bp || (ep->b_flags & B_INVAL) ||
			    ep->b_vp == NULLVP)
				continue;
			if (VOP_BMAP(ep->b_vp, (daddr_t)0, &vp, (daddr_t)0))
				continue;
			if (vp != ip->i_devvp)
				continue;
			/* look for overlap */
			if (ep->b_bcount == 0 || ep->b_blkno > last ||
			    ep->b_blkno + btodb(ep->b_bcount) <= start)
				continue;
			vprint("Disk overlap", vp);
			printf("\tstart %d, end %d overlap start %d, end %d\n",
				start, last, ep->b_blkno,
				ep->b_blkno + btodb(ep->b_bcount) - 1);
			panic("Disk buffer overlap");
		}
	}
#endif /* DIAGNOSTIC */
	vp = ip->i_devvp;
	/* v_rdev := v_un.vu_specinfo->si_rde */
	bp->b_dev = vp->v_rdev;
	(*(vp->v_op->vop_strategy))(bp);
	return (0);
}

/* Read/write routine for a buffer.  Finds the proper unit, range checks
 * arguments, and schedules the transfer.  Does not wait for the transfer
 * to complete.  Multi-page transfers are supported.  All I/O requests must
 * be a multiple of a sector in length.
 */
int
wdstrategy(register struct buf *bp)
{
	register struct buf *dp;
	struct disklabel *lp;
	register struct partition *p;
	struct disk *du;	/* Disk unit to do the IO.	*/
	long maxsz, sz;
	int	unit = wdunit(bp->b_dev);
	int	s;

	/* valid unit, controller, and request?  */
	if (unit > NWD || bp->b_blkno < 0 || (du = wddrives[unit]) == 0) {
		bp->b_error = EINVAL;
		bp->b_flags |= B_ERROR;
		goto done;
	}

	/*
	 * "soft" write protect check 
	 *
	 * Checks the disk's flags for write protection and the buf's flags
	 * for B_WRITE indirectly.
	 */
	if ((du->dk_flags & DKFL_WRITEPROT) && (bp->b_flags & B_READ) == 0) {
		bp->b_error = EROFS;
		bp->b_flags |= B_ERROR;
		goto done;
	}

	/*
	 * have partitions and want to use them? 
	 *
	 * If the disk drive contains a BSD disk label and wdpart does not
	 * return WDRAW, which means that this block is NOT a partition,
	 * we need to make sure that this i/o operation will not overwrite
	 * the disklabel or any of its partitions.
	 */
	if ((du->dk_flags & DKFL_BSDLABEL) != 0 && wdpart(bp->b_dev) != WDRAW) {
		/*
		 * do bounds checking, adjust transfer. if error, process.
		 * if end of partition, just return
		 */
		if (bounds_check_with_label(bp, &du->dk_dd, du->dk_wlabel) <= 0)
			goto done;
		/* otherwise, process transfer request */
	}

q:
	/* queue transfer on drive, activate drive and controller if idle */
	dp = &wdutab[unit];
	s = splbio();
	disksort(dp, bp);
	if (dp->b_active == 0)
		wdustart(du);		/* start drive */
	if (wdtab.b_active == 0)
		wdstart(s);		/* start controller */
	splx(s);
	return;

done:
	/* toss transfer, we're done early */
	biodone(bp);
}
```
