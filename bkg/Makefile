ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TOOL_NAME = bkg

bkg_FILES = main.mm
bkg_CFLAGS = -fobjc-arc
bkg_CODESIGN_FLAGS = -Sent.xml

include $(THEOS_MAKE_PATH)/tool.mk
