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

# Deterministic NPU self-test model, prebuilt from the generator scripts (see npu-test/README).
ifeq ($(BR2_PACKAGE_RKNN_RUNTIME_NPU_TEST_MODEL),y)
ifeq ($(BR2_PACKAGE_RKNN_RUNTIME_TEST_RK3588),y)
RKNN_RUNTIME_MODEL_SOC = RK3588
else
RKNN_RUNTIME_MODEL_SOC = RK3566_RK3568
endif

RKNN_RUNTIME_NPU_TEST_DIR = $(RKNN_RUNTIME_PKGDIR)/npu-test

define RKNN_RUNTIME_INSTALL_NPU_TEST_MODEL
	$(INSTALL) -D -m 0644 \
		$(RKNN_RUNTIME_NPU_TEST_DIR)/$(RKNN_RUNTIME_MODEL_SOC)/npu_test.rknn \
		$(TARGET_DIR)/usr/share/rknn/models/npu_test.rknn
	$(INSTALL) -D -m 0644 $(RKNN_RUNTIME_NPU_TEST_DIR)/npu_test_input.bin \
		$(TARGET_DIR)/usr/share/rknn/test/npu_test_input.bin
	$(INSTALL) -D -m 0644 $(RKNN_RUNTIME_NPU_TEST_DIR)/npu_test_expected.bin \
		$(TARGET_DIR)/usr/share/rknn/test/npu_test_expected.bin
endef
RKNN_RUNTIME_POST_INSTALL_TARGET_HOOKS += RKNN_RUNTIME_INSTALL_NPU_TEST_MODEL
endif

$(eval $(generic-package))
