#import "../common.h"
#include "BakgrunnurAppSystemCallsController.h"
#import "NSString+Regex.h"

@implementation BakgrunnurAppSystemCallsController

- (NSArray *)specifiers {
    if (!_specifiers) {
        
        self.identifier = [self.specifier.identifier stringByReplacingWithPattern:@"(.*)-bakgrunnur-.*-\\[(.*)\\]" withTemplate:@"$1" error:nil];
        self.appName = [self.specifier.identifier stringByReplacingWithPattern:@"(.*)-bakgrunnur-.*-\\[(.*)\\]" withTemplate:@"$2" error:nil];
        
        NSMutableArray *controllerSpecifiers = [[NSMutableArray alloc] init];
        
        //syscalls selection
        PSSpecifier *systemCallsGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"System Calls" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [systemCallsGroupSpec setProperty:[NSString stringWithFormat:@"Set the threshold number of Mach/BSD/Mach+BSD system calls (\U00000394 in one second) by %@ before it decides to retire itself within the preferred time span (s). Default is 0.", self.appName] forKey:@"footerText"];
        [controllerSpecifiers addObject:systemCallsGroupSpec];
        
        PSSpecifier *systemCallsSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"System Calls Selection" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSegmentCell edit:nil];
        [systemCallsSelectionSpec setValues:@[@0, @1, @2, @3] titles:@[@"Disable", @"Mach", @"BSD", @"Mach+BSD"]];
        [systemCallsSelectionSpec setProperty:@0 forKey:@"default"];
        [systemCallsSelectionSpec setProperty:@"systemCallsType" forKey:@"key"];
        [systemCallsSelectionSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [systemCallsSelectionSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        self.systemCallsSelectionSpecifier = systemCallsSelectionSpec;
        [controllerSpecifiers addObject:systemCallsSelectionSpec];
        
        //syscalls
        PSTextFieldSpecifier* systemCallsSpec = [PSTextFieldSpecifier preferenceSpecifierNamed:@"System Calls Threshold" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSEditTextCell edit:nil];
        [systemCallsSpec setKeyboardType:UIKeyboardTypeNumberPad autoCaps:UITextAutocapitalizationTypeNone autoCorrection:UITextAutocorrectionTypeNo];
        [systemCallsSpec setPlaceholder:@"0"];
        [systemCallsSpec setProperty:@"systemCallsThreshold" forKey:@"key"];
        [systemCallsSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [systemCallsSpec setProperty:@"Max System Calls" forKey:@"label"];
        [systemCallsSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        self.systemCallsSpecifier = systemCallsSpec;
        [controllerSpecifiers addObject:systemCallsSpec];
        
        _specifiers = controllerSpecifiers;
        
        
    }
    
    return _specifiers;
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
    NSDictionary *item = [self getItem:settings ofIdentifier:self.identifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:nil];
    
    id value = (item[specifier.properties[@"key"]]) ?: specifier.properties[@"default"];
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"systemCallsType"]){
        [self.systemCallsSpecifier setProperty:([value intValue] > 0)?@YES:@NO forKey:@"enabled"];
        [self reloadSpecifier:self.systemCallsSpecifier animated:YES];
    }
    
    
    return value;
    
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"systemCallsType"]){
        [self.systemCallsSpecifier setProperty:([value intValue] > 0)?@YES:@NO forKey:@"enabled"];
        [self reloadSpecifier:self.systemCallsSpecifier animated:YES];
    }
    
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    
    NSMutableArray *newSettings = [[NSMutableArray alloc] init];
    if (settings[@"enabledIdentifier"]) newSettings = [settings[@"enabledIdentifier"] mutableCopy];
    
    
    __block NSUInteger idx;
    NSMutableDictionary *item;
    item = [[self getItem:settings ofIdentifier:self.identifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:^(NSUInteger index){
        idx = index;
    }] mutableCopy];
    
    if (!item) item = [[NSMutableDictionary alloc] init];
    
    if (item){
        [item setObject:value forKey:specifier.properties[@"key"]];
    }else{
        [item setObject:value forKey:specifier.properties[@"key"]];
    }
    [item setObject:self.identifier forKey:@"identifier"];
    
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
