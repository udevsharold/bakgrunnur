#import "common.h"
#import "PrivateHeaders.h"
#import <dlfcn.h>
#import <objc/runtime.h>
#import "BKGBakgrunnur.h"
#import "BKGActivator.h"

@implementation BKGActivator
+(void)load{
    dlopen("/usr/lib/libactivator.dylib", RTLD_LAZY);
    if (objc_getClass("LAActivator")) { //libactivator is installed
        [self sharedInstance];
    }
}

+(id)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t token = 0;
    dispatch_once(&token, ^{
        sharedInstance = [self new];
    });
    return sharedInstance;
}

-(instancetype)init{
    if ((self = [super init]))
    {
        self.iconScale = 10;
        [self registerListeners];
    }
    return self;
}

-(void)registerListeners{
    LAActivator *la = [objc_getClass("LAActivator") sharedInstance];
    [la registerListener:self forName:@"bakgrunnur.enable"];
    [la registerListener:self forName:@"bakgrunnur.disable"];
    [la registerListener:self forName:@"bakgrunnur.toggle"];
    [la registerListener:self forName:@"bakgrunnur.enable.app"];
    [la registerListener:self forName:@"bakgrunnur.disable.app"];
    [la registerListener:self forName:@"bakgrunnur.toggle.app"];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName {
    return @"Bakgrunnur";
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName {
    if ([listenerName isEqualToString:@"bakgrunnur.enable"]){
        return @"Enable";
    }else if ([listenerName isEqualToString:@"bakgrunnur.disable"]){
        return @"Disable";
    }else if ([listenerName isEqualToString:@"bakgrunnur.toggle"]){
        return @"Toggle";
    }else if ([listenerName isEqualToString:@"bakgrunnur.enable.app"]){
        return @"Enable App";
    }else if ([listenerName isEqualToString:@"bakgrunnur.disable.app"]){
        return @"Disable App";
    }else if ([listenerName isEqualToString:@"bakgrunnur.toggle.app"]){
        return @"Toggle App";
    }
    return @"";
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
    if ([listenerName isEqualToString:@"bakgrunnur.enable"]){
        return @"Enable Bakgrunnur";
    }else if ([listenerName isEqualToString:@"bakgrunnur.disable"]){
        return @"Disable Bakgrunnur";
    }else if ([listenerName isEqualToString:@"bakgrunnur.disable"]){
        return @"Disable Bakgrunnur";
    }else if ([listenerName isEqualToString:@"bakgrunnur.toggle"]){
        return @"Toggle Bakgrunnur";
    }else if ([listenerName isEqualToString:@"bakgrunnur.disable.app"]){
        return @"Disable Current App";
    }else if ([listenerName isEqualToString:@"bakgrunnur.toggle.app"]){
        return @"Toggle current app";
    }
    return @"";
}

-(UIImage *)makeRoundedImage:(UIImage *)image radius:(float)radius scale:(float)scale{
    CALayer *imageLayer = [CALayer layer];
    imageLayer.frame = CGRectMake(0, 0, scale*self.iconScale,scale*self.iconScale);
    imageLayer.contents = (id) image.CGImage;
    
    imageLayer.masksToBounds = YES;
    imageLayer.cornerRadius = radius;
    
    //UIGraphicsBeginImageContext(image.size);
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(scale*self.iconScale,scale*self.iconScale), NO, scale);
    [imageLayer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *roundedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return roundedImage;
}

-(NSString *)bakgrunnurIconPath{
    return @"/Library/PreferenceBundles/BakgrunnurPrefs.bundle/Bakgrunnur@3x.png";
}

- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale{
    NSString *iconPath = [self bakgrunnurIconPath];
    UIImage *icon = [[UIImage alloc] init];
    NSData *iconData = [[NSData alloc] init];
    
    if (*scale == 3.0f){
        icon = [UIImage imageWithData:[NSData dataWithContentsOfFile:iconPath] scale:3.0f];
    }else if (*scale == 2.0f){
        icon = [UIImage imageWithData:[NSData dataWithContentsOfFile:iconPath] scale:2.0f];
    }else{
        icon = [UIImage imageWithData:[NSData dataWithContentsOfFile:iconPath] scale:1.0f];
    }
    
    icon = [self makeRoundedImage:icon radius:6 scale:*scale];
    
    iconData = [NSData dataWithData:UIImagePNGRepresentation(icon)];
    
    return iconData;
}

- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale{
    
    return [self activator:activator requiresIconDataForListenerName:listenerName scale:scale];
}

-(void)postTweakEnabledNotification{
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)REFRESH_MODULE_NOTIFICATION_NAME, NULL, NULL, YES);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)RELOAD_SPECIFIERS_NOTIFICATION_NAME, NULL, NULL, YES);
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName{
    NSMutableDictionary *prefs = nil;
    NSData *data = [NSData dataWithContentsOfFile:PREFS_PATH];
    if(data) {
        prefs = [[NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:nil] mutableCopy];
    } else{
        prefs = [@{} mutableCopy];
    }
    
    BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
    SBApplication *frontMostApp = [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
    if ([frontMostApp.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
    
    if ([listenerName isEqualToString:@"bakgrunnur.enable"]){
        prefs[@"enabled"] = @YES;
        [prefs writeToFile:PREFS_PATH atomically:NO];
        [self postTweakEnabledNotification];
    }else if ([listenerName isEqualToString:@"bakgrunnur.disable"]){
        prefs[@"enabled"] = @NO;
        [prefs writeToFile:PREFS_PATH atomically:NO];
        [self postTweakEnabledNotification];
    }else if ([listenerName isEqualToString:@"bakgrunnur.toggle"]){
        prefs[@"enabled"] = @(![bakgrunnur isEnabled]);
        [prefs writeToFile:PREFS_PATH atomically:NO];
        [self postTweakEnabledNotification];
    }else if ([listenerName isEqualToString:@"bakgrunnur.enable.app"]){
        [bakgrunnur setObject:@{@"enabled":@YES} bundleIdentifier:frontMostApp.bundleIdentifier];
    }else if ([listenerName isEqualToString:@"bakgrunnur.disable.app"]){
        [bakgrunnur setObject:@{@"enabled":@NO} bundleIdentifier:frontMostApp.bundleIdentifier];
    }else if ([listenerName isEqualToString:@"bakgrunnur.toggle.app"]){
        [bakgrunnur setObject:@{@"enabled":@(![bakgrunnur isEnabledForBundleIdentifier:frontMostApp.bundleIdentifier])} bundleIdentifier:frontMostApp.bundleIdentifier];
    }
}
@end
