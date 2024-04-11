################################################################################
#
# uvc-gadget
#
################################################################################

UVC_GADGET_VERSION = v0.4.0
UVC_GADGET_SITE = https://gitlab.freedesktop.org/camera/uvc-gadget.git
UVC_GADGET_SITE_METHOD = git
UVC_GADGET_LICENSE = GPL-2.0+
UVC_GADGET_DEPENDENCIES = \
	host-pkgconf \
	jpeg \
	libcamera

$(eval $(meson-package))
