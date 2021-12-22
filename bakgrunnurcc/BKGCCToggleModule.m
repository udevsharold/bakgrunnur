#import "../common.h"
#import "BKGCCToggleModule.h"
#import "../BKGShared.h"

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

-(void)updateState{
	_selected = [valueForKey(@"enabled", @YES) boolValue];
}

-(void)updateStateViaPreferences{
	_shouldSetValue = NO;
	_selected = [valueForKey(@"enabled", @YES) boolValue];
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

-(void)setSelected:(BOOL)selected{
	_selected = selected;
	
	[super refreshState];
	
	if (!_shouldSetValue) return;
		
	setValueForKey(@"enabled", @(_selected));
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)RELOAD_SPECIFIERS_NOTIFICATION_NAME, NULL, NULL, YES);
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
