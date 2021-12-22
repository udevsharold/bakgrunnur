#import "../common.h"
#import "../BKGShared.h"
#import "BKGPAppEntryController.h"
#import "BKGPAppSystemCallsController.h"
#import "NSString+Regex.h"

@implementation BKGPAppSystemCallsController

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

- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id value = valueForConfigKey(self.identifier, key, specifier.properties[@"default"]);
    if ([key isEqualToString:@"systemCallsType"]){
        [self.systemCallsSpecifier setProperty:([value intValue] > 0)?@YES:@NO forKey:@"enabled"];
        [self reloadSpecifier:self.systemCallsSpecifier animated:YES];
    }
    return value;
}

-(void)updateParentViewController{
    UIViewController *parentController = (UIViewController *)[self valueForKey:@"_parentController"];
    if ([parentController respondsToSelector:@selector(updateParentViewController)]){
        [(BKGPAppEntryController *)parentController updateParentViewController];
    }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"systemCallsType"]){
        [self.systemCallsSpecifier setProperty:([value intValue] > 0)?@YES:@NO forKey:@"enabled"];
        [self reloadSpecifier:self.systemCallsSpecifier animated:YES];
    }
    setValueForConfigKey(self.identifier, key, value);
    
    if ([key isEqualToString:@"systemCallsType"]){
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
