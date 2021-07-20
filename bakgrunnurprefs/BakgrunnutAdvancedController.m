#import "../common.h"
#import "../BKGShared.h"
#import "BakgrunnutAdvancedController.h"

@implementation BakgrunnutAdvancedController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *rootSpecifiers = [[NSMutableArray alloc] init];
        
        //Show hidden applications
        PSSpecifier *showHiddenAppsGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [showHiddenAppsGroupSpec setProperty:@"Show hidden apps in Manage Apps." forKey:@"footerText"];
        [rootSpecifiers addObject:showHiddenAppsGroupSpec];
        
        PSSpecifier *showHiddenAppsSpec = [PSSpecifier preferenceSpecifierNamed:@"Show Hidden Apps. Requires reload of Settings." target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [showHiddenAppsSpec setProperty:@"Show Hidden Apps" forKey:@"label"];
        [showHiddenAppsSpec setProperty:@"showHiddenApps" forKey:@"key"];
        [showHiddenAppsSpec setProperty:@NO forKey:@"default"];
        [showHiddenAppsSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [showHiddenAppsSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [rootSpecifiers addObject:showHiddenAppsSpec];
        
        _specifiers = rootSpecifiers;
    }
    
    return _specifiers;
}

-(id)readPreferenceValue:(PSSpecifier*)specifier{
    NSString *key = [specifier propertyForKey:@"key"];
    id value = valueForKey(key, specifier.properties[@"default"]);
    return value;
}

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier{
    setValueForKey([specifier propertyForKey:@"key"], value);
    CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
    if (notificationName) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
    }
}

@end
