#include "../common.h"
#import "BakgrunnurCC.h"
#import "ControlCenterUIKit.h"
#import "../SpringBoard.h"
#import <ControlCenterUIKit/CCUIButtonModuleView.h>
#import "../BKGBakgrunnur.h"

#define CLEAN_GLYPH_TAG 88888

@interface UIApplication (Custom)
-(BOOL)_openURL:(id)arg1 ;
@end

@implementation BakgrunnurModuleContentViewController

- (void)viewWillLayoutSubviews{
    [super viewWillLayoutSubviews];
    
    if(self.expanded){
        [self.buttonView.subviews setValue:@YES forKeyPath:@"hidden"];
        if (![self.buttonView viewWithTag:CLEAN_GLYPH_TAG]){
            UIImageView *cleanGlyph = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Bakgrunnur-Fill-White" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil]];
            cleanGlyph.tag = CLEAN_GLYPH_TAG;
            [self.buttonView addSubview:cleanGlyph];
            [self.buttonView bringSubviewToFront:cleanGlyph];
        }else{
            UIView *cleanGlyph = [self.buttonView viewWithTag:CLEAN_GLYPH_TAG];
            cleanGlyph.hidden = NO;
        }
    }
    else{
        [self.buttonView.subviews setValue:@NO forKeyPath:@"hidden"];
        UIView *cleanGlyph = [self.buttonView viewWithTag:CLEAN_GLYPH_TAG];
        
        if (cleanGlyph){
            cleanGlyph.hidden = YES;
        }
    }
}



-(void)populateActions{
    if (@available(iOS 13.0, *)){
        
        SBApplication *frontMostApp = [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
        
        NSDictionary *prefs = [self.module getPrefs];
        
        BOOL toggleVal = NO;
        NSDictionary *item = [self getItem:prefs ofIdentifier:frontMostApp.bundleIdentifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:nil];
        if (item){
            toggleVal = [item[@"enabled"] boolValue];
        }
        
        //Open settings
        [self addActionWithTitle:(frontMostApp.bundleIdentifier?@"App Settings":@"Settings") subtitle:@"" glyph:[UIImage systemImageNamed:@"gear"] handler:^{
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"prefs:root=Bakgrunnur&path=Manage%%20Apps/%@", frontMostApp.bundleIdentifier]];
            [[UIApplication sharedApplication] _openURL:url];
        }];
        
        if (frontMostApp.bundleIdentifier){
            //Master enable/disable
            __weak typeof(self) weakSelf = self;
            [self addActionWithTitle:(toggleVal?@"Disable":@"Enable") subtitle:frontMostApp.displayName glyph:[UIImage systemImageNamed:@"hourglass"] handler:^{
                [weakSelf setPreferenceValue:@(!toggleVal) forKey:@"enabled" bundleIdentifier:frontMostApp.bundleIdentifier];
                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
            }];
            
            //Once enable/disable
            if (!toggleVal){
                BKGBakgrunnur *bakgrunnur = [NSClassFromString(@"BKGBakgrunnur") sharedInstance];
                BOOL enabledOnce = [bakgrunnur.grantedOnceIdentifiers containsObject:frontMostApp.bundleIdentifier];
                BOOL isPersistenceOnce = item[@"persistenceOnce"] ? [item[@"persistenceOnce"] boolValue] : NO;

                [self addActionWithTitle:([NSString stringWithFormat:@"%@ Once%@", enabledOnce?@"Disable":@"Enable", isPersistenceOnce?@" (Persistence)":@""]) subtitle:frontMostApp.displayName glyph:[UIImage systemImageNamed:@"1.circle"] handler:^{
                    if (!enabledOnce){
                        [bakgrunnur.grantedOnceIdentifiers removeObject:frontMostApp.bundleIdentifier];
                        [bakgrunnur.grantedOnceIdentifiers addObject:frontMostApp.bundleIdentifier];
                    }else{
                        [bakgrunnur.grantedOnceIdentifiers removeObject:frontMostApp.bundleIdentifier];
                    }
                }];
            }
        }
    }
    self.visibleMenuItems = self.actionsCount;
}

/*
 -(NSArray <CCUIMenuModuleItem *>*)fetchItems{
 NSMutableArray *items = [NSMutableArray array];
 CCUIMenuModuleItem *openSettingItem = [[NSClassFromString(@"CCUIMenuModuleItem") alloc] initWithTitle:@"Open Settings" identifier:@"OPEN_SETTINGS" handler:^{
 SBApplication *frontMostApp = [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
 NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"prefs:root=Bakgrunnur&path=Manage%%20Apps/%@", frontMostApp.bundleIdentifier]];
 [[UIApplication sharedApplication] _openURL:url];
 }];
 [items addObject:openSettingItem];
 return items;
 }
 */

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    self.glyphImage = [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    self.selectedGlyphImage = [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    self.selectedGlyphColor = [UIColor blueColor];
    
    self.title = @"Bakgrunnur";
    /*
     [self setFooterButtonTitle:@"Control Centre Settings" handler:^{
     NSURL *url = [NSURL URLWithString:@"prefs:root=ControlCenter&path=CUSTOMIZE_CONTROLS/Bakgrunnur"];
     [[UIApplication sharedApplication] _openURL:url];
     }];
     */
    return self;
}
/*
 - (CGFloat)preferredExpandedContentHeight{
 return CCUISliderExpandedContentModuleHeight();
 }
 */
- (CGFloat)preferredExpandedContentWidth{
    return CCUIDefaultExpandedContentModuleWidth();
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    
    
    self.buttonView.enabled = !self.expanded;
    
    [coordinator animateAlongsideTransition:^(id <UIViewControllerTransitionCoordinatorContext>context)
     {
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:nil];
}


- (void)buttonTapped:(id)arg1 forEvent:(id)arg2{
    if (self.rejectTap) return;
    BOOL newState = ![self isSelected];
    [self setSelected:newState];
    [self.module setSelected:newState];
}


- (BOOL)_canShowWhileLocked{
    return YES;
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
    
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", BAKGRUNNUR_IDENTIFIER];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    
    NSMutableArray *newSettings = [[NSMutableArray alloc] init];
    if (settings[@"enabledIdentifier"]) newSettings = [settings[@"enabledIdentifier"] mutableCopy];
    
    
    __block NSUInteger idx;
    NSMutableDictionary *item;
    item = [[self getItem:settings ofIdentifier:bundleIdentifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:^(NSUInteger index){
        idx = index;
    }] mutableCopy];
    
    if (!item) item = [[NSMutableDictionary alloc] init];
    
    if (item){
        [item setObject:value forKey:key];
    }else{
        [item setObject:value forKey:key];
    }
    [item setObject:bundleIdentifier forKey:@"identifier"];
    
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
}

-(BOOL)shouldBeginTransitionToExpandedContentModule{
    if (self.rejectTap) return NO;
    NSDictionary *prefs = [self.module getPrefs];
    int actionType = prefs[@"moduleAction"] ? [prefs[@"moduleAction"] intValue] : -1;
    SBApplication *frontMostApp = [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
    if (actionType == 0){
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"prefs:root=Bakgrunnur&path=Manage%%20Apps/%@", frontMostApp.bundleIdentifier]];
        [[UIApplication sharedApplication] _openURL:url];
    }else if (actionType == 1){
        if (frontMostApp.bundleIdentifier){
            [self setPreferenceValue:@YES forKey:@"enabled" bundleIdentifier:frontMostApp.bundleIdentifier];
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
        }
        self.rejectTap = YES;
        self.glyphImage = [UIImage imageNamed:@"hourglass" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
        self.selectedGlyphImage = [UIImage imageNamed:@"hourglass" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.glyphImage = [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
            self.selectedGlyphImage = [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
            
            self.rejectTap = NO;
            
        });
        //[[NSClassFromString(@"SBControlCenterController") sharedInstance] dismissAnimated:YES completion:nil];
    }else if (actionType == 2){
        if (frontMostApp.bundleIdentifier){
            [self setPreferenceValue:@NO forKey:@"enabled" bundleIdentifier:frontMostApp.bundleIdentifier];
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
        }
        self.rejectTap = YES;
        self.glyphImage = [UIImage imageNamed:@"hourglass.line" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
        self.selectedGlyphImage = [UIImage imageNamed:@"hourglass.line" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.glyphImage = [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
            self.selectedGlyphImage = [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
            
            self.rejectTap = NO;
            
        });
        //[[NSClassFromString(@"SBControlCenterController") sharedInstance] dismissAnimated:YES completion:nil];
    }else if (actionType == 3){
        if (frontMostApp.bundleIdentifier){
            BOOL toggleVal = NO;
            NSDictionary *item = [self getItem:prefs ofIdentifier:frontMostApp.bundleIdentifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:nil];
            if (item){
                toggleVal = [item[@"enabled"] boolValue];
            }
            
            
            [self setPreferenceValue:@(!toggleVal) forKey:@"enabled" bundleIdentifier:frontMostApp.bundleIdentifier];
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
            
            self.rejectTap = YES;
            self.glyphImage = [UIImage imageNamed:(toggleVal?@"hourglass.line":@"hourglass") inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
            self.selectedGlyphImage = [UIImage imageNamed:(toggleVal?@"hourglass.line":@"hourglass") inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.glyphImage = [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
                self.selectedGlyphImage = [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
                
                self.rejectTap = NO;
                
            });
        }
    }else if (actionType == 4){ //Enable Once
        if (frontMostApp.bundleIdentifier){
            BOOL toggleVal = NO;
            NSDictionary *item = [self getItem:prefs ofIdentifier:frontMostApp.bundleIdentifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:nil];
            if (item){
                toggleVal = [item[@"enabled"] boolValue];
            }
            
            if (toggleVal){
                //[[NSClassFromString(@"SBControlCenterController") sharedInstance] dismissAnimated:YES completion:nil];
                self.rejectTap = YES;
                [self shakeView:self.view completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        self.rejectTap = NO;
                    });
                }];
            }else{
                
                BKGBakgrunnur *bakgrunnur = [NSClassFromString(@"BKGBakgrunnur") sharedInstance];
                [bakgrunnur.grantedOnceIdentifiers removeObject:frontMostApp.bundleIdentifier];
                [bakgrunnur.grantedOnceIdentifiers addObject:frontMostApp.bundleIdentifier];
                
                //[self setPreferenceValue:@(!toggleVal) forKey:@"enabled" bundleIdentifier:frontMostApp.bundleIdentifier];
                //CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
                
                self.rejectTap = YES;
                self.glyphImage = [UIImage imageNamed:@"hourglass.one" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
                self.selectedGlyphImage = [UIImage imageNamed:@"hourglass.one" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    self.glyphImage = [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
                    self.selectedGlyphImage = [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
                    
                    self.rejectTap = NO;
                    
                });
            }
        }
        //[[NSClassFromString(@"SBControlCenterController") sharedInstance] dismissAnimated:YES completion:nil];
    }else if (actionType == 5){ //Disable Once
        if (frontMostApp.bundleIdentifier){
            BOOL toggleVal = NO;
            NSDictionary *item = [self getItem:prefs ofIdentifier:frontMostApp.bundleIdentifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:nil];
            if (item){
                toggleVal = [item[@"enabled"] boolValue];
            }
            
            if (toggleVal){
                //[[NSClassFromString(@"SBControlCenterController") sharedInstance] dismissAnimated:YES completion:nil];
                self.rejectTap = YES;
                [self shakeView:self.view completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        self.rejectTap = NO;
                    });
                }];
            }else{
                
                BKGBakgrunnur *bakgrunnur = [NSClassFromString(@"BKGBakgrunnur") sharedInstance];
                [bakgrunnur.grantedOnceIdentifiers removeObject:frontMostApp.bundleIdentifier];
                
                //[self setPreferenceValue:@(!toggleVal) forKey:@"enabled" bundleIdentifier:frontMostApp.bundleIdentifier];
                //CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
                
                self.rejectTap = YES;
                self.glyphImage = [UIImage imageNamed:@"hourglass.one.line" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
                self.selectedGlyphImage = [UIImage imageNamed:@"hourglass.one.line" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    self.glyphImage = [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
                    self.selectedGlyphImage = [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
                    
                    self.rejectTap = NO;
                    
                });
            }
        }
        //[[NSClassFromString(@"SBControlCenterController") sharedInstance] dismissAnimated:YES completion:nil];
    }else if (actionType == 6){ //Toggle Once
        if (frontMostApp.bundleIdentifier){
            BOOL toggleVal = NO;
            NSDictionary *item = [self getItem:prefs ofIdentifier:frontMostApp.bundleIdentifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:nil];
            if (item){
                toggleVal = [item[@"enabled"] boolValue];
            }
            
            if (toggleVal){
                //[[NSClassFromString(@"SBControlCenterController") sharedInstance] dismissAnimated:YES completion:nil];
                self.rejectTap = YES;
                [self shakeView:self.view completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        self.rejectTap = NO;
                    });
                }];
            }else{
                
                BKGBakgrunnur *bakgrunnur = [NSClassFromString(@"BKGBakgrunnur") sharedInstance];
                
                BOOL enabledOnce = [bakgrunnur.grantedOnceIdentifiers containsObject:frontMostApp.bundleIdentifier];
                if (enabledOnce){
                    [bakgrunnur.grantedOnceIdentifiers removeObject:frontMostApp.bundleIdentifier];
                }else{
                    [bakgrunnur.grantedOnceIdentifiers removeObject:frontMostApp.bundleIdentifier];
                    [bakgrunnur.grantedOnceIdentifiers addObject:frontMostApp.bundleIdentifier];
                    
                }
                
                //[self setPreferenceValue:@(!toggleVal) forKey:@"enabled" bundleIdentifier:frontMostApp.bundleIdentifier];
                //CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
                
                self.rejectTap = YES;
                self.glyphImage = [UIImage imageNamed:(enabledOnce?@"hourglass.one.line":@"hourglass.one") inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
                self.selectedGlyphImage = [UIImage imageNamed:(enabledOnce?@"hourglass.one.line":@"hourglass.one") inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    self.glyphImage = [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
                    self.selectedGlyphImage = [UIImage imageNamed:@"Bakgrunnur" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
                    
                    self.rejectTap = NO;
                    
                });
            }
        }
        //[[NSClassFromString(@"SBControlCenterController") sharedInstance] dismissAnimated:YES completion:nil];
    }else{
        [self populateActions];
        return YES;
    }
    [[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:UINotificationFeedbackTypeSuccess];
    return NO;
}

-(void)shakeView:(UIView *)sender completion:(void (^)())completionHandler{
    CABasicAnimation *shake = [CABasicAnimation animationWithKeyPath:@"position"];
    [shake setDuration:0.05];
    [shake setRepeatCount:2];
    [shake setAutoreverses:YES];
    [shake setFromValue:[NSValue valueWithCGPoint:
                         CGPointMake(sender.center.x - 5,sender.center.y)]];
    [shake setToValue:[NSValue valueWithCGPoint:
                       CGPointMake(sender.center.x + 5, sender.center.y)]];
    [sender.layer removeAllAnimations];
    [sender.layer addAnimation:shake forKey:@"position"];
    if (completionHandler){
        completionHandler();
    }
}


@end
