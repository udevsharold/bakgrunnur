#include "../common.h"
#import "BakgrunnurCC.h"


@implementation BakgrunnurCC
static BOOL shouldSetValue = YES;

- (instancetype)init
{
    if ((self = [super init])) {
        _contentViewController = [[BakgrunnurModuleContentViewController alloc] init];
        _contentViewController.module = self;
        [self updateStateViaPreferences];
    }
    return self;
}

- (UIViewController*)contentViewController
{
    return _contentViewController;
}

-(void)updateState{
    NSMutableDictionary *prefs = [self getPrefs];
    _selected = prefs[@"enabled"] ?  [prefs[@"enabled"] boolValue] : YES;
}

-(void)updateStateViaPreferences{
    shouldSetValue = NO;
    NSMutableDictionary *prefs = [self getPrefs];
    _selected = prefs[@"enabled"] ?  [prefs[@"enabled"] boolValue] : YES;
    [self setSelected:_selected];
    [_contentViewController setSelected:_selected];
    shouldSetValue = YES;
}

//Return the icon of your module here
- (UIImage *)iconGlyph
{
    return [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
}

//Return the color selection color of your module here
- (UIColor *)selectedColor
{
    return [UIColor blueColor];
}

- (BOOL)isSelected
{
    return _selected;
}

-(NSMutableDictionary *)getPrefs{
    NSMutableDictionary *prefs = nil;
    NSData *data = [NSData dataWithContentsOfFile:PREFS_PATH];
    if(data) {
        prefs = [[NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:nil] mutableCopy];
    } else{
        prefs = [@{} mutableCopy];
    }
    return prefs;
}

- (void)setSelected:(BOOL)selected
{
    _selected = selected;
    
    [super refreshState];
    
    if (!shouldSetValue) return;
    
    NSMutableDictionary *prefs = [self getPrefs];
    
    if(_selected)
    {
        prefs[@"enabled"] = @YES;
        
    }
    else
    {
        prefs[@"enabled"] = @NO;
    }
    [prefs writeToFile:PREFS_PATH atomically:NO];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)RELOAD_SPECIFIERS_NOTIFICATION_NAME, NULL, NULL, YES);
}

@end

static void refreshModule(){
    CCUIModuleInstance* bkgModule = [[NSClassFromString(@"CCUIModuleInstanceManager") sharedInstance] instanceForModuleIdentifier:@"com.udevs.bakgrunnurcc"];
    [(BakgrunnurCC*)bkgModule.module updateStateViaPreferences];
}

__attribute__((constructor))
static void init(void)
{
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)refreshModule, (CFStringRef)REFRESH_MODULE_NOTIFICATION_NAME, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

}
