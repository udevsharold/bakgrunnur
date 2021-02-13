export XCODE_12_SLICE ?= 0
ifeq ($(XCODE_12_SLICE), 1)
	export ARCHS = arm64e
else
	export ARCHS = arm64 arm64e
	export PREFIX = $(THEOS)/toolchain/Xcode11.xctoolchain/usr/bin/
endif

TARGET := iphone:clang:latest:7.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = bkgd

bkgd_FILES = $(wildcard *.mm)
bkgd_CFLAGS = -fobjc-arc
bkgd_CODESIGN_FLAGS = -Sentitlements.plist
bkgd_INSTALL_PATH = /usr/libexec
bkgd_PRIVATE_FRAMEWORKS = IOKit

include $(THEOS_MAKE_PATH)/tool.mk
