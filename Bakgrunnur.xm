#import "common.h"
#import "Shared.h"
#import "SpringBoard.h"
#import "BKGBakgrunnur.h"
#import "NSTask.h"
#include <pthread.h>
#include <mach/mach.h>
#import <dlfcn.h>
#include <objc/runtime.h>

BOOL enabled = YES;
NSDictionary *prefs;
NSArray *enabledIdentifier;
NSArray *allEntriesIdentifier;
SBFloatingDockView *floatingDockView;
double globalTimeSpan = 1800.0/2.0;
BOOL quickActionMaster = YES;
BOOL quickActionOnce = NO;
NSArray *persistenceOnce;

static BOOL firstInit = YES;
static long long preferredAccessoryType = 2;
static BOOL showIndicatorOnDock = NO;
static BOOL isFolderTransitioning = NO;

static NSString* frontMostAppBundleIdentifier(){
    if ([objc_getClass("SBMainWorkspace") _instanceIfExists]){
        SBApplication *frontMostApp = [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
        return frontMostApp.bundleIdentifier;
    }
    return nil;
}

static void sceneMovedToForeground(FBScene *scene, void (^completion)()){
    if (enabled){
        NSString *bundleIdentifier = scene.clientProcess.identity.embeddedApplicationIdentifier;
        
        BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
        if ([enabledIdentifier
             containsObject:bundleIdentifier] || [bakgrunnur.grantedOnceIdentifiers containsObject:bundleIdentifier]){
            //NSUInteger identifierIdx = [enabledIdentifier indexOfObject:bundleIdentifier];
            //BOOL isImmortal = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"retire"]) ? ([prefs[@"enabledIdentifier"][identifierIdx][@"retire"] intValue] > 1) : NO;
            //if (isImmortal){
            //[[BKGBakgrunnur sharedInstance].immortalIdentifiers removeObject:bundleIdentifier];
            //}else{
            /*
             if ([bakgrunnur.queuedIdentifiers containsObject:bundleIdentifier] || [bakgrunnur.immortalIdentifiers containsObject:bundleIdentifier] || [bakgrunnur.advancedMonitoringIdentifiers containsObject:bundleIdentifier]){
             [bakgrunnur.grantedOnceIdentifiers removeObject:bundleIdentifier];
             }
             */
            [bakgrunnur invalidateQueue:bundleIdentifier];
            
            
            NSUInteger identifierIdx = [allEntriesIdentifier indexOfObject:bundleIdentifier];
            BOOL aggressiveAssertion = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"aggressiveAssertion"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"aggressiveAssertion"] boolValue] : YES;
            [bakgrunnur acquireAssertionIfNecessary:scene aggressive:aggressiveAssertion];
            
            HBLogDebug(@"Reset expiration for %@", bundleIdentifier);
        }
        if (completion){
            completion();
        }
    }
    
}

static void sceneMovedToBackground(FBScene *scene, void (^completion)()){
    
    if (enabled){
        NSString *bundleIdentifier = scene.clientProcess.identity.embeddedApplicationIdentifier;
        
        BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
        //HBLogDebug(@"bakgrunnur.grantedOnceIdentifiers: %@", bakgrunnur.grantedOnceIdentifiers);
        BOOL alreadyQueued = [bakgrunnur.queuedIdentifiers containsObject:bundleIdentifier] || [bakgrunnur.immortalIdentifiers containsObject:bundleIdentifier] || [bakgrunnur.advancedMonitoringIdentifiers containsObject:bundleIdentifier];
        
        if (([enabledIdentifier containsObject:bundleIdentifier] || [bakgrunnur.grantedOnceIdentifiers containsObject:bundleIdentifier]) && (![bakgrunnur.retiringIdentifiers containsObject:bundleIdentifier]) && scene.valid && !alreadyQueued){
            
            NSUInteger identifierIdx = [allEntriesIdentifier indexOfObject:bundleIdentifier];
            BOOL isImmortal = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"retire"]) ? ([prefs[@"enabledIdentifier"][identifierIdx][@"retire"] intValue] == 2) : NO;
            BOOL isAdvancedMonitoring = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"retire"]) ? ([prefs[@"enabledIdentifier"][identifierIdx][@"retire"] intValue] == 3) : NO;
            BOOL enabledAppNotifications = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"] boolValue] : NO;
            //[bakgrunnur.grantedOnceIdentifiers removeObject:bundleIdentifier];
            [bakgrunnur invalidateQueue:bundleIdentifier];
            if (isImmortal || isAdvancedMonitoring){
                [bakgrunnur.immortalIdentifiers addObject:bundleIdentifier];
                [bakgrunnur updateLabelAccessory:bundleIdentifier];
                NSString *advBannerVerbose = @"Advanced";
                if (isAdvancedMonitoring){
                    NSMutableArray *advBannerVerboseArray = [NSMutableArray array];
                    BOOL cpuUsageEnabled = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"cpuUsageEnabled"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"cpuUsageEnabled"] boolValue] : NO;
                    if (cpuUsageEnabled){
                        [advBannerVerboseArray addObject:@"C"];
                    }
                    int systemCallsType = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"systemCallsType"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"systemCallsType"] intValue] : 0;
                    if (systemCallsType > 0){
                        [advBannerVerboseArray addObject:@"S"];
                    }
                    int networkTransmissionType = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"networkTransmissionType"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"networkTransmissionType"] intValue] : 0;
                    if (networkTransmissionType > 0){
                        [advBannerVerboseArray addObject:@"N"];
                    }
                    if (advBannerVerboseArray.count > 0){
                        advBannerVerbose = [advBannerVerboseArray componentsJoinedByString:@""];
                        advBannerVerbose = [NSString stringWithFormat:@"Advanced (%@)", advBannerVerbose];
                    }
                    [bakgrunnur.advancedMonitoringIdentifiers addObject:bundleIdentifier];
                    [bakgrunnur startAdvancedMonitoringWithInterval:globalTimeSpan];
                }
                [bakgrunnur presentBannerWithSubtitleIfPossible:isImmortal?@"Immortal":advBannerVerbose forBundle:bundleIdentifier];
            }else{
                double expiration = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"expiration"] && [prefs[@"enabledIdentifier"][identifierIdx][@"expiration"] length] > 0) ? [prefs[@"enabledIdentifier"][identifierIdx][@"expiration"] doubleValue] : defaultExpirationTime;
                expiration = expiration < 0 ? defaultExpirationTime : expiration;
                expiration = expiration == 0 ? 1 : expiration;
                
                HBLogDebug(@"expiration %f", expiration);
                
                [bakgrunnur queueProcess:bundleIdentifier  softRemoval:(identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"retire"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"retire"] boolValue] : YES expirationTime:expiration];
            }
            
            if (enabledAppNotifications){
                [[%c(UNSUserNotificationServer) sharedInstance] _didChangeApplicationState:4 forBundleIdentifier:bundleIdentifier];
            }
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                if ([bakgrunnur.darkWakeIdentifiers containsObject:bundleIdentifier] || ([bakgrunnur.grantedOnceIdentifiers containsObject:bundleIdentifier] && [bakgrunnur.dormantDarkWakeIdentifiers containsObject:bundleIdentifier])){
                    [bakgrunnur updateDarkWakeState];
                }
            });
            
            
            HBLogDebug(@"Queued %@ for invalidation", bundleIdentifier);
        }else{
            [bakgrunnur.retiringIdentifiers removeObject:bundleIdentifier];
        }
        if (completion){
            completion();
        }
    }
}

static void applySceneWithSettings(FBScene *scene, UIMutableApplicationSceneSettings *settings){
    if (enabled){
        
        NSString *bundleIdentifier = scene.clientProcess.identity.embeddedApplicationIdentifier;
        NSString *frontMostAppID = frontMostAppBundleIdentifier();
        
        BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
        int pid = [bakgrunnur pidForBundleIdentifier:bundleIdentifier];
        
        NSUInteger identifierIdx = [allEntriesIdentifier indexOfObject:bundleIdentifier];
        
        BOOL isiOS14 = NO;
        if (@available(iOS 14.0, *)){
            isiOS14 = YES;
        }
        
        
        if (([enabledIdentifier containsObject:bundleIdentifier] || [bakgrunnur.grantedOnceIdentifiers containsObject:bundleIdentifier]) && ![bakgrunnur.retiringIdentifiers containsObject:bundleIdentifier]  && (pid > 0)){
            
            HBLogDebug(@"ENTER");
            BOOL enabledAppNotifications = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"] boolValue] : NO;
            
            BOOL isFrontMost = NO;
            BOOL isUILocked = [[%c(SBLockScreenManager) sharedInstance] isUILocked];
            
            if ([objc_getClass("SBMainWorkspace") _instanceIfExists]){
                isFrontMost = [frontMostAppID isEqualToString:bundleIdentifier];
                if (isUILocked){
                    isFrontMost = NO;
                }
                if (isFrontMost && frontMostAppID && !isUILocked){
                    
                    BOOL alreadyQueued = [bakgrunnur.queuedIdentifiers containsObject:frontMostAppID] || [bakgrunnur.immortalIdentifiers containsObject:frontMostAppID] || [bakgrunnur.advancedMonitoringIdentifiers containsObject:frontMostAppID];
                    
                    BOOL revokedOnceToken = NO;
                    if (alreadyQueued && ![persistenceOnce containsObject:frontMostAppID]){
                        [bakgrunnur.grantedOnceIdentifiers removeObject:frontMostAppID];
                        [bakgrunnur cleanAssertionsForBundle:frontMostAppID];
                        [bakgrunnur.userInitiatedIdentifiers removeObject:frontMostAppID];
                        revokedOnceToken = YES;
                        HBLogDebug(@"Revoked \"Once\" token for %@", frontMostAppID);
                    }
                    
                    [bakgrunnur invalidateQueue:frontMostAppID];
                    
                    if (isiOS14 && !revokedOnceToken){
                        if (![bakgrunnur.userInitiatedIdentifiers containsObject:frontMostAppID]){
                            HBLogDebug(@"User initiated launch %@", frontMostAppID);
                            [bakgrunnur.userInitiatedIdentifiers addObject:frontMostAppID];
                        }
                    }
                    
                    if (enabledAppNotifications){
                        [[%c(UNSUserNotificationServer) sharedInstance] _didChangeApplicationState:8 forBundleIdentifier:frontMostAppID];
                    }
                    
                    if (isiOS14 && !revokedOnceToken){
                        BOOL aggressiveAssertion = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"aggressiveAssertion"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"aggressiveAssertion"] boolValue] : YES;
                        [bakgrunnur acquireAssertionIfNecessary:scene aggressive:aggressiveAssertion];
                    }
                    HBLogDebug(@"Reset expiration for %@", frontMostAppID);
                }else if (!isUILocked && !isFrontMost){
                    if (isiOS14){
                        if ([bakgrunnur.userInitiatedIdentifiers containsObject:bundleIdentifier]){
                            //[bakgrunnur.userInitiatedIdentifiers addObject:bundleIdentifier];
                            //assert(NO);
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                                sceneMovedToBackground(scene, nil);
                            });
                            
                        }
                        
                    }
                }
            }
            
            
            if (isiOS14 && isUILocked && [bakgrunnur.userInitiatedIdentifiers containsObject:bundleIdentifier]){
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    sceneMovedToBackground(scene, nil);
                });
            }
            
            BOOL userInitiated = YES;
            if (isiOS14 && ![bakgrunnur.userInitiatedIdentifiers containsObject:bundleIdentifier]){
                userInitiated = NO;
            }
            
            if ([settings respondsToSelector:@selector(setForeground:)] && userInitiated){
                
                [settings setForeground:YES];
                [settings setBackgrounded:NO];
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    if ([bakgrunnur.darkWakeIdentifiers containsObject:bundleIdentifier]){
                        [bakgrunnur updateDarkWakeState];
                    }
                });
                
                //NSUInteger identifierIdx = [allEntriesIdentifier indexOfObject:bundleIdentifier];
                // BOOL enabledAppNotifications = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"] boolValue] : YES;
                //[settings setPrefersProcessTaskSuspensionWhileSceneForeground:enabledAppNotifications?!isFrontMost:[settings prefersProcessTaskSuspensionWhileSceneForeground]];
                
                HBLogDebug(@"Deferred backgrounding for %@", bundleIdentifier);
            }
            
        }else if (([enabledIdentifier containsObject:bundleIdentifier] || (![persistenceOnce containsObject:bundleIdentifier] && [bakgrunnur.grantedOnceIdentifiers containsObject:bundleIdentifier])) && !(pid > 0)){
            [bakgrunnur.grantedOnceIdentifiers removeObject:bundleIdentifier];
            [bakgrunnur cleanAssertionsForBundle:bundleIdentifier];
            [bakgrunnur invalidateQueue:bundleIdentifier];
        }
        //else if (![enabledIdentifier containsObject:bundleIdentifier] && ([bakgrunnur.queuedIdentifiers containsObject:bundleIdentifier] || [bakgrunnur.immortalIdentifiers containsObject:bundleIdentifier]){
        //[bakgrunnur.retiringIdentifiers removeObject:bundleIdentifier];
        //}
    }
}

/*
 %hook SBMainSwitcherViewController
 
 -(void)_deleteAppLayout:(SBAppLayout *)appLayout forReason:(long long)arg2{
 HBLogDebug(@"_deleteAppLayout: %@ ** %lld", ((SBDisplayItem *)(appLayout.rolesToLayoutItemsMap[@1])).bundleIdentifier, arg2);
 if ([((SBDisplayItem *)(appLayout.rolesToLayoutItemsMap[@1])).bundleIdentifier isEqualToString:@"com.atebits.Tweetie2"]){
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
 [(SBGridSwitcherViewController *)(self.contentViewController) _updateVisibleItems];
 });
 return;
 }
 %orig;
 }
 %end
 
 %hook FBApplicationProcess
 -(void)killForReason:(long long)arg1 andReport:(BOOL)arg2 withDescription:(id)arg3 completion:(id)arg4{
 HBLogDebug(@"killForReason: %@", self.bundleIdentifier);
 if ([self.bundleIdentifier isEqualToString:@"com.atebits.Tweetie2"]){
 return;
 }
 %orig;
 }
 %end
 */

%hook SBFloatingDockView
-(id)initWithFrame:(CGRect)arg1{
    return floatingDockView = %orig;
}
%end

%hook SBApplication
-(void)_didExitWithContext:(id)arg1{
    %orig;
    if (enabled){
        BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
        if ([enabledIdentifier containsObject:self.bundleIdentifier] || [bakgrunnur.grantedOnceIdentifiers containsObject:self.bundleIdentifier]){
            [bakgrunnur.grantedOnceIdentifiers removeObject:self.bundleIdentifier];
            [bakgrunnur invalidateQueue:self.bundleIdentifier];
            HBLogDebug(@"_didExitWithContext: %@", self.bundleIdentifier);
            
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            if ([bakgrunnur.darkWakeIdentifiers containsObject:self.bundleIdentifier]){
                [bakgrunnur updateDarkWakeState];
            }
        });
        
    }
}
%end

%hook SBFolderView
-(void)willTransitionAnimated:(BOOL)arg1 withSettings:(id)arg2{
    %orig;
    if (enabled && !firstInit){
        isFolderTransitioning = YES;
    }
}

-(void)didTransitionAnimated:(BOOL)arg1{
    %orig;
    if (enabled && !firstInit){
        isFolderTransitioning = NO;
        //dispatch_async(dispatch_get_main_queue(), ^ {
        BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
        if ([bakgrunnur.pendingAccessoryUpdateFolderID containsObject:self.folder.uniqueIdentifier]/* && !self.folder.open*/){
            [self.folder.icon _notifyAccessoriesDidUpdate];
            [bakgrunnur.pendingAccessoryUpdateFolderID removeObject:self.folder.uniqueIdentifier];
        }
        //});
    }
}
%end

%hook SBIconView
-(long long)currentLabelAccessoryType{
    //long long type = %orig;
    //HBLogDebug(@"labelHidden %@", ?@"YES":@"NO");
    //HBLogDebug(@"folder: %@", self.folderIcon);
    long long labelType = %orig;
    if (enabled && preferredAccessoryType > 0){
        BOOL isInFolder = NO;
        BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
        if ([self folder]){
            NSMutableSet *queuedIdentifiersSet = [NSMutableSet setWithArray:bakgrunnur.queuedIdentifiers];
            NSMutableSet *immortalIdentifiersSet = [NSMutableSet setWithArray:bakgrunnur.immortalIdentifiers];
            NSSet *currentFolderSet = [NSSet setWithArray:[[self folder].icons valueForKey:@"applicationBundleID"]];
            [queuedIdentifiersSet intersectSet:currentFolderSet];
            [immortalIdentifiersSet intersectSet:currentFolderSet];
            NSArray *queuedIdentifiersInFolderSet = [queuedIdentifiersSet allObjects];
            NSArray *immortalIdentifiersInFolderSet = [immortalIdentifiersSet allObjects];
            if ([queuedIdentifiersInFolderSet count] > 0 || [immortalIdentifiersInFolderSet count] > 0){
                isInFolder = YES;
            }
        }
        
        BOOL isInDock = NO;
        if (@available(iOS 14.0, *)){
            isInDock = [self.location containsString:@"Dock"];
        }else{
            isInDock = self.inDock;
        }
        
        if (([bakgrunnur.queuedIdentifiers containsObject:[self.icon applicationBundleID]] || [bakgrunnur.immortalIdentifiers containsObject:[self.icon applicationBundleID]] || (isInFolder && !isFolderTransitioning)) && (!self.labelHidden || (isInDock && showIndicatorOnDock))){
            
            if (isInFolder && ![bakgrunnur.pendingAccessoryUpdateFolderID containsObject:[self folder].uniqueIdentifier]){
                [bakgrunnur.pendingAccessoryUpdateFolderID addObject:[self folder].uniqueIdentifier];
            }
            return preferredAccessoryType; //1-bule, 2-yellow, 3-offload, 4-hourglass
        }else if (isInFolder && ![bakgrunnur.pendingAccessoryUpdateFolderID containsObject:[self folder].uniqueIdentifier]){ //fix folder dot not updating
            [bakgrunnur.pendingAccessoryUpdateFolderID addObject:[self folder].uniqueIdentifier];
            return preferredAccessoryType; //1-bule, 2-yellow, 3-offload, 4-hourglass
        }else if (labelType <= 2 && preferredAccessoryType == 2){
            return 0;
        }
    }
    return labelType;
}

-(NSArray *)applicationShortcutItems{
    NSArray *ret = %orig;
    if (enabled && (quickActionMaster || quickActionOnce)){
        NSString *bundleIdentifier;
        if ([self respondsToSelector:@selector(applicationBundleIdentifier)]) {
            bundleIdentifier = [self applicationBundleIdentifier]; //iOS 13.1.3
        } else if ([self respondsToSelector:@selector(applicationBundleIdentifierForShortcuts)]) {
            bundleIdentifier = [self applicationBundleIdentifierForShortcuts]; //iOS 13.2.2
        }
        if (bundleIdentifier){
            NSArray<SBSApplicationShortcutItem*> *stackedShortcuts = [[BKGBakgrunnur sharedInstance] stackBakgrunnurShortcut:ret bundleIdentifier:bundleIdentifier];
            return stackedShortcuts;
        }
    }
    return ret;
}

+(void)activateShortcut:(SBSApplicationShortcutItem *)shortcut withBundleIdentifier:(NSString *)bundleIdentifier forIconView:(id)arg3{
    if (enabled && (quickActionMaster || quickActionOnce)){
        BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
        if (bundleIdentifier && [[shortcut type] isEqualToString:@"BakgrunnurShortcut"]) {
            if ([shortcut.localizedSubtitle isEqualToString:@"Disable"]){
                [bakgrunnur.grantedOnceIdentifiers removeObject:bundleIdentifier];
                [bakgrunnur setObject:@{@"enabled":@NO} bundleIdentifier:bundleIdentifier];
                return;
            }else if (bundleIdentifier && [shortcut.localizedSubtitle isEqualToString:@"Enable"]){
                [bakgrunnur.grantedOnceIdentifiers removeObject:bundleIdentifier];
                [bakgrunnur setObject:@{@"enabled":@YES} bundleIdentifier:bundleIdentifier];
            }else if (bundleIdentifier && [shortcut.localizedSubtitle containsString:@"Enable Once"]){
                [bakgrunnur.grantedOnceIdentifiers removeObject:bundleIdentifier];
                [bakgrunnur.grantedOnceIdentifiers addObject:bundleIdentifier];
            }else if (bundleIdentifier && [shortcut.localizedSubtitle containsString:@"Disable Once"]){
                //[bakgrunnur.grantedOnceIdentifiers removeObject:bundleIdentifier];
                [bakgrunnur invalidateQueue:bundleIdentifier];
                [bakgrunnur _retireScene:bundleIdentifier];
                return;
            }
        }
    }
    %orig;
}

%end

/*
 %hook UNSUserNotificationServer
 /*
 -(void)_didChangeApplicationState:(unsigned)arg1 forBundleIdentifier:(NSString *)bundleIdentifier{
 HBLogDebug(@"_didChangeApplicationState: %@ ** %u", bundleIdentifier, arg1);
 if (enabled){
 NSUInteger identifierIdx = [allEntriesIdentifier indexOfObject:bundleIdentifier];
 
 BOOL enabledAppNotifications = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"] boolValue] : NO;
 BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
 
 if (!(enabledAppNotifications && ([enabledIdentifier containsObject:bundleIdentifier]) && ([bakgrunnur.queuedIdentifiers containsObject:bundleIdentifier] || [bakgrunnur.immortalIdentifiers containsObject:bundleIdentifier]))){
 HBLogDebug(@"don'r send ");
 return %orig;
 }
 
 if (enabledAppNotifications) HBLogDebug(@"please sned");
 }
 %orig;
 }
 
 /*
 -(BOOL)isApplicationForeground:(NSString *)bundleIdentifier{
 HBLogDebug(@"UNSUserNotificationServer: %@", bundleIdentifier);
 if (enabled){
 NSUInteger identifierIdx = [allEntriesIdentifier indexOfObject:bundleIdentifier];
 BOOL enabledAppNotifications = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"] boolValue] : NO;
 BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
 if (enabledAppNotifications && ([enabledIdentifier containsObject:bundleIdentifier]) && ([bakgrunnur.queuedIdentifiers containsObject:bundleIdentifier] || [bakgrunnur.immortalIdentifiers containsObject:bundleIdentifier])){
 __block BOOL isFrontMost = YES;
 dispatch_sync(dispatch_get_main_queue(), ^{
 isFrontMost = [bakgrunnur isFrontMost:bundleIdentifier];
 });
 if (!isFrontMost){
 return NO;
 }
 }
 }
 return %orig;
 }
 
 %end
 
 
 %hook NCNotificationDispatcher
 -(BOOL)_shouldPostNotificationRequest:(NCNotificationRequest *)req{
 HBLogDebug(@"_shouldPostNotificationRequest: %@", req);
 if (enabled){
 NSUInteger identifierIdx = [allEntriesIdentifier indexOfObject:req.sectionIdentifier];
 BOOL enabledAppNotifications = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotificatio ns"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"] boolValue] : NO;
 BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
 if (enabledAppNotifications && ([enabledIdentifier containsObject:req.sectionIdentifier]) && ([bakgrunnur.queuedIdentifiers containsObject:req.sectionIdentifier] || [bakgrunnur.immortalIdentifiers containsObject:req.sectionIdentifier])){
 //__block BOOL isFrontMost = YES;
 //dispatch_sync(dispatch_get_main_queue(), ^{
 BOOL isFrontMost = [bakgrunnur isFrontMost:req.sectionIdentifier];
 //});
 if (!isFrontMost){
 return YES;
 }
 }
 }
 return %orig;
 }
 %end
 */


//cydia
/*
 %hook FBScene
 -(void)updateSettings:(UIMutableApplicationSceneSettings *)settings withTransitionContext:(UIApplicationSceneTransitionContext *)context completion:(id)completion{
 if (([enabledIdentifier containsObject:self.clientProcess.identity.embeddedApplicationIdentifier])){
 FBSceneManager *sceneManager  = [%c(FBSceneManager) sharedInstance];
 [sceneManager _noteSceneMovedToBackground:self];
 return;
 
 }
 %orig;
 }
 %end
 */

%group iOS13
%hook FBSceneManager
-(void)_noteSceneMovedToForeground:(FBScene *)scene{
    //HBLogDebug(@"_noteSceneMovedToForeground: %@", scene);
    %orig;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        sceneMovedToForeground(scene, nil);
    });
    
}

-(void)_noteSceneMovedToBackground:(FBScene *)scene{
    //HBLogDebug(@"_noteSceneMovedToBackground: %@", [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication]);
    %orig;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        sceneMovedToBackground(scene, nil);
    });
    
}
%end
%end


%hook FBSceneManager
-(void)_applyMutableSettings:(UIMutableApplicationSceneSettings *)settings toScene:(FBScene *)scene withTransitionContext:(id)transitionContext completion:(/*^block*/id)arg4{
    applySceneWithSettings(scene, settings);
    %orig;
}
%end

/*
//iOS 14 (needed else mediaserverd will try to invalidate the assertion - video is playing but no sound), maybe iOS 13?
%hook RBSConnection
-(BOOL)invalidateAssertion:(RBSAssertion *)assertion error:(NSError **)error{
    if (enabled){
        SBApplicationController *sbAppController = [objc_getClass("SBApplicationController") sharedInstanceIfExists];
        if (sbAppController){
            SBApplication *sbApp = [sbAppController applicationWithPid:assertion.target.processIdentifier.pid];
            NSString *bundleIdentifier = sbApp.bundleIdentifier;
            BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
            
            if (([enabledIdentifier containsObject:bundleIdentifier] || [bakgrunnur.grantedOnceIdentifiers containsObject:bundleIdentifier]) && ![bakgrunnur.retiringAssertionIdentifiers containsObject:bundleIdentifier] && [bakgrunnur.userInitiatedIdentifiers containsObject:bundleIdentifier]){
                HBLogDebug(@"Deferred invalidation of assertion for %@", bundleIdentifier);
                if (error){
                    *error = nil;
                }
                return NO;
            }else if ([bakgrunnur.retiringAssertionIdentifiers containsObject:bundleIdentifier]){
                [bakgrunnur fireAssertionRetiring:bundleIdentifier delay:0.3];
            }
        }
    }
    return %orig;
}
%end
*/
/*
%hook RBDaemon
-(void)assertionManager:(id)arg1 didInvalidateAssertions:(id)arg2{
    HBLogDebug(@"_clientInvalidateWithError");
    return NO;
}
%end
*/

/*
 %hook SpringBoard
 -(void)frontDisplayDidChange:(id)display{
 %orig;
 
 if ([display isKindOfClass:[objc_getClass("SBApplication") class]]){
 HBLogDebug(@"frontDisplayDidChange: %@", display);
 NSString *identifier = [display bundleIdentifier];
 if (![identifier isEqualToString:currentApp]){
 FBSceneManager *sceneManager  = [objc_getClass("FBSceneManager") sharedInstance];
 NSMutableDictionary *scenesByID = [sceneManager valueForKey:@"_scenesByID"];
 [scenesByID enumerateKeysAndObjectsUsingBlock:^(NSString *sceneID, FBScene *scene, BOOL *stop) {
 if ([currentApp isEqualToString:scene.clientProcess.identity.embeddedApplicationIdentifier]) {
 sceneMovedToBackground(scene, nil);
 *stop = YES;
 }
 }];
 }
 currentApp = identifier;
 }else{
 if (currentApp){
 FBSceneManager *sceneManager  = [objc_getClass("FBSceneManager") sharedInstance];
 NSMutableDictionary *scenesByID = [sceneManager valueForKey:@"_scenesByID"];
 [scenesByID enumerateKeysAndObjectsUsingBlock:^(NSString *sceneID, FBScene *scene, BOOL *stop) {
 if ([currentApp isEqualToString:scene.clientProcess.identity.embeddedApplicationIdentifier]) {
 sceneMovedToBackground(scene, nil);
 *stop = YES;
 }
 }];
 }
 currentApp = nil;
 }
 }
 %end
 */

static NSArray *getArrayWithFormat(NSString *keyName, NSString *identifier, NSString *format){
    NSArray *array = [prefs[keyName] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:format]];
    NSArray *filteredArray = [array valueForKey:identifier];
    return filteredArray;
}

static NSArray *getEnabledArray(BOOL enabled){
    return getArrayWithFormat(@"enabledIdentifier", @"identifier", enabled ? @"enabled = YES" : @"enabled = NO");
}

static NSArray *getPersistenceOnceArray(){
    return getArrayWithFormat(@"enabledIdentifier", @"identifier", @"persistenceOnce = YES");
}

static NSArray *getAllEntries(NSString *keyName, NSString *keyIdentifier){
    
    NSArray *arrayWithEventID = [prefs[keyName] valueForKey:keyIdentifier];
    return arrayWithEventID;
}

static void reloadPrefs(){
    prefs = nil;
    NSData *data = [NSData dataWithContentsOfFile:PREFS_PATH];
    if (data){
        prefs = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:nil];
    }else{
        prefs = @{};
    }
    
    enabled = prefs[@"enabled"] ?  [prefs[@"enabled"] boolValue] : YES;
    quickActionMaster = prefs[@"quickActionMaster"] ?  [prefs[@"quickActionMaster"] boolValue] : YES;
    quickActionOnce = prefs[@"quickActionOnce"] ?  [prefs[@"quickActionOnce"] boolValue] : NO;
    persistenceOnce = getPersistenceOnceArray();
    
    BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
    
    if (@available(iOS 14.0, *)){
        bakgrunnur.presentBanner = prefs[@"presentBanner"] ? [prefs[@"presentBanner"] boolValue] : YES;
    }
    
    if (prefs && [prefs[@"enabledIdentifier"] firstObject] != nil){
        enabledIdentifier = getEnabledArray(YES);
        allEntriesIdentifier = getAllEntries(@"enabledIdentifier", @"identifier");
        if (!firstInit){
            NSMutableArray *disabledIdentifier = [getEnabledArray(NO) mutableCopy];
            [disabledIdentifier removeObjectsInArray:bakgrunnur.grantedOnceIdentifiers];
            NSMutableArray *reallyDisabledIdentifier = [NSMutableArray array];
            for (NSString *queuedIdentifier in disabledIdentifier){
                if ([bakgrunnur isQueued:queuedIdentifier]){
                    [reallyDisabledIdentifier addObject:queuedIdentifier];
                }
            }
            [bakgrunnur invalidateAllQueuesIn:reallyDisabledIdentifier];
        }
    }else if (prefs && ([prefs count] == 0)){
        enabledIdentifier = @[];
        allEntriesIdentifier = @[];
    }
    
    if (!enabled){
        [bakgrunnur invalidateAllQueues];
        [bakgrunnur notifySleepingState:YES];
        [bakgrunnur.grantedOnceIdentifiers removeAllObjects];
        bakgrunnur.sleepingState = 0;
    }
    
    
    double oldGlobalTimeSpan = globalTimeSpan;
    
    preferredAccessoryType = prefs[@"preferredAccessoryType"] ? [prefs[@"preferredAccessoryType"] longLongValue] : 2;
    showIndicatorOnDock = prefs[@"showIndicatorOnDock"] ? [prefs[@"showIndicatorOnDock"] boolValue] : YES;
    //showForceTouchShortcut = prefs[@"showForceTouchShortcut"] ? [prefs[@"showForceTouchShortcut"] boolValue] : YES;
    globalTimeSpan = (prefs[@"timeSpan"] && [prefs[@"timeSpan"] length] > 0) ? [prefs[@"timeSpan"] doubleValue]/2.0 : 1800.0/2.0;
    globalTimeSpan = globalTimeSpan <= 0.0 ? 1.0 : globalTimeSpan;
    
    
    if (enabled){
        [bakgrunnur update];
        
        NSUInteger idx = 0;
        for (NSString *identifier in allEntriesIdentifier){
            if ([enabledIdentifier containsObject:identifier]){
                BOOL enabledAppNotifications = prefs[@"enabledIdentifier"][idx][@"enabledAppNotifications"] ? [prefs[@"enabledIdentifier"][idx][@"enabledAppNotifications"] boolValue] : NO;
                [[%c(UNSUserNotificationServer) sharedInstance] _didChangeApplicationState:enabledAppNotifications?4:8 forBundleIdentifier:identifier];
            }
            idx++;
        }
        
        if (globalTimeSpan != oldGlobalTimeSpan){
            if (bakgrunnur.advancedMonitoringTimer){
                [bakgrunnur.advancedMonitoringTimer invalidate];
                bakgrunnur.advancedMonitoringTimer = nil;
                [bakgrunnur startAdvancedMonitoringWithInterval:globalTimeSpan];
            }
            HBLogDebug(@"Restart monitoring timer based on new time span: %lf", globalTimeSpan);
        }
        
    }
    
    //HBLogDebug(@"%@",prefs[@"enabledIdentifier"]);
    //if (!rbProcessState) rbProcessState = [[NSMutableDictionary alloc] init];
}

static void resetAll(){
    [[BKGBakgrunnur sharedInstance] invalidateAllQueues];
}

static void cliRequest(){
    
    reloadPrefs();
    BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
    NSDictionary *pending = prefs[@"pendingRequest"];
    if (pending){
        if (pending[@"retire"] && [pending[@"retire"] boolValue]){
            if (pending[@"expiration"]){
                [bakgrunnur.grantedOnceIdentifiers removeObject:pending[@"identifier"]];
                [bakgrunnur invalidateQueue:pending[@"identifier"]];
                [bakgrunnur queueProcess:pending[@"identifier"] softRemoval:YES expirationTime:[pending[@"expiration"] doubleValue]];
            }else{
                [bakgrunnur _retireScene:pending[@"identifier"]];
            }
        }
        if (pending[@"remove"] && [pending[@"remove"] boolValue]){
            if (pending[@"expiration"]){
                [bakgrunnur.grantedOnceIdentifiers removeObject:pending[@"identifier"]];
                [bakgrunnur invalidateQueue:pending[@"identifier"]];
                [bakgrunnur queueProcess:pending[@"identifier"] softRemoval:NO expirationTime:[pending[@"expiration"] doubleValue]];
            }else{
                [bakgrunnur _terminateProcess:pending[@"identifier"]];
            }
        }
        if (pending[@"foreground"]){
            if ([pending[@"foreground"] boolValue]){
                
                
                FBSceneManager *sceneManager  = [%c(FBSceneManager) sharedInstance];
                NSMutableDictionary *scenesByID = [sceneManager valueForKey:@"_scenesByID"];
                
                [scenesByID enumerateKeysAndObjectsUsingBlock:^(NSString *sceneID, FBScene *scene, BOOL *stop) {
                    if ([pending[@"identifier"] isEqualToString:scene.clientProcess.identity.embeddedApplicationIdentifier]) {
                        
                        //apply foreground
                        FBSMutableSceneSettings *backgroundingSceneSettings = scene.mutableSettings;
                        [backgroundingSceneSettings setForeground:[pending[@"foreground"] boolValue]];
                        [backgroundingSceneSettings setBackgrounded:![pending[@"foreground"] boolValue]];
                        [sceneManager _applyMutableSettings:backgroundingSceneSettings toScene:scene withTransitionContext:nil completion:nil];
                        
                        
                        //add to queues
                        NSUInteger identifierIdx = [allEntriesIdentifier indexOfObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                        BOOL isImmortal = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"retire"]) ? ([prefs[@"enabledIdentifier"][identifierIdx][@"retire"] intValue] == 2) : NO;
                        BOOL isAdvancedMonitoring = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"retire"]) ? ([prefs[@"enabledIdentifier"][identifierIdx][@"retire"] intValue] == 3) : NO;
                        [bakgrunnur.grantedOnceIdentifiers removeObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                        [bakgrunnur invalidateQueue:scene.clientProcess.identity.embeddedApplicationIdentifier];
                        if (isImmortal || isAdvancedMonitoring){
                            [bakgrunnur.immortalIdentifiers addObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                            [bakgrunnur updateLabelAccessory:scene.clientProcess.identity.embeddedApplicationIdentifier];
                            if (isAdvancedMonitoring){
                                [bakgrunnur.advancedMonitoringIdentifiers addObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                                [bakgrunnur startAdvancedMonitoringWithInterval:globalTimeSpan];
                            }
                        }else{
                            double expiration = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"expiration"] && [prefs[@"enabledIdentifier"][identifierIdx][@"expiration"] length] > 0) ? [prefs[@"enabledIdentifier"][identifierIdx][@"expiration"] doubleValue] : defaultExpirationTime;
                            expiration = expiration < 0 ? defaultExpirationTime : expiration;
                            expiration = expiration == 0 ? 1 : expiration;
                            
                            [bakgrunnur queueProcess:scene.clientProcess.identity.embeddedApplicationIdentifier  softRemoval:(identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"retire"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"retire"] boolValue] : YES expirationTime:expiration];
                        }
                        
                        *stop = YES;
                    }
                }];
            }else{
                [bakgrunnur _retireScene:pending[@"identifier"]];
            }
        }
        
        //launchb in fore/background
        if (pending[@"launchb"] || pending[@"launchf"]){
            
            FBSceneManager *sceneManager  = [%c(FBSceneManager) sharedInstance];
            NSMutableDictionary *scenesByID = [sceneManager valueForKey:@"_scenesByID"];
            
            [bakgrunnur launchBundleIdentifier:pending[@"identifier"] trusted:YES suspended:[pending[@"launchb"] boolValue] withPayloadURL:nil completion:^(NSError *error){
                if ([pending[@"launchb"] boolValue]){
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        
                        [scenesByID enumerateKeysAndObjectsUsingBlock:^(NSString *sceneID, FBScene *scene, BOOL *stop){
                            if ([pending[@"identifier"] isEqualToString:scene.clientProcess.identity.embeddedApplicationIdentifier]) {
                                
                                if (@available(iOS 14.0, *)){
                                    bakgrunnur.temporarilyHaltBanner = YES;
                                    sceneMovedToForeground(scene, nil);
                                }else{
                                    [sceneManager _noteSceneMovedToForeground:scene];
                                }
                                
                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                    
                                    if (@available(iOS 14.0, *)){
                                        sceneMovedToBackground(scene, ^{
                                            bakgrunnur.temporarilyHaltBanner = NO;
                                        });
                                    }else{
                                        [sceneManager _noteSceneMovedToBackground:scene];
                                    }
                                    
                                });
                                *stop = YES;
                            }
                        }];
                    });
                    
                }
                
            }];
            
        }
    }
}

static void preming(){
    HBLogDebug(@"prerming");
    BKGBakgrunnur *bakgrunnur = [BKGBakgrunnur sharedInstance];
    bakgrunnur.isPreming = YES;
    [bakgrunnur notifySleepingState:YES];
    bakgrunnur.sleepingState = 0;
}

%ctor{
    reloadPrefs();
    
    %init();
    
    if (@available(iOS 14.0, *)){
        //already handled in methods
    }else{
        %init(iOS13);
    }
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reloadPrefs, (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)cliRequest, (CFStringRef)CLI_REQUEST_NOTIFICATION_NAME, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)resetAll, (CFStringRef)RESET_ALL_NOTIFICATION_NAME, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)preming, (CFStringRef)PRERMING_NOTIFICATION_NAME, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    
    
    firstInit = NO;
    
}
