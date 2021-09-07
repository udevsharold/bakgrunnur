#import "../common.h"
#import "../BKGShared.h"
#import "BakgrunnurAppEntryController.h"
#import "BakgrunnurAppCPUController.h"
#import "NSString+Regex.h"

@implementation BakgrunnurAppCPUController

static void refreshSpecifiers() {
	[[NSNotificationCenter defaultCenter] postNotificationName:RELOAD_SPECIFIERS_LOCAL_NOTIFICATION_NAME object:nil];
}

- (instancetype)init{
	if ((self = [super init])) {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)refreshSpecifiers, (CFStringRef)RELOAD_SPECIFIERS_NOTIFICATION_NAME, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshSpecifiers:) name:RELOAD_SPECIFIERS_LOCAL_NOTIFICATION_NAME object:nil];
	}
	return self;
}

- (void)refreshSpecifiers:(NSNotification *)notification{
	[self reloadSpecifiers];
}

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

- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id value = valueForConfigKey(self.identifier, key, specifier.properties[@"default"]);
   if ([key isEqualToString:@"cpuUsageEnabled"]){
        [self.cpuUsageSpecifier setProperty:value forKey:@"enabled"];
        [self reloadSpecifier:self.cpuUsageSpecifier animated:YES];
    }
    return value;
}

-(void)updateParentViewController{
    UIViewController *parentController = (UIViewController *)[self valueForKey:@"_parentController"];
    if ([parentController respondsToSelector:@selector(updateParentViewController)]){
        [(BakgrunnurAppEntryController *)parentController updateParentViewController];
    }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"cpuUsageEnabled"]){
        [self.cpuUsageSpecifier setProperty:value forKey:@"enabled"];
        [self reloadSpecifier:self.cpuUsageSpecifier animated:YES];
    }
    setValueForConfigKey(self.identifier, key, value);
    
    if ([key isEqualToString:@"cpuUsageEnabled"]){
        [self updateParentViewController];
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
