ARCHS = arm64 arm64e
DEBUG = 0
FINALPACKAGE = 1

TARGET = iphone:clang:latest:11.0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Bakgrunnur

Bakgrunnur_FILES = $(wildcard *.xm)
Bakgrunnur_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += bkg
SUBPROJECTS += bakgrunnurprefs
SUBPROJECTS += bakgrunnurcc
SUBPROJECTS += bkgd
include $(THEOS_MAKE_PATH)/aggregate.mk
