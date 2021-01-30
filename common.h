#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
#include <HBLog.h>

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
