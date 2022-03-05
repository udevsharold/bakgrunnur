#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <HBLog.h>

//#if defined(__IPHONE_14_0) || defined(__MAC_10_16) || defined(__TVOS_14_0) || defined(__WATCHOS_7_0)
//#define OBJC_DIRECT_MEMBERS __attribute__((objc_direct_members))
//#define OBJC_DIRECT __attribute__((objc_direct))
//#define DIRECT ,direct
//#else
//#define OBJC_DIRECT_MEMBERS
//#define OBJC_DIRECT
//#define DIRECT
//#endif


#define BAKGRUNNUR_IDENTIFIER @"com.udevs.bakgrunnur"
#define PREFS_CHANGED_NOTIFICATION_NAME @"com.udevs.bakgrunnur.prefschanged"
#define CLI_REQUEST_NOTIFICATION_NAME @"com.udevs.bakgrunnur.cli"
#define PREFS_PATH @"/var/mobile/Library/Preferences/com.udevs.bakgrunnur.plist"

#define REFRESH_MODULE_NOTIFICATION_NAME @"com.udevs.bakgrunnur/refreshmodule"
#define RELOAD_SPECIFIERS_NOTIFICATION_NAME @"com.udevs.bakgrunnur.reloadspecifiers"
#define RELOAD_SPECIFIERS_LOCAL_NOTIFICATION_NAME @"com.udevs.bakgrunnur.reloadspecifiers.local"

#define RESET_ALL_NOTIFICATION_NAME @"com.udevs.bakgrunnur.reloadspecifiers.reset"

#define SIMULATE_HOME_BUTTON_PRESS_NOTIFICATION_NAME @"com.udevs.bakgrunnur.homebutton.press"

#define POWERD_XPC_NAME "com.apple.iokit.powerdxpc"

#define PRERMING_NOTIFICATION_NAME @"com.udevs.bakgrunnur-prerming"

#define defaultExpirationTime 10800 // 3hours

/*
Cycript:
cy# @import FrontBoardServices
cy# extern "C" NSString *FBSApplicationTerminationReasonDescription(NSUInteger)
cy# FBSApplicationTerminationReasonDescription(0)
*/

typedef NS_ENUM(NSUInteger, FBSTerminationReason) {
    FBSTerminationReasonNone,
    FBSTerminationReasonUserInitiated,
    FBSTerminationReasonPuring,
    FBSTerminationReasonThermalIssue,
    FBSTerminationReasonNonSpecific,
    FBSTerminationReasonShutDownSystem,
    FBSTerminationReasonLaunchTest,
    FBSTerminationReasonInsecureDrawing,
    FBSTerminationReasonLogOut,
    FBSTerminationReasonUnknown
};

typedef NS_ENUM(NSUInteger, BKGBackgroundType) {
    BKGBackgroundTypeTerminate = 0,
    BKGBackgroundTypeRetire,
    BKGBackgroundTypeImmortal,
    BKGBackgroundTypeAdvanced
};

typedef NS_ENUM(NSInteger, BKGCCModuleAction) {
	BKGCCModuleActionDefault = -1,
	BKGCCModuleActionExpandModule = BKGCCModuleActionDefault,
	BKGCCModuleActionOpenAppSettings = 0,
	BKGCCModuleActionEnableApp,
	BKGCCModuleActionDisableApp,
	BKGCCModuleActionToggleApp,
	BKGCCModuleActionEnableAppOnce,
	BKGCCModuleActionDisableAppOnce,
	BKGCCModuleActionToggleAppOnce,
	BKGCCModuleActionEnable,
	BKGCCModuleActionDisable,
	BKGCCModuleActionToggle,
	BKGCCModuleActionDoNothing
};
