export ARCHS = arm64 arm64e
export DEBUG = 0
export FINALPACKAGE = 1

export PREFIX = $(THEOS)/toolchain/Xcode11.xctoolchain/usr/bin/

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
