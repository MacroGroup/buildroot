################################################################################
#
# libusbgx
#
################################################################################

LIBUSBGX_GIT_VERSION = a5bfa81017a9b2064bc449cf74f5f9d106445f62
LIBUSBGX_GIT_SITE = https://github.com/linux-usb-gadgets/libusbgx.git
LIBUSBGX_GIT_SITE_METHOD = git
LIBUSBGX_GIT_LICENSE = GPL-2.0+ (examples), LGPL-2.1+ (library)
LIBUSBGX_GIT_LICENSE_FILES = COPYING COPYING.LGPL
LIBUSBGX_GIT_DEPENDENCIES = host-pkgconf libconfig
LIBUSBGX_GIT_AUTORECONF = YES
LIBUSBGX_GIT_INSTALL_STAGING = YES

$(eval $(autotools-package))
