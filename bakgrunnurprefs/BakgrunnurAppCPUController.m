#import "../common.h"
#include "BakgrunnurAppCPUController.h"
#import "NSString+Regex.h"

@implementation BakgrunnurAppCPUController

- (NSArray *)specifiers {
    if (!_specifiers) {
        
        self.identifier = [self.specifier.identifier stringByReplacingWithPattern:@"(.*)-bakgrunnur-.*-\\[(.*)\\]" withTemplate:@"$1" error:nil];
        self.appName = [self.specifier.identifier stringByReplacingWithPattern:@"(.*)-bakgrunnur-.*-\\[(.*)\\]" withTemplate:@"$2" error:nil];
        
        NSMutableArray *controllerSpecifiers = [[NSMutableArray alloc] init];
        
        //cpu usage selection
        PSSpecifier *cpuUsageGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"CPU" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [cpuUsageGroupSpec setProperty:[NSString stringWithFormat:@"Set the threshold CPU usage (0%% to 100%%) by %@ before it decides to retire itself within the preferred time span (s). Default is 0.5%%.", self.appName] forKey:@"footerText"];
        [controllerSpecifiers addObject:cpuUsageGroupSpec];
        
        PSSpecifier *cpuUsageSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"CPU Usage Selection" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSegmentCell edit:nil];
        [cpuUsageSelectionSpec setValues:@[@NO, @YES] titles:@[@"Disable", @"CPU Usage"]];
        [cpuUsageSelectionSpec setProperty:@NO forKey:@"default"];
        [cpuUsageSelectionSpec setProperty:@"cpuUsageEnabled" forKey:@"key"];
        [cpuUsageSelectionSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [cpuUsageSelectionSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        self.cpuUsageSelectionSpecifier = cpuUsageSelectionSpec;
        [controllerSpecifiers addObject:cpuUsageSelectionSpec];
        
        //cpu usage
        PSTextFieldSpecifier* cpuUsageSpec = [PSTextFieldSpecifier preferenceSpecifierNamed:@"CPU Usage Threshold" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSEditTextCell edit:nil];
        [cpuUsageSpec setKeyboardType:UIKeyboardTypeDecimalPad autoCaps:UITextAutocapitalizationTypeNone autoCorrection:UITextAutocorrectionTypeNo];
        [cpuUsageSpec setPlaceholder:@"0.5"];
        [cpuUsageSpec setProperty:@"cpuUsageThreshold" forKey:@"key"];
        [cpuUsageSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [cpuUsageSpec setProperty:@"CPU Usage Threshold" forKey:@"label"];
        [cpuUsageSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        self.cpuUsageSpecifier = cpuUsageSpec;
        [controllerSpecifiers addObject:cpuUsageSpec];
        
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
   if ([key isEqualToString:@"cpuUsageEnabled"]){
        [self.cpuUsageSpecifier setProperty:value forKey:@"enabled"];
        [self reloadSpecifier:self.cpuUsageSpecifier animated:YES];
    }
    
    
    return value;
    
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"cpuUsageEnabled"]){
        [self.cpuUsageSpecifier setProperty:value forKey:@"enabled"];
        [self reloadSpecifier:self.cpuUsageSpecifier animated:YES];
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
