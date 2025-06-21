PORTNAME=	safirbu
DISTVERSION=	0.20
#PORTREVISION=	# Port/Makefile version

# As long as the program has beta status this is the version given for dist packages.
#ISCVERSION=	${DISTVERSION}${DISTVERSIONSUFFIX}

CATEGORIES=	sysutils
MASTER_SITES=	https://github.com/DomAsProgrammer/${PORTNAME}/
#MASTER_SITES=	${MASTER_SITE_GH}
#DISTNAME=	${PORTNAME} # Shall not be overwritten. By BSDoc 5.4.1
EXTRACT_SUFX=	.tar.xz
MAINTAINER=	domasprogrammer@gmail.com
COMMENT=	Solution for Automatic Full Incremental Remote Backup on Unix
WWW=		https://github.com/DomAsProgrammer/${PORTNAME}/
#DISTFILES=	# Use to name the tarball if not assambled correctly.

LICENSE=	LICENCE.md
LICENSE_NAME=	'SAFIRBU Licence'
LICENSE_PERMS=	no-dist-mirror no-dist-sell no-pkg-mirror no-pkg-sell no-auto-accept
LICENSE_FILE=	${WRKSRC}/LICENCE.md
PORTSCOUT=	site:https://github.com/DomAsProgrammer/

RUN_DEPENDS=	rsync:net/rsync

# System apps
#RUN_DEPENDS=	find
#RUN_DEPENDS=	wc
#RUN_DEPENDS=	du
#RUN_DEPENDS=	ssh

BUILD_DEPENDS=	perl5
BUILD_DEPENDS=	bash:shells/bash
USES=		gmake

NO_TEST=	true

IS_INTERACTIVE=	no
#WRKSRC=		${DISTNAME}-${DISTVERSION}${DISTVERSIONSUFFIX}
GNU_CONFIGURE=	no
HAS_CONFIGURE=	yes
# ${WRKDIR} means a working directory of Ports
# ${WRKSRC} means a directory within ${WRKDIR} where the package was really extracted to. (The directory, contained within the original tarball.
# ${STAGEDIR} aliases $RPM_BUILD_ROOT

do-configure:
	( cd ${WRKSRC} && ./configure -b -i ${STAGEDIR} )

pre-build:
	( cd ${WRKSRC} && ./s/Bootstrap.sh )

do-build:
	( cd ${WRKSRC} && ${MAKE_CMD} build )

pre-install:
	rm -rf ${STAGEDIR}
	# Expected folders from base installation
	install -d ${STAGEDIR}/usr/local/sbin
	install -d ${STAGEDIR}/usr/local/etc/logrotate.d
	install -d ${STAGEDIR}/usr/local/etc/bash_completion.d
	install -d ${STAGEDIR}/usr/local/share/man/man5/
	install -d ${STAGEDIR}/usr/local/share/man/man8/

do-install:
	( cd ${WRKSRC} && ${MAKE_CMD} install )

post-install:
	# Sample files
	mv ${STAGEDIR}/usr/local/etc/safirbu/config ${STAGEDIR}/usr/local/etc/safirbu/config.sample
	mv ${STAGEDIR}/usr/local/etc/logrotate.d/safirbu ${STAGEDIR}/usr/local/etc/logrotate.d/safirbu.sample
	install -d -m 0644 ${STAGEDIR}/usr/local/share/licenses/safirbu
	install -m 0444 ${WRKSRC}/LICENCE.md ${STAGEDIR}/usr/local/share/licenses/safirbu/LICENCE.md
	xz -d ${STAGEDIR}/usr/local/share/man/man5/safirbu-config.5.xz
	gzip -9 ${STAGEDIR}/usr/local/share/man/man5/safirbu-config.5
	xz -d ${STAGEDIR}/usr/local/share/man/man8/safirbu.8.xz
	gzip -9 ${STAGEDIR}/usr/local/share/man/man8/safirbu.8

.include <bsd.port.mk>
