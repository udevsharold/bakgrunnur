ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BakgrunnurPrefs

BakgrunnurPrefs_FILES = $(wildcard *.m) ../BKGShared.mm
BakgrunnurPrefs_INSTALL_PATH = /Library/PreferenceBundles
BakgrunnurPrefs_FRAMEWORKS = UIKit
BakgrunnurPrefs_PRIVATE_FRAMEWORKS = Preferences
BakgrunnurPrefs_EXTRA_FRAMEWORKS = AltList
BakgrunnurPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/BakgrunnurPrefs.plist$(ECHO_END)
