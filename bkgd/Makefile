ARCHS = arm64 arm64e

TARGET := iphone:clang:14.5:7.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = bkgd

bkgd_FILES = $(wildcard *.mm)
bkgd_CFLAGS = -fobjc-arc
bkgd_CODESIGN_FLAGS = -Sentitlements.plist
bkgd_INSTALL_PATH = /usr/libexec
bkgd_PRIVATE_FRAMEWORKS = IOKit

include $(THEOS_MAKE_PATH)/tool.mk
