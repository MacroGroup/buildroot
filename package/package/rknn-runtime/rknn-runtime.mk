################################################################################
#
# rknn-runtime
#
################################################################################

RKNN_RUNTIME_VERSION = 1.6.0
RKNN_RUNTIME_SITE = $(call github,airockchip,rknn-toolkit2,v$(RKNN_RUNTIME_VERSION))
RKNN_RUNTIME_LICENSE = Proprietary
RKNN_RUNTIME_REDISTRIBUTE = NO
RKNN_RUNTIME_INSTALL_STAGING = YES

RKNN_RUNTIME_SDK_SUBDIR = rknpu2/runtime/Linux/librknn_api

# Prebuilt runtime: no configure or build commands are needed.
define RKNN_RUNTIME_INSTALL_STAGING_CMDS
	$(INSTALL) -D -m 0755 \
		$(@D)/$(RKNN_RUNTIME_SDK_SUBDIR)/aarch64/librknnrt.so \
		$(STAGING_DIR)/usr/lib/librknnrt.so
	$(INSTALL) -d $(STAGING_DIR)/usr/include
	$(INSTALL) -m 0644 $(@D)/$(RKNN_RUNTIME_SDK_SUBDIR)/include/*.h \
		$(STAGING_DIR)/usr/include/
endef

define RKNN_RUNTIME_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 \
		$(@D)/$(RKNN_RUNTIME_SDK_SUBDIR)/aarch64/librknnrt.so \
		$(TARGET_DIR)/usr/lib/librknnrt.so
endef

$(eval $(generic-package))
