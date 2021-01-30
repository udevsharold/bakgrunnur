ARCHS = arm64 arm64e

TARGET := iphone:clang:latest:7.0


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BakgrunnurPM

BakgrunnurPM_FILES = $(wildcard *.xm)
BakgrunnurPM_CFLAGS = -fobjc-arc
BakgrunnurPM_PRIVATE_FRAMEWORKS = IOKit

include $(THEOS_MAKE_PATH)/tweak.mk
