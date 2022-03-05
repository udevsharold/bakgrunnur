#import "../common.h"
#import "BKGCCModuleRootListController.h"
#import "../BKGShared.h"

@implementation BKGCCModuleRootListController

-(NSArray *)specifiers{
    if (!_specifiers) {
        NSMutableArray *rootSpecifiers = [[NSMutableArray alloc] init];
        PSSpecifier *actionsGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Gestures" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [actionsGroupSpec setProperty:@"Enable Once only valid in instance where master Enabled switch for the app is off, and its token will be revoked when the app is active again." forKey:@"footerText"];
        [rootSpecifiers addObject:actionsGroupSpec];
        
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
		
		//action - single
		PSSpecifier *singleTapSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"Single Tap" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:NSClassFromString(@"PSListItemsController") cell:PSLinkListCell edit:Nil];
		[singleTapSelectionSpec setProperty:NSClassFromString(@"PSLinkListCell") forKey:@"cellClass"];
		[singleTapSelectionSpec setProperty:@"Single Tap Action" forKey:@"label"];
		[singleTapSelectionSpec setProperty:@(BKGCCModuleActionToggle) forKey:@"default"];
		[singleTapSelectionSpec setValues:@[@(BKGCCModuleActionOpenAppSettings), @(BKGCCModuleActionToggle), @(BKGCCModuleActionToggleApp), @(BKGCCModuleActionToggleAppOnce), @(BKGCCModuleActionExpandModule), @(BKGCCModuleActionDoNothing)] titles:@[@"App Settings", @"Toggle Bakgrunnur", @"Toggle App", @"Toggle App (Once)", @"Expand Module", @"Do Nothing"]];
		[singleTapSelectionSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
		[singleTapSelectionSpec setProperty:@"moduleSingleTapAction" forKey:@"key"];
		[singleTapSelectionSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
		[rootSpecifiers addObject:singleTapSelectionSpec];
        
        //action - long press
        PSSpecifier *longPressSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"Long Press" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:NSClassFromString(@"PSListItemsController") cell:PSLinkListCell edit:Nil];
        [longPressSelectionSpec setProperty:NSClassFromString(@"PSLinkListCell") forKey:@"cellClass"];
        [longPressSelectionSpec setProperty:@"Long Press Action" forKey:@"label"];
        [longPressSelectionSpec setProperty:@(BKGCCModuleActionDefault) forKey:@"default"];
		[longPressSelectionSpec setValues:@[@(BKGCCModuleActionOpenAppSettings), @(BKGCCModuleActionToggle), @(BKGCCModuleActionEnableApp), @(BKGCCModuleActionDisableApp), @(BKGCCModuleActionToggleApp), @(BKGCCModuleActionEnableAppOnce), @(BKGCCModuleActionDisableAppOnce), @(BKGCCModuleActionToggleAppOnce), @(BKGCCModuleActionExpandModule), @(BKGCCModuleActionDoNothing)] titles:@[@"App Settings", @"Toggle Bakgrunnur", @"Enable App", @"Disable App", @"Toggle App", @"Enable App (Once)", @"Disable App (Once)", @"Toggle App (Once)", @"Expand Module", @"Do Nothing"]];
        [longPressSelectionSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [longPressSelectionSpec setProperty:@"moduleAction" forKey:@"key"];
        [longPressSelectionSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [rootSpecifiers addObject:longPressSelectionSpec];
        
        
        _specifiers = rootSpecifiers;

    }

    return _specifiers;
}

-(id)readPreferenceValue:(PSSpecifier *)specifier{
	NSString *key = [specifier propertyForKey:@"key"];
	id value = valueForKey(key, specifier.properties[@"default"]);
	return value;
}

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier{
	setValueForKey([specifier propertyForKey:@"key"], value);
	/*
	CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
	if (notificationName){
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
	}
	*/
}

@end
