#include "../common.h"
#import "BakgrunnurModuleRootListController.h"

@implementation BakgrunnurModuleRootListController
- (NSArray *)specifiers{
    if (!_specifiers) {
        NSMutableArray *rootSpecifiers = [[NSMutableArray alloc] init];
        PSSpecifier *longPressingGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Long Press/Force Touch" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [longPressingGroupSpec setProperty:@"Set action when long pressing/force touching the module. Enable Once only valid in instance where master Enabled switch for the app is off, and its token will be revoked when the app is active again." forKey:@"footerText"];
        [rootSpecifiers addObject:longPressingGroupSpec];
        
        /*
        //action
        PSSpecifier *actionSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"Long Press Action" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSegmentCell edit:nil];
        [actionSelectionSpec setValues:@[@0, @1, @2, @3, @4, @5] titles:@[@"Open Setting", @"Enable App", @"Disable App", @"Toggle", @"Enable Once", @"Expand Module"]];
        [actionSelectionSpec setProperty:@0 forKey:@"default"];
        [actionSelectionSpec setProperty:@"moduleAction" forKey:@"key"];
        [actionSelectionSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        //[actionSelectionSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [rootSpecifiers addObject:actionSelectionSpec];
        */
        
        //action - list
        PSSpecifier *actionSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"Long Press Action" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:NSClassFromString(@"PSListItemsController") cell:PSLinkListCell edit:Nil];
        [actionSelectionSpec setProperty:NSClassFromString(@"PSLinkListCell") forKey:@"cellClass"];
        [actionSelectionSpec setProperty:@"Long Press Action" forKey:@"label"];
        [actionSelectionSpec setProperty:@(-1) forKey:@"default"];
        [actionSelectionSpec setValues:@[@0, @1, @2, @3, @4, @5, @6, @(-1)] titles:@[@"App Settings", @"Enable App", @"Disable App", @"Toggle App", @"Enable App Once", @"Disable App Once", @"Toggle App Once", @"Expand Module"]];
        [actionSelectionSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [actionSelectionSpec setProperty:@"moduleAction" forKey:@"key"];
        [actionSelectionSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [rootSpecifiers addObject:actionSelectionSpec];
        
        
        _specifiers = rootSpecifiers;

    }

    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    return (settings[specifier.properties[@"key"]]) ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    [settings setObject:value forKey:specifier.properties[@"key"]];
    [settings writeToFile:path atomically:YES];
    CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
    if (notificationName) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
    }
     NSString *key = [specifier propertyForKey:@"key"];
       if ([key isEqualToString:@"sortPriority"]){
           [self reloadSpecifiers];
       }
}

@end
