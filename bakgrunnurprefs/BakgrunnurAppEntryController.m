#import "../common.h"
#include "BakgrunnurAppEntryController.h"

@implementation BakgrunnurAppEntryController

- (NSArray *)specifiers {
    if (!_specifiers) {
        
        NSMutableArray *appEntrySpecifiers = [[NSMutableArray alloc] init];
        
        //Enabled
        PSSpecifier *enabledEntryGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [enabledEntryGroupSpec setProperty:[NSString stringWithFormat:@"Allow %@ to dispatch notifications even though it is being backgrounded by Bakgrunnur.", self.title] forKey:@"footerText"];
        [appEntrySpecifiers addObject:enabledEntryGroupSpec];
        
        PSSpecifier *enabledEntrydSpec = [PSSpecifier preferenceSpecifierNamed:@"Enabled" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [enabledEntrydSpec setProperty:@"Enabled" forKey:@"label"];
        [enabledEntrydSpec setProperty:@"enabled" forKey:@"key"];
        [enabledEntrydSpec setProperty:@NO forKey:@"default"];
        [enabledEntrydSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [enabledEntrydSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [appEntrySpecifiers addObject:enabledEntrydSpec];
        
        
        //Enabled notification
        PSSpecifier *enabledAppNotificationsSpec = [PSSpecifier preferenceSpecifierNamed:@"Notifications (BETA)" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [enabledAppNotificationsSpec setProperty:@"Notifications (BETA)" forKey:@"label"];
        [enabledAppNotificationsSpec setProperty:@"enabledAppNotifications" forKey:@"key"];
        [enabledAppNotificationsSpec setProperty:@NO forKey:@"default"];
        [enabledAppNotificationsSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [enabledAppNotificationsSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [appEntrySpecifiers addObject:enabledAppNotificationsSpec];
        
        //Persistence once
        PSSpecifier *persistenceOnceGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [persistenceOnceGroupSpec setProperty:[NSString stringWithFormat:@"Keep \"Enable Once\" token for %@ alive until being forcefully terminated via app switcher. Token will be revoked whenever %@ is active again when this setting is disabled.", self.title, self.title] forKey:@"footerText"];
        [appEntrySpecifiers addObject:persistenceOnceGroupSpec];
        
        PSSpecifier *persistenceOnceSpec = [PSSpecifier preferenceSpecifierNamed:@"Persistence Once Token" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [persistenceOnceSpec setProperty:@"Persistence Once Token" forKey:@"label"];
        [persistenceOnceSpec setProperty:@"persistenceOnce" forKey:@"key"];
        [persistenceOnceSpec setProperty:@NO forKey:@"default"];
        [persistenceOnceSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [persistenceOnceSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [appEntrySpecifiers addObject:persistenceOnceSpec];
        
        //Dark wake
        PSSpecifier *darkWakeGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [darkWakeGroupSpec setProperty:[NSString stringWithFormat:@"Allow %@ to put device into half-asleep state instead of full sleep when locked. CPU, networking and disk read/write will operate at full capacity in this state. Useful when app needs full network/disk speed for background operations (files downloading, SSH etc.). By default, system will throttle/disable these capabilities when locked.", self.title] forKey:@"footerText"];
        [appEntrySpecifiers addObject:darkWakeGroupSpec];
        
        PSSpecifier *darkWakeSpec = [PSSpecifier preferenceSpecifierNamed:@"Half-asleep" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [darkWakeSpec setProperty:@"Half-asleep" forKey:@"label"];
        [darkWakeSpec setProperty:@"darkWake" forKey:@"key"];
        [darkWakeSpec setProperty:@NO forKey:@"default"];
        [darkWakeSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [darkWakeSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [appEntrySpecifiers addObject:darkWakeSpec];
        
        //expiration
        PSSpecifier *expirationGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [expirationGroupSpec setProperty:@"Set the expiration time (s) for app to be retired/terminated. The countdown will begin when the app entered background or the device is locked. It'll be reset whenever the app is in foreground or active again. Default is 3 hours." forKey:@"footerText"];
        [appEntrySpecifiers addObject:expirationGroupSpec];
        
        
        PSTextFieldSpecifier* expirationSpec = [PSTextFieldSpecifier preferenceSpecifierNamed:@"Expiration" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSEditTextCell edit:nil];
        [expirationSpec setKeyboardType:UIKeyboardTypeNumberPad autoCaps:UITextAutocapitalizationTypeNone autoCorrection:UITextAutocorrectionTypeNo];
        [expirationSpec setPlaceholder:@"10800"];
        [expirationSpec setProperty:@"expiration" forKey:@"key"];
        [expirationSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [expirationSpec setProperty:@"Expiration" forKey:@"label"];
        [expirationSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        self.expirationSpecifier = expirationSpec;
        [appEntrySpecifiers addObject:expirationSpec];
        
        //retire type
        PSSpecifier *retireSelectionGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [retireSelectionGroupSpec setProperty:@"\U00002022Retire: System will be informed to suspends app gracefully.\n\U00002022Terminate: App will be terminated immediately once it's expired.\n\U00002022Immortal: App will remains active until being forcefully terminated by user or after a respring.\n\U00002022Advanced: App will be retired according to the preferred advanced settings (CPU, system calls & network) within the specified time span." forKey:@"footerText"];
        [appEntrySpecifiers addObject:retireSelectionGroupSpec];
        
        PSSpecifier *retireSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"Retire" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSegmentCell edit:nil];
        [retireSelectionSpec setValues:@[@1, @0, @2, @3] titles:@[@"Retire", @"Terminate", @"Immortal", @"Advanced"]];
        [retireSelectionSpec setProperty:@1 forKey:@"default"];
        [retireSelectionSpec setProperty:@"retire" forKey:@"key"];
        [retireSelectionSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [retireSelectionSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [appEntrySpecifiers addObject:retireSelectionSpec];
    
        
        //Advanced
        PSSpecifier *advancedGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [advancedGroupSpec setProperty:[NSString stringWithFormat:@"Time Span is a global value, which means it applies to all enabled apps in this category to pleasantly manage power usage. Default is 30 minutes. Two periodic checks will be performed within the time span."] forKey:@"footerText"];
        [appEntrySpecifiers addObject:advancedGroupSpec];
        
        //time span
        PSTextFieldSpecifier* timeSpanSpec = [PSTextFieldSpecifier preferenceSpecifierNamed:@"Time Span" target:self set:@selector(setGlobalPreferenceValue:specifier:) get:@selector(readGlobalPreferenceValue:) detail:nil cell:PSEditTextCell edit:nil];
        [timeSpanSpec setKeyboardType:UIKeyboardTypeNumberPad autoCaps:UITextAutocapitalizationTypeNone autoCorrection:UITextAutocorrectionTypeNo];
        [timeSpanSpec setPlaceholder:@"1800"];
        [timeSpanSpec setProperty:@"timeSpan" forKey:@"key"];
        [timeSpanSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [timeSpanSpec setProperty:@"Time Span" forKey:@"label"];
        [timeSpanSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        self.timeSpanSpecSpecifier = timeSpanSpec;
        [appEntrySpecifiers addObject:timeSpanSpec];
        
        /*
        //cpu usage selection
        PSSpecifier *cpuUsageGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"CPU" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [cpuUsageGroupSpec setProperty:[NSString stringWithFormat:@"Set the maximum threshold CPU usage (0%% to 100%%) by %@ before it decides to retire itself within the preferred time span (s). Default is 0.5%%.", self.title] forKey:@"footerText"];
        [appEntrySpecifiers addObject:cpuUsageGroupSpec];
        
        PSSpecifier *cpuUsageSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"CPU Usage Selection" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSegmentCell edit:nil];
        [cpuUsageSelectionSpec setValues:@[@NO, @YES] titles:@[@"Disable", @"CPU Usage"]];
        [cpuUsageSelectionSpec setProperty:@1 forKey:@"default"];
        [cpuUsageSelectionSpec setProperty:@"cpuUsageEnabled" forKey:@"key"];
        [cpuUsageSelectionSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [cpuUsageSelectionSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        self.cpuUsageSelectionSpecifier = cpuUsageSelectionSpec;
        [appEntrySpecifiers addObject:cpuUsageSelectionSpec];
        
        //cpu usage
        PSTextFieldSpecifier* cpuUsageSpec = [PSTextFieldSpecifier preferenceSpecifierNamed:@"Max CPU Usage" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSEditTextCell edit:nil];
        [cpuUsageSpec setKeyboardType:UIKeyboardTypeDecimalPad autoCaps:UITextAutocapitalizationTypeNone autoCorrection:UITextAutocorrectionTypeNo];
        [cpuUsageSpec setPlaceholder:@"0.5"];
        [cpuUsageSpec setProperty:@"cpuUsageThreshold" forKey:@"key"];
        [cpuUsageSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [cpuUsageSpec setProperty:@"Max CPU Usage" forKey:@"label"];
        [cpuUsageSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        self.cpuUsageSpecifier = cpuUsageSpec;
        [appEntrySpecifiers addObject:cpuUsageSpec];
        
        //syscalls selection
        PSSpecifier *systemCallsGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"System Calls" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [systemCallsGroupSpec setProperty:[NSString stringWithFormat:@"Set the maximum number of Mach/BSD/Mach+BSD system calls (\U00000394 in one second) by %@ before it decides to retire itself within the preferred time span (s). Default is 0.", self.title] forKey:@"footerText"];
        [appEntrySpecifiers addObject:systemCallsGroupSpec];
        
        PSSpecifier *systemCallsSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"System Calls Selection" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSegmentCell edit:nil];
        [systemCallsSelectionSpec setValues:@[@0, @1, @2, @3] titles:@[@"Disable", @"Mach", @"BSD", @"Mach+BSD"]];
        [systemCallsSelectionSpec setProperty:@0 forKey:@"default"];
        [systemCallsSelectionSpec setProperty:@"systemCallsType" forKey:@"key"];
        [systemCallsSelectionSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [systemCallsSelectionSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        self.systemCallsSelectionSpecifier = systemCallsSelectionSpec;
        [appEntrySpecifiers addObject:systemCallsSelectionSpec];
        
        //syscalls
        PSTextFieldSpecifier* systemCallsSpec = [PSTextFieldSpecifier preferenceSpecifierNamed:@"Max System Calls" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSEditTextCell edit:nil];
        [systemCallsSpec setKeyboardType:UIKeyboardTypeNumberPad autoCaps:UITextAutocapitalizationTypeNone autoCorrection:UITextAutocorrectionTypeNo];
        [systemCallsSpec setPlaceholder:@"0"];
        [systemCallsSpec setProperty:@"systemCallsThreshold" forKey:@"key"];
        [systemCallsSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [systemCallsSpec setProperty:@"Max System Calls" forKey:@"label"];
        [systemCallsSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        self.systemCallsSpecifier = systemCallsSpec;
        [appEntrySpecifiers addObject:systemCallsSpec];
        */
        
        //blank
        PSSpecifier *blankSpecGroup = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [appEntrySpecifiers addObject:blankSpecGroup];
        
        //CPU Controller
        PSSpecifier *cpuControllerSpec = [PSSpecifier preferenceSpecifierNamed:@"CPU" target:nil set:nil get:nil detail:NSClassFromString(@"BakgrunnurAppCPUController") cell:PSLinkCell edit:nil];
        [cpuControllerSpec setProperty:[NSString stringWithFormat:@"%@-bakgrunnur-app-cpu-[%@]", self.specifier.identifier, self.title] forKey:@"id"];
        self.cpuControllerSpecifier = cpuControllerSpec;
        [appEntrySpecifiers addObject:cpuControllerSpec];
        
        //System Calls Controller
        PSSpecifier *systemCallsControllerSpec = [PSSpecifier preferenceSpecifierNamed:@"System Calls" target:nil set:nil get:nil detail:NSClassFromString(@"BakgrunnurAppSystemCallsController") cell:PSLinkCell edit:nil];
        [systemCallsControllerSpec setProperty:[NSString stringWithFormat:@"%@-bakgrunnur-app-systemcalls-[%@]", self.specifier.identifier, self.title] forKey:@"id"];
        self.systemCallsControllerSpecifier = systemCallsControllerSpec;
        [appEntrySpecifiers addObject:systemCallsControllerSpec];
        
        //Network Controller
        PSSpecifier *networkControllerSpec = [PSSpecifier preferenceSpecifierNamed:@"Network" target:nil set:nil get:nil detail:NSClassFromString(@"BakgrunnurAppNetworkController") cell:PSLinkCell edit:nil];
        [networkControllerSpec setProperty:[NSString stringWithFormat:@"%@-bakgrunnur-app-network-[%@]", self.specifier.identifier, self.title] forKey:@"id"];
        self.networkControllerSpecifier = networkControllerSpec;
        [appEntrySpecifiers addObject:networkControllerSpec];
        
        _specifiers = appEntrySpecifiers;
        
    }

	return _specifiers;
}

- (id)readGlobalPreferenceValue:(PSSpecifier*)specifier {
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    return (settings[specifier.properties[@"key"]]) ?: specifier.properties[@"default"];
}

- (void)setGlobalPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    [settings setObject:value forKey:specifier.properties[@"key"]];
    [settings writeToFile:path atomically:YES];
    CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
    if (notificationName) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
    }
    if ([specifier.properties[@"key"] isEqualToString:@"enabled"]){
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)REFRESH_MODULE_NOTIFICATION_NAME, NULL, NULL, YES);
        
    }
}



-(NSDictionary *)getItem:(NSDictionary *)prefs ofIdentifier:(NSString *)snippetID forKey:(NSString *)keyName identifierKey:(NSString *)identifier completion:(void (^)(NSUInteger idx))handler{
    NSArray *arrayWithEventID = [prefs[keyName] valueForKey:identifier];
    NSUInteger index = [arrayWithEventID indexOfObject:snippetID];
    NSDictionary *snippet = index != NSNotFound ? prefs[keyName][index] : @{};
    if (handler){
        handler(index);
    }
    return snippet;
}


- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    NSDictionary *item = [self getItem:settings ofIdentifier:self.specifier.identifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:nil];
    
    id value = (item[specifier.properties[@"key"]]) ?: specifier.properties[@"default"];
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"retire"]){
        if ([value intValue] == 2){
            self.isAdvanced = NO;
            [self.expirationSpecifier setProperty:@NO forKey:@"enabled"];
            [self.cpuControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [self.systemCallsControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [self.networkControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [self.timeSpanSpecSpecifier setProperty:@NO forKey:@"enabled"];
        }else if ([value intValue] == 3){
            self.isAdvanced = YES;
            [self.expirationSpecifier setProperty:@NO forKey:@"enabled"];
            [self.cpuControllerSpecifier setProperty:@YES forKey:@"enabled"];
            [self.systemCallsControllerSpecifier setProperty:@YES forKey:@"enabled"];
            [self.networkControllerSpecifier setProperty:@YES forKey:@"enabled"];
            [self.timeSpanSpecSpecifier setProperty:@YES forKey:@"enabled"];
        }else{
            self.isAdvanced = NO;
            [self.expirationSpecifier setProperty:@YES forKey:@"enabled"];
            [self.cpuControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [self.systemCallsControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [self.networkControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [self.timeSpanSpecSpecifier setProperty:@NO forKey:@"enabled"];
        }
        [self reloadSpecifier:self.expirationSpecifier animated:YES];
        [self reloadSpecifier:self.cpuControllerSpecifier animated:YES];
        [self reloadSpecifier:self.systemCallsControllerSpecifier animated:YES];
        [self reloadSpecifier:self.networkControllerSpecifier animated:YES];
        [self reloadSpecifier:self.timeSpanSpecSpecifier animated:YES];
    }
    
    
    return value;
    
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"retire"]){
        if ([value intValue] == 2){
            self.isAdvanced = NO;
            [self.expirationSpecifier setProperty:@NO forKey:@"enabled"];
            [self.cpuControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [self.systemCallsControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [self.networkControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [self.timeSpanSpecSpecifier setProperty:@NO forKey:@"enabled"];
        }else if ([value intValue] == 3){
            self.isAdvanced = YES;
            [self.expirationSpecifier setProperty:@NO forKey:@"enabled"];
            [self.cpuControllerSpecifier setProperty:@YES forKey:@"enabled"];
            [self.systemCallsControllerSpecifier setProperty:@YES forKey:@"enabled"];
            [self.networkControllerSpecifier setProperty:@YES forKey:@"enabled"];
            [self.timeSpanSpecSpecifier setProperty:@YES forKey:@"enabled"];
        }else{
            self.isAdvanced = NO;
            [self.expirationSpecifier setProperty:@YES forKey:@"enabled"];
            [self.cpuControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [self.systemCallsControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [self.networkControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [self.timeSpanSpecSpecifier setProperty:@NO forKey:@"enabled"];
        }
        [self reloadSpecifier:self.expirationSpecifier animated:YES];
        [self reloadSpecifier:self.cpuControllerSpecifier animated:YES];
        [self reloadSpecifier:self.systemCallsControllerSpecifier animated:YES];
        [self reloadSpecifier:self.networkControllerSpecifier animated:YES];
        [self reloadSpecifier:self.timeSpanSpecSpecifier animated:YES];
    }
    
    
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    
    NSMutableArray *newSettings = [[NSMutableArray alloc] init];
    if (settings[@"enabledIdentifier"]) newSettings = [settings[@"enabledIdentifier"] mutableCopy];
    
    
    __block NSUInteger idx;
    NSMutableDictionary *item;
    item = [[self getItem:settings ofIdentifier:self.specifier.identifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:^(NSUInteger index){
        idx = index;
    }] mutableCopy];
    
    if (!item) item = [[NSMutableDictionary alloc] init];
    
    if (item){
        [item setObject:value forKey:specifier.properties[@"key"]];
    }else{
        [item setObject:value forKey:specifier.properties[@"key"]];
    }
    [item setObject:self.specifier.identifier forKey:@"identifier"];

    HBLogDebug(@"item: %@", item);

    if (idx != NSNotFound){
        newSettings[idx] = item;
        HBLogDebug(@"settings exit: %@", settings);

    }else{
        [newSettings addObject:item];
        HBLogDebug(@"settings addobject: %@", settings);

    }
    
    HBLogDebug(@"settings: %@", settings);
    settings[@"enabledIdentifier"] = newSettings;
    
    [settings writeToFile:path atomically:YES];
    CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
    if (notificationName) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
    }
}

-(void)loadView {
    [super loadView];
    ((UITableView *)[self table]).keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
}

-(void)_returnKeyPressed:(id)arg1 {
    [self.view endEditing:YES];
}
@end
