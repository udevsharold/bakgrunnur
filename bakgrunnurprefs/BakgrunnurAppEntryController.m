#import "../common.h"
#import "../BKGShared.h"
#import "BakgrunnurAppEntryController.h"
#import "BakgrunnurApplicationListSubcontrollerController.h"

@implementation BakgrunnurAppEntryController

- (NSArray *)specifiers {
    if (!_specifiers) {
        
        _expanded = NO;
        _manuallyExpanded = NO;
        
        NSMutableArray *appEntrySpecifiers = [NSMutableArray array];
        
        _staticSpecifiers = [NSMutableArray array];
        
        //Enabled
        _enabledEntrySpecifier = [PSSpecifier preferenceSpecifierNamed:@"Enabled" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [_enabledEntrySpecifier setProperty:@"Enabled" forKey:@"label"];
        [_enabledEntrySpecifier setProperty:@"enabled" forKey:@"key"];
        [_enabledEntrySpecifier setProperty:@NO forKey:@"default"];
        [_enabledEntrySpecifier setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [_enabledEntrySpecifier setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [_staticSpecifiers addObject:_enabledEntrySpecifier];
        
        
        _expandableSpecifiers = [NSMutableArray array];
        
        //Enabled notification
        PSSpecifier *enabledAppNotificationsGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [enabledAppNotificationsGroupSpec setProperty:[NSString stringWithFormat:@"Allow %@ to dispatch notifications even though it is being backgrounded by Bakgrunnur.", self.title] forKey:@"footerText"];
        [_expandableSpecifiers addObject:enabledAppNotificationsGroupSpec];
        
        PSSpecifier *enabledAppNotificationsSpec = [PSSpecifier preferenceSpecifierNamed:@"Notifications (BETA)" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [enabledAppNotificationsSpec setProperty:@"Notifications (BETA)" forKey:@"label"];
        [enabledAppNotificationsSpec setProperty:@"enabledAppNotifications" forKey:@"key"];
        [enabledAppNotificationsSpec setProperty:@NO forKey:@"default"];
        [enabledAppNotificationsSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [enabledAppNotificationsSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [_expandableSpecifiers addObject:enabledAppNotificationsSpec];
        
        //Persistence once
        PSSpecifier *persistenceOnceGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [persistenceOnceGroupSpec setProperty:[NSString stringWithFormat:@"Keep \"Enable Once\" token for %@ alive unless being forcefully terminated via app switcher. Token will be revoked whenever %@ is active again when this setting is disabled.", self.title, self.title] forKey:@"footerText"];
        [_expandableSpecifiers addObject:persistenceOnceGroupSpec];
        
        PSSpecifier *persistenceOnceSpec = [PSSpecifier preferenceSpecifierNamed:@"Persistence Once Token" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [persistenceOnceSpec setProperty:@"Persistence Once Token" forKey:@"label"];
        [persistenceOnceSpec setProperty:@"persistenceOnce" forKey:@"key"];
        [persistenceOnceSpec setProperty:@NO forKey:@"default"];
        [persistenceOnceSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [persistenceOnceSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [_expandableSpecifiers addObject:persistenceOnceSpec];
        
        //Dark wake
        PSSpecifier *darkWakeGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [darkWakeGroupSpec setProperty:[NSString stringWithFormat:@"Allow %@ to put device into half-asleep state instead of full sleep when locked. CPU, networking and disk read/write will operate at full capacity in this state. Useful when app needs full network/disk speed for background operations (files downloading, SSH etc.). By default, system will throttle/disable these capabilities when locked.", self.title] forKey:@"footerText"];
        [_expandableSpecifiers addObject:darkWakeGroupSpec];
        
        PSSpecifier *darkWakeSpec = [PSSpecifier preferenceSpecifierNamed:@"Half-asleep" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [darkWakeSpec setProperty:@"Half-asleep" forKey:@"label"];
        [darkWakeSpec setProperty:@"darkWake" forKey:@"key"];
        [darkWakeSpec setProperty:@NO forKey:@"default"];
        [darkWakeSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [darkWakeSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [_expandableSpecifiers addObject:darkWakeSpec];
        
        //aggressive assertion
        PSSpecifier *aggressiveAssertionGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [aggressiveAssertionGroupSpec setProperty:[NSString stringWithFormat:@"Aggressively put %@ into backgrounding mode. Enabling this will prevent the UI of %@ from being throttled and try to use as much resources as needed.", self.title, self.title] forKey:@"footerText"];
        [_expandableSpecifiers addObject:aggressiveAssertionGroupSpec];
        
        PSSpecifier *aggressiveAssertionSpec = [PSSpecifier preferenceSpecifierNamed:@"Aggressive" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [aggressiveAssertionSpec setProperty:@"Aggressive" forKey:@"label"];
        [aggressiveAssertionSpec setProperty:@"aggressiveAssertion" forKey:@"key"];
        [aggressiveAssertionSpec setProperty:@YES forKey:@"default"];
        [aggressiveAssertionSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [aggressiveAssertionSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [_expandableSpecifiers addObject:aggressiveAssertionSpec];
        
        //expiration
        PSSpecifier *expirationGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [expirationGroupSpec setProperty:@"Set the expiration time (s) for app to be retired/terminated. The countdown will begin when the app entered background or the device is locked. It'll be reset whenever the app is in foreground or active again. Default is 3 hours." forKey:@"footerText"];
        [_expandableSpecifiers addObject:expirationGroupSpec];
        
        
        _expirationSpecifier = [PSTextFieldSpecifier preferenceSpecifierNamed:@"Expiration" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSEditTextCell edit:nil];
        [_expirationSpecifier setKeyboardType:UIKeyboardTypeNumberPad autoCaps:UITextAutocapitalizationTypeNone autoCorrection:UITextAutocorrectionTypeNo];
        [_expirationSpecifier setPlaceholder:@"10800"];
        [_expirationSpecifier setProperty:@"expiration" forKey:@"key"];
        [_expirationSpecifier setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [_expirationSpecifier setProperty:@"Expiration" forKey:@"label"];
        [_expirationSpecifier setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [_expandableSpecifiers addObject:_expirationSpecifier];
        
        //retire type
        PSSpecifier *retireSelectionGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [retireSelectionGroupSpec setProperty:@"\U0001F539Retire: System will be informed to suspends app gracefully.\n\U0001F539Terminate: App will be terminated immediately once it's expired.\n\U0001F539Immortal: App will remains active indefinately unless being forcefully terminated by user or after a respring.\n\U0001F539Advanced: App will be retired according to the preferred advanced settings (CPU, system calls & network) within the specified time span." forKey:@"footerText"];
        [_expandableSpecifiers addObject:retireSelectionGroupSpec];
        
        PSSpecifier *retireSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"Retire" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSegmentCell edit:nil];
        [retireSelectionSpec setValues:@[@(BKGBackgroundTypeRetire), @(BKGBackgroundTypeTerminate), @(BKGBackgroundTypeImmortal), @(BKGBackgroundTypeAdvanced)] titles:@[@"Retire", @"Terminate", @"Immortal", @"Advanced"]];
        [retireSelectionSpec setProperty:@(BKGBackgroundTypeRetire) forKey:@"default"];
        [retireSelectionSpec setProperty:@"retire" forKey:@"key"];
        [retireSelectionSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [retireSelectionSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [_expandableSpecifiers addObject:retireSelectionSpec];
        
        
        //Advanced
        PSSpecifier *advancedGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [advancedGroupSpec setProperty:[NSString stringWithFormat:@"Time Span is a global value, which means it applies to all enabled apps in this category to pleasantly manage power usage. Default is 30 minutes. Two periodic checks will be performed within the time span."] forKey:@"footerText"];
        [_expandableSpecifiers addObject:advancedGroupSpec];
        
        //time span
        _timeSpanSpecifier = [PSTextFieldSpecifier preferenceSpecifierNamed:@"Time Span" target:self set:@selector(setGlobalPreferenceValue:specifier:) get:@selector(readGlobalPreferenceValue:) detail:nil cell:PSEditTextCell edit:nil];
        [_timeSpanSpecifier setKeyboardType:UIKeyboardTypeNumberPad autoCaps:UITextAutocapitalizationTypeNone autoCorrection:UITextAutocorrectionTypeNo];
        [_timeSpanSpecifier setPlaceholder:@"1800"];
        [_timeSpanSpecifier setProperty:@"timeSpan" forKey:@"key"];
        [_timeSpanSpecifier setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [_timeSpanSpecifier setProperty:@"Time Span" forKey:@"label"];
        [_timeSpanSpecifier setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [_expandableSpecifiers addObject:_timeSpanSpecifier];
        
        //blank
        PSSpecifier *blankSpecGroup = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [_expandableSpecifiers addObject:blankSpecGroup];
        
        //CPU Controller
        _cpuControllerSpecifier = [PSSpecifier preferenceSpecifierNamed:@"CPU" target:nil set:nil get:nil detail:NSClassFromString(@"BakgrunnurAppCPUController") cell:PSLinkCell edit:nil];
        [_cpuControllerSpecifier setProperty:[NSString stringWithFormat:@"%@-bakgrunnur-app-cpu-[%@]", self.specifier.identifier, self.title] forKey:@"id"];
        [_expandableSpecifiers addObject:_cpuControllerSpecifier];
        
        //System Calls Controller
        _systemCallsControllerSpecifier = [PSSpecifier preferenceSpecifierNamed:@"System Calls" target:nil set:nil get:nil detail:NSClassFromString(@"BakgrunnurAppSystemCallsController") cell:PSLinkCell edit:nil];
        [_systemCallsControllerSpecifier setProperty:[NSString stringWithFormat:@"%@-bakgrunnur-app-systemcalls-[%@]", self.specifier.identifier, self.title] forKey:@"id"];
        [_expandableSpecifiers addObject:_systemCallsControllerSpecifier];
        
        //Network Controller
        _networkControllerSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Network" target:nil set:nil get:nil detail:NSClassFromString(@"BakgrunnurAppNetworkController") cell:PSLinkCell edit:nil];
        [_networkControllerSpecifier setProperty:[NSString stringWithFormat:@"%@-bakgrunnur-app-network-[%@]", self.specifier.identifier, self.title] forKey:@"id"];
        [_expandableSpecifiers addObject:_networkControllerSpecifier];
        
        
        [appEntrySpecifiers addObjectsFromArray:_staticSpecifiers];
        
        if ([[self readPreferenceValue:_enabledEntrySpecifier] boolValue]){
            [appEntrySpecifiers addObjectsFromArray:_expandableSpecifiers];
            _expanded = YES;
        }
        
        _specifiers = appEntrySpecifiers;
        
    }
    
    return _specifiers;
}

- (id)readGlobalPreferenceValue:(PSSpecifier*)specifier {
    return valueForKey(specifier.properties[@"key"], specifier.properties[@"default"]);
}

- (void)setGlobalPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    setValueForKey([specifier propertyForKey:@"key"], value);
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id value = valueForConfigKey(self.specifier.identifier, key, specifier.properties[@"default"]);
    return value;
}

-(void)updateParentViewController{
    UIViewController *parentController = (UIViewController *)[self valueForKey:@"_parentController"];
    if ([parentController respondsToSelector:@selector(specifierForApplicationWithIdentifier:)]){
        [(BakgrunnurApplicationListSubcontrollerController *)parentController updateIvars];
        [(BakgrunnurApplicationListSubcontrollerController *)parentController reloadSpecifier:[(BakgrunnurApplicationListSubcontrollerController *)parentController specifierForApplicationWithIdentifier:self.specifier.identifier] animated:YES];
    }
}

-(void)updateParentViewControllerWithDelay:(double)delay{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateParentViewController];
    });
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"retire"]){
        if ([value unsignedLongValue] == BKGBackgroundTypeImmortal){
            _isAdvanced = NO;
            [_expirationSpecifier setProperty:@NO forKey:@"enabled"];
            [_cpuControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [_systemCallsControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [_networkControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [_timeSpanSpecifier setProperty:@NO forKey:@"enabled"];
        }else if ([value unsignedLongValue] == BKGBackgroundTypeAdvanced){
            _isAdvanced = YES;
            [_expirationSpecifier setProperty:@NO forKey:@"enabled"];
            [_cpuControllerSpecifier setProperty:@YES forKey:@"enabled"];
            [_systemCallsControllerSpecifier setProperty:@YES forKey:@"enabled"];
            [_networkControllerSpecifier setProperty:@YES forKey:@"enabled"];
            [_timeSpanSpecifier setProperty:@YES forKey:@"enabled"];
        }else{
            _isAdvanced = NO;
            [_expirationSpecifier setProperty:@YES forKey:@"enabled"];
            [_cpuControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [_systemCallsControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [_networkControllerSpecifier setProperty:@NO forKey:@"enabled"];
            [_timeSpanSpecifier setProperty:@NO forKey:@"enabled"];
        }
        [self reloadSpecifier:_expirationSpecifier animated:YES];
        [self reloadSpecifier:_cpuControllerSpecifier animated:YES];
        [self reloadSpecifier:_systemCallsControllerSpecifier animated:YES];
        [self reloadSpecifier:_networkControllerSpecifier animated:YES];
        [self reloadSpecifier:_timeSpanSpecifier animated:YES];
    }
    
    setValueForConfigKey(self.specifier.identifier, key, value);
    
    if ([key isEqualToString:@"enabled"]){
        if ([value boolValue] && !_expanded){
            [self insertContiguousSpecifiers:_expandableSpecifiers afterSpecifier:specifier animated:YES];
            _expanded = YES;
        }else if(![value boolValue] && _expanded){
            [self removeContiguousSpecifiers:_expandableSpecifiers animated:YES];
            _expanded = NO;
        }
    }
    
    if ([key isEqualToString:@"enabled"] || [key isEqualToString:@"retire"] || [key isEqualToString:@"expiration"] || [key isEqualToString:@"darkWake"]){
        [self updateParentViewController];
    }
}

-(void)viewWillAppear:(BOOL)animated{
    BKGBackgroundType backgroundType = unsignedLongValueForConfigKey(self.specifier.identifier, @"retire", BKGBackgroundTypeRetire);
    if (backgroundType == BKGBackgroundTypeImmortal){
        _isAdvanced = NO;
        [_expirationSpecifier setProperty:@NO forKey:@"enabled"];
        [_cpuControllerSpecifier setProperty:@NO forKey:@"enabled"];
        [_systemCallsControllerSpecifier setProperty:@NO forKey:@"enabled"];
        [_networkControllerSpecifier setProperty:@NO forKey:@"enabled"];
        [_timeSpanSpecifier setProperty:@NO forKey:@"enabled"];
    }else if (backgroundType == BKGBackgroundTypeAdvanced){
        _isAdvanced = YES;
        [_expirationSpecifier setProperty:@NO forKey:@"enabled"];
        [_cpuControllerSpecifier setProperty:@YES forKey:@"enabled"];
        [_systemCallsControllerSpecifier setProperty:@YES forKey:@"enabled"];
        [_networkControllerSpecifier setProperty:@YES forKey:@"enabled"];
        [_timeSpanSpecifier setProperty:@YES forKey:@"enabled"];
    }else{
        _isAdvanced = NO;
        [_expirationSpecifier setProperty:@YES forKey:@"enabled"];
        [_cpuControllerSpecifier setProperty:@NO forKey:@"enabled"];
        [_systemCallsControllerSpecifier setProperty:@NO forKey:@"enabled"];
        [_networkControllerSpecifier setProperty:@NO forKey:@"enabled"];
        [_timeSpanSpecifier setProperty:@NO forKey:@"enabled"];
    }
    [self reloadSpecifier:_expirationSpecifier animated:YES];
    [self reloadSpecifier:_cpuControllerSpecifier animated:YES];
    [self reloadSpecifier:_systemCallsControllerSpecifier animated:YES];
    [self reloadSpecifier:_networkControllerSpecifier animated:YES];
    [self reloadSpecifier:_timeSpanSpecifier animated:YES];
    [super viewWillAppear:animated];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
    if (!_manuallyExpanded && !_expanded && indexPath == [self indexPathForSpecifier:_enabledEntrySpecifier]){
        [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
        [self expands:!_expanded];
        _manuallyExpanded = YES;
    }
}

-(void)expands:(BOOL)expands{
    if (expands && !_expanded){
        [self insertContiguousSpecifiers:_expandableSpecifiers afterSpecifier:_enabledEntrySpecifier animated:YES];
        _expanded = YES;
    }else if (!expands && _expanded){
        [self removeContiguousSpecifiers:_expandableSpecifiers animated:YES];
        _expanded = NO;
    }
}

-(void)loadView{
    [super loadView];
    self.table.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
}

-(void)_returnKeyPressed:(id)arg1{
    [self.view endEditing:YES];
}
@end
