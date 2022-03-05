#import "../common.h"
#import "BKGCCToggleModule.h"
#import "../BKGShared.h"
#import "../BKGBakgrunnur.h"
#import <objc/runtime.h>

@implementation BKGCCToggleModule

-(instancetype)init{
	if ((self = [super init])) {
		_shouldSetValue = YES;
		_contentViewController = [[BKGCCModuleContentViewController alloc] init];
		_contentViewController.module = self;
		[self updateStateViaPreferences];
	}
	return self;
}

-(UIViewController*)contentViewController{
	return _contentViewController;
}

-(BOOL)shouldSelect{
	NSDictionary *prefs = getPrefs();
	BKGCCModuleAction singleTapAction = intValueForKeyWithPrefs(@"moduleSingleTapAction", BKGCCModuleActionToggle, prefs);
	SBApplication *frontMostApp = [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
		
	switch (singleTapAction) {
		case BKGCCModuleActionToggleApp:{
			
			if ([frontMostApp.bundleIdentifier isEqualToString:@"com.apple.springboard"]){
				return boolValueForKeyWithPrefs(@"enabled", YES, prefs);
			}
			
			BOOL toggleVal = NO;
			NSDictionary *item = [self getItem:prefs ofIdentifier:frontMostApp.bundleIdentifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:nil];
			if (item){
				toggleVal = [item[@"enabled"] boolValue];
			}
			return toggleVal;
		}
		case BKGCCModuleActionToggleAppOnce:{
			
			if ([frontMostApp.bundleIdentifier isEqualToString:@"com.apple.springboard"]){
				return boolValueForKeyWithPrefs(@"enabled", YES, prefs);
			}
			
			BOOL toggleVal = NO;
			NSDictionary *item = [self getItem:prefs ofIdentifier:frontMostApp.bundleIdentifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:nil];
			if (item){
				toggleVal = [item[@"enabled"] boolValue];
			}
			return toggleVal;
			break;
		}
		case BKGCCModuleActionDoNothing:
		case BKGCCModuleActionExpandModule:{
			self.expandOnTap = YES;
		}
		case BKGCCModuleActionOpenAppSettings:
		case BKGCCModuleActionToggle:
		default:{
			return boolValueForKeyWithPrefs(@"enabled", YES, prefs);
		}
	}
}

-(void)updateState{
	self.expandOnTap = NO;
	_selected = [self shouldSelect];
}

-(void)updateStateViaPreferences{
	_shouldSetValue = NO;
	self.expandOnTap = NO;
	_selected = [self shouldSelect];
	[self setSelected:_selected];
	[_contentViewController setSelected:_selected];
	_shouldSetValue = YES;
}

//Return the icon of your module here
-(UIImage *)iconGlyph{
	return [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
}

//Return the color selection color of your module here
-(UIColor *)selectedColor{
	return [UIColor blueColor];
}

-(BOOL)isSelected{
	return _selected;
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

- (void)setPreferenceValue:(id)value forKey:(NSString *)key bundleIdentifier:(NSString *)bundleIdentifier{
	setValueForConfigKey(bundleIdentifier, key, value);
}

-(void)setSelected:(BOOL)selected{
	_selected = selected;
	[super refreshState];
	
	if (!_shouldSetValue) return;
	
	NSDictionary *prefs = getPrefs();
	BKGCCModuleAction singleTapAction = intValueForKeyWithPrefs(@"moduleSingleTapAction", BKGCCModuleActionToggle, prefs);
	SBApplication *frontMostApp = [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
	
	switch (singleTapAction) {
		case BKGCCModuleActionOpenAppSettings:{
			NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"prefs:root=Bakgrunnur&path=Manage%%20Apps/%@", frontMostApp.bundleIdentifier]];
			[[UIApplication sharedApplication] _openURL:url];
			break;
		}
		case BKGCCModuleActionToggleApp:{
			if ([frontMostApp.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
			BOOL toggleVal = NO;
			NSDictionary *item = [self getItem:prefs ofIdentifier:frontMostApp.bundleIdentifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:nil];
			if (item){
				toggleVal = [item[@"enabled"] boolValue];
			}
			
			
			[self setPreferenceValue:@(!toggleVal) forKey:@"enabled" bundleIdentifier:frontMostApp.bundleIdentifier];
			CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
			break;
		}
		case BKGCCModuleActionToggleAppOnce:{
			if ([frontMostApp.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
			BOOL toggleVal = NO;
			NSDictionary *item = [self getItem:prefs ofIdentifier:frontMostApp.bundleIdentifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:nil];
			if (item){
				toggleVal = [item[@"enabled"] boolValue];
			}
			
			if (toggleVal){
				
			}else{
				BKGBakgrunnur *bakgrunnur = [NSClassFromString(@"BKGBakgrunnur") sharedInstance];
				
				BOOL enabledOnce = [bakgrunnur.grantedOnceIdentifiers containsObject:frontMostApp.bundleIdentifier];
				if (enabledOnce){
					[bakgrunnur.grantedOnceIdentifiers removeObject:frontMostApp.bundleIdentifier];
				}else{
					[bakgrunnur.grantedOnceIdentifiers removeObject:frontMostApp.bundleIdentifier];
					[bakgrunnur.grantedOnceIdentifiers addObject:frontMostApp.bundleIdentifier];
					
				}
			}
			break;
		}
		case BKGCCModuleActionExpandModule:{
			CCUIContentModuleContext *moduleContext = [[objc_getClass("CCUIContentModuleContext") alloc] initWithModuleIdentifier:@"com.udevs.bakgrunnurcc"];
			[[objc_getClass("CCUIModuleInstanceManager") sharedInstance] requestExpandModuleForContentModuleContext:moduleContext];
			break;
		}
		case BKGCCModuleActionDoNothing:
			break;
		case BKGCCModuleActionToggle:
		default:{
			setValueForKey(@"enabled", @(_selected));
			CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)RELOAD_SPECIFIERS_NOTIFICATION_NAME, NULL, NULL, YES);
			break;
		}
			
	}
}

@end

static void refreshModule(){
	CCUIModuleInstance* bkgModule = [[NSClassFromString(@"CCUIModuleInstanceManager") sharedInstance] instanceForModuleIdentifier:@"com.udevs.bakgrunnurcc"];
	[(BKGCCToggleModule *)bkgModule.module updateStateViaPreferences];
}

__attribute__((constructor))
static void init(void){
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)refreshModule, (CFStringRef)REFRESH_MODULE_NOTIFICATION_NAME, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	
}
