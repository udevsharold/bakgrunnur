export DEBUG = 0
export FINALPACKAGE = 1

export XCODE_12_SLICE ?= 0
ifeq ($(XCODE_12_SLICE), 1)
	export ARCHS = arm64e
else
	export ARCHS = arm64 arm64e
	export PREFIX = $(THEOS)/toolchain/Xcode11.xctoolchain/usr/bin/
endif

TARGET = iphone:clang:latest:11.0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Bakgrunnur

Bakgrunnur_FILES = $(wildcard *.xm) $(wildcard *.mm)
Bakgrunnur_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += bkg
SUBPROJECTS += bakgrunnurprefs
SUBPROJECTS += bakgrunnurcc
SUBPROJECTS += bkgd
include $(THEOS_MAKE_PATH)/aggregate.mk
