#import "common.h"
#import "Shared.h"
#import "SpringBoard.h"
#import "BKGBakgrunnur.h"
#import "NSTask.h"
#include <pthread.h>
#include <mach/mach.h>
#include <dlfcn.h>
#include <objc/runtime.h>

//static NSDictionary *prefs;
//static NSArray *enabledIdentifier;
//static NSArray *allEntriesIdentifier;
//static SBFloatingDockView *floatingDockView;
//static double globalTimeSpan = 1800.0/2.0;

@implementation BKGBakgrunnur

+(void)load{
    [self sharedInstance];
}

+ (instancetype)sharedInstance {
    static dispatch_once_t once = 0;
    __strong static id sharedInstance = nil;
    dispatch_once(&once, ^{
        sharedInstance = [self new];
    });
    return sharedInstance;
}

- (instancetype)init{
    if ((self = [super init])){
        
        self.isPreming = NO;
        
        [self createXPCConnection];
        //[self createPowerdXPCConnection];
        [self notifySleepingState:YES];
        //0-sleep
        //1-half-asleep
        self.sleepingState = 0;
        
        self.retiringIdentifiers = [[NSMutableArray alloc] init];
        self.retiringAssertionIdentifiers = [[NSMutableArray alloc] init];
        self.queuedIdentifiers = [[NSMutableArray alloc] init];
        self.immortalIdentifiers = [[NSMutableArray alloc] init];
        self.advancedMonitoringIdentifiers = [[NSMutableArray alloc] init];
        self.advancedMonitoringHistory = [[NSMutableDictionary alloc] init];
        self.pendingAccessoryUpdateFolderID = [[NSMutableArray alloc] init];
        self.grantedOnceIdentifiers = [[NSMutableArray alloc] init];
        self.userInitiatedIdentifiers = [[NSMutableArray alloc] init];
        _retiringAssertionQueues = [NSMutableDictionary dictionary];
        //[self addObserver:self forKeyPath:@"queuedIdentifiers" options:NSKeyValueObservingOptionNew context:@selector(notifySleepingState:)];
        //[self addObserver:self forKeyPath:@"immortalIdentifiers" options:NSKeyValueObservingOptionNew context:@selector(notifySleepingState:)];
        //[self addObserver:self forKeyPath:@"advancedMonitoringIdentifiers" options:NSKeyValueObservingOptionNew context:@selector(notifySleepingState:)];
        
        //self.ipcCenter = [CPDistributedMessagingCenter centerNamed:kIPCCenterName];
        //rocketbootstrap_distributedmessagingcenter_apply(self.ipcCenter);
    }
    return self;
}

-(void)updateDarkWakeState{
    if (self.isPreming) return;
    if ([self.darkWakeIdentifiers count] > 0){
        if ([self.darkWakeIdentifiers firstObjectCommonWithArray:self.queuedIdentifiers] || [self.darkWakeIdentifiers firstObjectCommonWithArray:self.immortalIdentifiers] || [self.darkWakeIdentifiers firstObjectCommonWithArray:self.advancedMonitoringIdentifiers]){
            if (self.sleepingState == 1) return;
            [self notifySleepingState:NO];
            self.sleepingState = 1;
        }else{
            if (self.sleepingState == 0) return;
            [self notifySleepingState:YES];
            self.sleepingState = 0;
        }
    }else{
        if (self.sleepingState == 0) return;
        [self notifySleepingState:YES];
        self.sleepingState = 0;
    }
}

-(void)update{
    self.darkWakeIdentifiers = [self darkWakers];
    self.dormantDarkWakeIdentifiers = [self dormantDarkWakers];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self updateDarkWakeState];
    });
}

-(NSArray *)filterDictionary:(NSDictionary *)dict keyName:(NSString *)keyName identifier:(NSString *)identifier format:(NSString *)format{
    
    NSArray *array = [dict[keyName] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:format]];
    NSArray *filteredArray = [array valueForKey:identifier];
    return filteredArray;
}

-(NSArray *)darkWakers{
    return [self filterDictionary:prefs keyName:@"enabledIdentifier" identifier:@"identifier" format:@"enabled = YES && darkWake = YES"];
}

-(NSArray *)dormantDarkWakers{
    return [self filterDictionary:prefs keyName:@"enabledIdentifier" identifier:@"identifier" format:@"enabled = NO && darkWake = YES"];
}

/*
 - (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
 HBLogDebug(@"observeValueForKeyPath: %@", keyPath);
 if ([keyPath isEqualToString:@"queuedIdentifiers"]){
 if ([self.darkWakeIdentifiers count] > 0){
 if ([self.darkWakeIdentifiers firstObjectCommonWithArray:self.queuedIdentifiers]){
 [self notifySleepingState:NO];
 }
 }
 }
 }
 */

-(BOOL)isFrontMost:(NSString *)identifier{
    SBApplication *frontMostApp = [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
    BOOL isFrontMost = [frontMostApp.bundleIdentifier isEqualToString:identifier];
    BOOL isUILocked = [[objc_getClass("SBLockScreenManager") sharedInstance] isUILocked];
    if (isUILocked) isFrontMost = NO;
    return isFrontMost;
}

-(void)updateLabelAccessory:(NSString *)identifier{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[((SBIconController *)[objc_getClass("SBIconController") sharedInstance]).model applicationIconForBundleIdentifier:identifier] _notifyAccessoriesDidUpdate];
        [self updateLabelAccessoryForDockItem:identifier];
    });
}

-(void)updateLabelAccessoryForDockItem:(NSString *)identifier{
    if (floatingDockView){
        
        for (SBApplicationIcon *icon in floatingDockView.recentIconListView.visibleIcons){
            if ([icon.applicationBundleID isEqualToString:identifier]){
                [icon _notifyAccessoriesDidUpdate];
                break;
            }
        }
    }
}

-(void)fireAssertionRetiring:(NSString *)identifier delay:(double)delay{
    
    if (_retiringAssertionQueues[identifier]){
        dispatch_block_cancel(_retiringAssertionQueues[identifier]);
    }
    
    _retiringAssertionQueues[identifier] = dispatch_block_create(static_cast<dispatch_block_flags_t>(0), ^{
        [self.retiringAssertionIdentifiers removeObject:identifier];
        [_retiringAssertionQueues removeObjectForKey:identifier];
    });
        
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (delay * NSEC_PER_SEC)),dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), _retiringAssertionQueues[identifier]);
}

-(void)retireScene:(id)timer{
    NSDictionary *userInfo = [timer userInfo];
    [self _retireScene:userInfo[@"identifier"]];
}

-(void)_retireAllScenesIn:(NSMutableArray *)identifiers{
    HBLogDebug(@"Retiring all scenes in %@", identifiers);
    
    FBSceneManager *sceneManager  = [objc_getClass("FBSceneManager") sharedInstance];
    NSMutableDictionary *scenesByID = [sceneManager valueForKey:@"_scenesByID"];
    
    NSMutableArray *toBeRemovedQueuedIdentifiers = [[NSMutableArray alloc] init];
    NSMutableArray *toBeRemovedQueuedImmortalIdentifiers = [[NSMutableArray alloc] init];
    NSMutableArray *toBeRemovedAdvancedMonitoringIdentifiers = [[NSMutableArray alloc] init];
    NSMutableArray *toBeRemovedAdvancedMonitoringHistoryIdentifiers = [[NSMutableArray alloc] init];
    
    
    [scenesByID enumerateKeysAndObjectsUsingBlock:^(NSString *sceneID, FBScene *scene, BOOL *stop) {
        NSString *identifier = scene.clientProcess.identity.embeddedApplicationIdentifier;
        if ([identifiers containsObject:identifier]) {
            
            if (![self.retiringIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]){
                [self.retiringIdentifiers addObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
            }
            
            if (![self.retiringAssertionIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]){
                [self.retiringAssertionIdentifiers addObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
            }
            
            UIMutableApplicationSceneSettings *newSettings = [scene.settings mutableCopy];
            [newSettings setForeground:NO];
            [newSettings setUnderLock:NO];
            [newSettings setDeactivationReasons:0];
            
            [sceneManager _applyMutableSettings:[newSettings copy] toScene:scene withTransitionContext:nil completion:^{
                if (@available(iOS 14.0, *)){
                    [self.retiringIdentifiers removeObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                }
            }];
            
            [toBeRemovedQueuedIdentifiers addObject:identifier];
            [toBeRemovedQueuedImmortalIdentifiers addObject:identifier];
            [toBeRemovedAdvancedMonitoringIdentifiers addObject:identifier];
            [toBeRemovedAdvancedMonitoringHistoryIdentifiers addObject:identifier];
            
            
            [self updateLabelAccessory:identifier];
            HBLogDebug(@"Retired %@", scene.clientProcess.identity.embeddedApplicationIdentifier);
        }
    }];
    [self.queuedIdentifiers removeObjectsInArray:toBeRemovedQueuedIdentifiers];
    [self.immortalIdentifiers removeObjectsInArray:toBeRemovedQueuedImmortalIdentifiers];
    [self.advancedMonitoringIdentifiers removeObjectsInArray:toBeRemovedAdvancedMonitoringIdentifiers];
    [self.grantedOnceIdentifiers removeObjectsInArray:toBeRemovedQueuedIdentifiers];
    [self.userInitiatedIdentifiers removeObjectsInArray:identifiers];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self updateDarkWakeState];
    });
    
    for (NSString *key in toBeRemovedAdvancedMonitoringHistoryIdentifiers){
        [self.advancedMonitoringHistory removeObjectForKey:key];
    }
}


-(void)_retireScene:(NSString *)identifier{
    HBLogDebug(@"Retiring %@", identifier);
    
    FBSceneManager *sceneManager  = [objc_getClass("FBSceneManager") sharedInstance];
    NSMutableDictionary *scenesByID = [sceneManager valueForKey:@"_scenesByID"];
    
    [scenesByID enumerateKeysAndObjectsUsingBlock:^(NSString *sceneID, FBScene *scene, BOOL *stop) {
        if ([identifier isEqualToString:scene.clientProcess.identity.embeddedApplicationIdentifier]) {
            
            if (![self.retiringIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]){
                [self.retiringIdentifiers addObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
            }
            
            if (![self.retiringAssertionIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]){
                [self.retiringAssertionIdentifiers addObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
            }
            
            UIMutableApplicationSceneSettings *newSettings = [scene.settings mutableCopy];
            [newSettings setForeground:NO];
            [newSettings setUnderLock:NO];
            [newSettings setDeactivationReasons:0];

            [sceneManager _applyMutableSettings:[newSettings copy] toScene:scene withTransitionContext:nil completion:^{
                if (@available(iOS 14.0, *)){
                    [self.retiringIdentifiers removeObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                }
            }];

            [self.queuedIdentifiers removeObject:identifier];
            [self.immortalIdentifiers removeObject:identifier];
            [self.advancedMonitoringIdentifiers removeObject:identifier];
            [self.grantedOnceIdentifiers removeObject:identifier];
            [self.advancedMonitoringHistory removeObjectForKey:identifier];
            //[self invalidateAssertion:identifier];
            [self.userInitiatedIdentifiers removeObject:identifier];
            [self updateLabelAccessory:identifier];

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [self updateDarkWakeState];
            });
            
            HBLogDebug(@"Retired %@", scene.clientProcess.identity.embeddedApplicationIdentifier);
                        
            *stop = YES;
        }
    }];
}

-(int)pidForBundleIdentifier:(NSString *)bundleIdentifier{
    return [[objc_getClass("FBSSystemService") sharedService] pidForApplication:bundleIdentifier];
}

-(void)terminateProcess:(id)timer{
    NSDictionary *userInfo = [timer userInfo];
    [self _terminateProcess:userInfo[@"identifier"]];
}

-(void)_terminateProcess:(NSString *)identifier{
    HBLogDebug(@"Terminating %@", identifier);
    [[objc_getClass("FBSSystemService") sharedService] terminateApplication:identifier forReason:FBSTerminationReasonUserInitiated andReport:NO withDescription:nil completion:^(NSInteger result){
        [self.queuedIdentifiers removeObject:identifier];
        [self.immortalIdentifiers removeObject:identifier];
        [self.advancedMonitoringIdentifiers removeObject:identifier];
        [self.grantedOnceIdentifiers removeObject:identifier];
        [self.advancedMonitoringHistory removeObjectForKey:identifier];
        //[self invalidateAssertion:identifier];
        [self updateLabelAccessory:identifier];
        [self.userInitiatedIdentifiers removeObject:identifier];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [self updateDarkWakeState];
        });
        HBLogDebug(@"Terminated %@, with result: %ld", identifier, result);
    }];
}

-(BOOL)invalidateAssertion:(NSString *)identifier{
    BOOL invalidated = NO;
    SBApplicationController *sbAppController = [objc_getClass("SBApplicationController") sharedInstanceIfExists];
    if (sbAppController){
        RBSConnection *rbsCnx = [objc_getClass("RBSConnection") sharedInstance];
        NSMapTable *acquiredAssertionsByIdentifier = [rbsCnx valueForKey:@"_acquiredAssertionsByIdentifier"];
        
        NSEnumerator *enumerator = [acquiredAssertionsByIdentifier objectEnumerator];
        RBSAssertion *assertion;
        
        while ((assertion = [enumerator nextObject])) {
            SBApplication *sbApp = [sbAppController applicationWithPid:assertion.target.processIdentifier.pid];
            NSString *bundleIdentifier = sbApp.bundleIdentifier;
            if ([bundleIdentifier isEqualToString:identifier]){
                [rbsCnx invalidateAssertionWithIdentifier:assertion.identifier error:nil];
                invalidated = YES;
            }
        }
    }
    return invalidated;
}

-(BOOL)isQueued:(NSString *)identifier{
    PCPersistentInterfaceManager *pcTimerManager = [objc_getClass("PCPersistentInterfaceManager") sharedInstance];
    NSMapTable *queues = [pcTimerManager valueForKey:@"_delegatesAndQueues"];
    NSArray *timerInQueues = [queues allKeys];
 
    for (PCPersistentTimer *persistentTimer in timerInQueues){
        PCSimpleTimer *simpleTimer = [persistentTimer valueForKey:@"_simpleTimer"];
        NSString *serviceindentifier =[simpleTimer valueForKey:@"_serviceIdentifier"];
        if ([serviceindentifier isEqualToString:[NSString stringWithFormat:@"com.udevs.bakgrunnur.%@", identifier]]){
            return YES;
            break;
        }
    }
    return NO;
}

-(void)invalidateQueue:(NSString *)identifier{
    PCPersistentInterfaceManager *pcTimerManager = [objc_getClass("PCPersistentInterfaceManager") sharedInstance];
    NSMapTable *queues = [pcTimerManager valueForKey:@"_delegatesAndQueues"];
    NSArray *timerInQueues = [queues allKeys];
    //HBLogDebug(@"allkeys: %@", timerInQueues);
    [self.immortalIdentifiers removeObject:identifier];
    [self.advancedMonitoringIdentifiers removeObject:identifier];
    [self.advancedMonitoringHistory removeObjectForKey:identifier];
    ////[self invalidateAssertion:identifier];
    //[self.userInitiatedIdentifiers removeObject:identifier];
    
    //[self.grantedOnceIdentifiers removeObject:identifier];
    
    for (PCPersistentTimer *persistentTimer in timerInQueues){
        PCSimpleTimer *simpleTimer = [persistentTimer valueForKey:@"_simpleTimer"];
        NSString *serviceindentifier =[simpleTimer valueForKey:@"_serviceIdentifier"];
        //HBLogDebug(@"serviceindentifier: %@", serviceindentifier);
        if ([serviceindentifier isEqualToString:[NSString stringWithFormat:@"com.udevs.bakgrunnur.%@", identifier]]){
            [self.queuedIdentifiers removeObject:identifier];
            //[self updateLabelAccessory:identifier];
            [simpleTimer invalidate];
            simpleTimer = nil;
            HBLogDebug(@"Invalidated %@", identifier);
            break;
        }
    }
    [self updateLabelAccessory:identifier];
    
}

-(void)invalidateAllQueues{
    PCPersistentInterfaceManager *pcTimerManager = [objc_getClass("PCPersistentInterfaceManager") sharedInstance];
    NSMapTable *queues = [pcTimerManager valueForKey:@"_delegatesAndQueues"];
    NSArray *timerInQueues = [queues allKeys];
    //HBLogDebug(@"allkeys: %@", timerInQueues);
    for (NSString *identifier in self.immortalIdentifiers){
        [self _retireScene:identifier];
        [self.immortalIdentifiers removeObject:identifier];
        [self.advancedMonitoringIdentifiers removeObject:identifier];
        //[self.grantedOnceIdentifiers removeObject:identifier];
        [self.advancedMonitoringHistory removeObjectForKey:identifier];
        //[self invalidateAssertion:identifier];
        //[self.userInitiatedIdentifiers removeObject:identifier];
        [self updateLabelAccessory:identifier];
    }
    
    
    for (PCPersistentTimer *persistentTimer in timerInQueues){
        PCSimpleTimer *simpleTimer = [persistentTimer valueForKey:@"_simpleTimer"];
        NSString *serviceindentifier = [simpleTimer valueForKey:@"_serviceIdentifier"];
        //HBLogDebug(@"serviceindentifier: %@", serviceindentifier);
        if ([serviceindentifier containsString:@"com.udevs.bakgrunnur."]){
            NSString *identifier = [serviceindentifier stringByReplacingOccurrencesOfString:@"com.udevs.bakgrunnur." withString:@""];
            [self _retireScene:identifier];
            [self.queuedIdentifiers removeObject:identifier];
            [self updateLabelAccessory:identifier];
            [simpleTimer invalidate];
            simpleTimer = nil;
            HBLogDebug(@"Invalidated %@", identifier);
        }
    }
}

-(void)invalidateAllQueuesIn:(NSArray *)identifiers{
    PCPersistentInterfaceManager *pcTimerManager = [objc_getClass("PCPersistentInterfaceManager") sharedInstance];
    NSMapTable *queues = [pcTimerManager valueForKey:@"_delegatesAndQueues"];
    NSArray *timerInQueues = [queues allKeys];
    //HBLogDebug(@"allkeys: %@", timerInQueues);
    
    for (NSString *identifier in identifiers){
        [self _retireScene:identifier];
        [self.immortalIdentifiers removeObject:identifier];
        [self.advancedMonitoringIdentifiers removeObject:identifier];
        //[self.grantedOnceIdentifiers removeObject:identifier];
        [self.advancedMonitoringHistory removeObjectForKey:identifier];
        //[self invalidateAssertion:identifier];
        //[self.userInitiatedIdentifiers removeObject:identifier];
        [self updateLabelAccessory:identifier];
    }
    
    for (PCPersistentTimer *persistentTimer in timerInQueues){
        PCSimpleTimer *simpleTimer = [persistentTimer valueForKey:@"_simpleTimer"];
        NSString *serviceindentifier = [simpleTimer valueForKey:@"_serviceIdentifier"];
        //HBLogDebug(@"serviceindentifier: %@", serviceindentifier);
        if ([serviceindentifier containsString:@"com.udevs.bakgrunnur."]){
            NSString *identifier = [serviceindentifier stringByReplacingOccurrencesOfString:@"com.udevs.bakgrunnur." withString:@""];
            if ([identifiers containsObject:identifier]){
                [self _retireScene:identifier];
                [self.queuedIdentifiers removeObject:identifier];
                [self updateLabelAccessory:identifier];
                [simpleTimer invalidate];
                simpleTimer = nil;
                HBLogDebug(@"Invalidated %@", identifier);
            }
        }
    }
}

-(void)queueProcess:(NSString *)identifier softRemoval:(BOOL)removeGracefully expirationTime:(double)expTime{
    /*
    RBSRunningReasonAttribute *runningAttr = [objc_getClass("RBSRunningReasonAttribute") withReason:1000];
    RBSLegacyAttribute *legacyAttr = [objc_getClass("RBSLegacyAttribute") attributeWithReason:1 flags:13];
    RBSPreventIdleSleepGrant *preventSleepGrant = [objc_getClass("RBSPreventIdleSleepGrant") grant];
    RBSAppNapPreventBackgroundSocketsGrant *preventBackgroundSocketGrant = [objc_getClass("RBSAppNapPreventBackgroundSocketsGrant") grant];
    RBSAppNapInactiveGrant *inactiveGrant = [objc_getClass("RBSAppNapInactiveGrant") grant];

    RBSTarget *target = [objc_getClass("RBSTarget") targetWithPid:[[objc_getClass("FBSSystemService") sharedService] pidForApplication:identifier]];
    
    if (!self.backgroundAssertion){
    NSError *err = nil;
    self.backgroundAssertion  = [[objc_getClass("RBSAssertion") alloc] initWithExplanation:@"Bakgrunnur" target:target attributes:@[runningAttr, legacyAttr, preventSleepGrant, preventBackgroundSocketGrant, inactiveGrant]];
    [self.backgroundAssertion acquireWithError:&err];
    HBLogDebug(@"Error: %@", err);

    
    self.backgroundAssertionID = [[objc_getClass("RBSConnection") sharedInstance] acquireAssertion:self.backgroundAssertion error:&err];
    HBLogDebug(@"Error: %@", err);
    }
    */
    
    PCPersistentTimer *timer = [[objc_getClass("PCPersistentTimer") alloc] initWithFireDate:[[NSDate date] dateByAddingTimeInterval:expTime] serviceIdentifier:[NSString stringWithFormat:@"com.udevs.bakgrunnur.%@", identifier] target:self selector:(removeGracefully?@selector(retireScene:):@selector(terminateProcess:)) userInfo:@{@"identifier":identifier}];
    
    [timer setMinimumEarlyFireProportion:1];
    
    if ([NSThread isMainThread]) {
        [timer scheduleInRunLoop:[NSRunLoop mainRunLoop]];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^ {
            [timer scheduleInRunLoop:[NSRunLoop mainRunLoop]];
        });
    }
    
    [self.queuedIdentifiers addObject:identifier];
    [self updateLabelAccessory:identifier];
    //SBApplicationController *sbAppController = [objc_getClass("SBApplicationController") sharedInstance];
    //SBApplication *sbApp = [sbAppController applicationWithBundleIdentifier:identifier];
    //[sbApp _setNewlyInstalled:YES];
}


-(void)setTaskEventsDeltaHistoryForBundleIdentifier:(NSString *)identifier newHistory:(NSMutableDictionary *)history lastHistory:(NSMutableDictionary *)historyDictAtInstance timeStamp:(NSTimeInterval)timeStamp delay:(double)delay{
    
    [historyDictAtInstance setObject:@([[self taskEventsDeltaForBundleIdentifier:identifier history:nil][@"syscalls_mach"] intValue]) forKey:@"syscalls_mach"];
    [historyDictAtInstance setObject:@([[self taskEventsDeltaForBundleIdentifier:identifier history:nil][@"syscalls_unix"] intValue]) forKey:@"syscalls_unix"];
    [historyDictAtInstance setObject:@([[self taskEventsDeltaForBundleIdentifier:identifier history:nil][@"syscalls_total"] intValue]) forKey:@"syscalls_total"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [historyDictAtInstance setObject:@([[self taskEventsDeltaForBundleIdentifier:identifier history:historyDictAtInstance][@"syscalls_mach"] intValue]) forKey:@"syscalls_mach"];
        [historyDictAtInstance setObject:@([[self taskEventsDeltaForBundleIdentifier:identifier history:historyDictAtInstance][@"syscalls_unix"] intValue]) forKey:@"syscalls_unix"];
        [historyDictAtInstance setObject:@([[self taskEventsDeltaForBundleIdentifier:identifier history:historyDictAtInstance][@"syscalls_total"] intValue]) forKey:@"syscalls_total"];
        history[@(timeStamp)] = historyDictAtInstance;
        self.advancedMonitoringHistory[identifier] = history;
    });
}



-(void)setTaskEventsDeltaHistoryForBundleIdentifier:(NSString *)identifier newHistory:(NSMutableDictionary *)history lastHistory:(NSMutableDictionary *)historyDictAtInstanceIn withNetstat:(BOOL)requestNestat timeStamp:(NSTimeInterval)timeStamp delay:(double)delay{
    
    if (!requestNestat){
        [self setTaskEventsDeltaHistoryForBundleIdentifier:identifier newHistory:history lastHistory:historyDictAtInstanceIn timeStamp:timeStamp delay:delay];
        return;
    }
    
    __block NSMutableDictionary *historyDictAtInstance = [historyDictAtInstanceIn mutableCopy];
    
    [self netStatDeltaForBundleIdentifiers:@[identifier] history:nil cachedStats:self.cachedNetstatOne completion:^(NSDictionary *validNetstats, NSDictionary *stats){
        self.cachedNetstatOne = stats;
        
        
        NSNumber *currentRxbytes = validNetstats[identifier][@"rxbytes"]?:@0;
        NSNumber *currentTxbytes = validNetstats[identifier][@"txbytes"]?:@0;
        
        [historyDictAtInstance setObject:currentRxbytes forKey:@"rxbytes"];
        [historyDictAtInstance setObject:currentTxbytes forKey:@"txbytes"];
        [historyDictAtInstance setObject:@([currentRxbytes unsignedLongLongValue] + [currentTxbytes unsignedLongLongValue]) forKey:@"rxtxbytes"];
        
        
        [historyDictAtInstance setObject:@([[self taskEventsDeltaForBundleIdentifier:identifier history:nil][@"syscalls_mach"] intValue]) forKey:@"syscalls_mach"];
        [historyDictAtInstance setObject:@([[self taskEventsDeltaForBundleIdentifier:identifier history:nil][@"syscalls_unix"] intValue]) forKey:@"syscalls_unix"];
        [historyDictAtInstance setObject:@([[self taskEventsDeltaForBundleIdentifier:identifier history:nil][@"syscalls_total"] intValue]) forKey:@"syscalls_total"];
        
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            
            [self netStatDeltaForBundleIdentifiers:@[identifier] history:@{identifier:historyDictAtInstance} cachedStats:self.cachedNetstatTwo completion:^(NSDictionary *validNetstats, NSDictionary *stats){
                
                self.cachedNetstatTwo = stats;
                
                NSNumber *currentRxbytes = validNetstats[identifier][@"rxbytes"]?:@0;
                NSNumber *currentTxbytes = validNetstats[identifier][@"txbytes"]?:@0;
                
                [historyDictAtInstance setObject:currentRxbytes forKey:@"rxbytes"];
                [historyDictAtInstance setObject:currentTxbytes forKey:@"txbytes"];
                [historyDictAtInstance setObject:@([currentRxbytes unsignedLongLongValue] + [currentTxbytes unsignedLongLongValue]) forKey:@"rxtxbytes"];
                
                [historyDictAtInstance setObject:@([[self taskEventsDeltaForBundleIdentifier:identifier history:historyDictAtInstance][@"syscalls_mach"] intValue]) forKey:@"syscalls_mach"];
                [historyDictAtInstance setObject:@([[self taskEventsDeltaForBundleIdentifier:identifier history:historyDictAtInstance][@"syscalls_unix"] intValue]) forKey:@"syscalls_unix"];
                [historyDictAtInstance setObject:@([[self taskEventsDeltaForBundleIdentifier:identifier history:historyDictAtInstance][@"syscalls_total"] intValue]) forKey:@"syscalls_total"];
                history[@(timeStamp)] = historyDictAtInstance;
                self.advancedMonitoringHistory[identifier] = history;
            }];
            
            
        });
        
        
    }];
    
}



-(void)monitoringUsage:(PCPersistentTimer *)timer{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        BOOL scheduledCall = ([timer userInfo] && [[timer userInfo][@"scheduledCall"] boolValue]) ? YES : NO;
        HBLogDebug(@"%@", scheduledCall?@"Monitoring usage by system":@"Checking monitoring criteria");
        
        NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
        BOOL shouldDeferChecking = NO;
        NSMutableArray *toBeInvalidateQueues = [[NSMutableArray alloc] init];
        NSMutableArray *toBeRetiredIndentifiers = [[NSMutableArray alloc] init];
        
        for (NSString *identifier in self.advancedMonitoringIdentifiers){
            
            NSUInteger identifierIdx = [allEntriesIdentifier indexOfObject:identifier];
            BOOL cpuUsageEnabled = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"cpuUsageEnabled"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"cpuUsageEnabled"] boolValue] : NO;
            
            int networkTransmissionType = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"networkTransmissionType"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"networkTransmissionType"] intValue] : 0;
            
            int systemCallsType = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"systemCallsType"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"systemCallsType"] intValue] : 0;
            
            if (scheduledCall){
                
                switch ([[(NSMutableDictionary *)self.advancedMonitoringHistory[identifier] allKeys] count]) {
                    case 0:{
                        NSMutableDictionary *history = [[NSMutableDictionary alloc] init];
                        NSMutableDictionary *historyDictAtInstance = [[NSMutableDictionary alloc] init];
                        if (cpuUsageEnabled){
                            [historyDictAtInstance setObject:@([self cpuUsageForBundleIdentifier:identifier]) forKey:@"cpu"];
                        }
                        if (systemCallsType > 0 || networkTransmissionType > 0){
                            shouldDeferChecking = YES;
                            [self setTaskEventsDeltaHistoryForBundleIdentifier:identifier newHistory:history lastHistory:historyDictAtInstance withNetstat:(networkTransmissionType > 0) timeStamp:timeStamp delay:1.0];
                        }else{
                            history[@(timeStamp)] = historyDictAtInstance;
                            self.advancedMonitoringHistory[identifier] = history;
                        }
                        continue;
                        break;
                    }
                    case 1:{
                        NSMutableDictionary *history = [self.advancedMonitoringHistory[identifier] mutableCopy];
                        NSMutableDictionary *historyDictAtInstance = [[NSMutableDictionary alloc] init];
                        if (cpuUsageEnabled){
                            [historyDictAtInstance setObject:@([self cpuUsageForBundleIdentifier:identifier]) forKey:@"cpu"];
                        }
                        if (systemCallsType > 0 || networkTransmissionType > 0){
                            shouldDeferChecking = YES;
                            [self setTaskEventsDeltaHistoryForBundleIdentifier:identifier newHistory:history lastHistory:historyDictAtInstance withNetstat:(networkTransmissionType > 0) timeStamp:timeStamp delay:1.0];
                            continue;
                        }else{
                            history[@(timeStamp)] = historyDictAtInstance;
                            self.advancedMonitoringHistory[identifier] = history;
                        }
                        break;
                    }
                    case 2:{
                        NSMutableDictionary *history = [self.advancedMonitoringHistory[identifier] mutableCopy];
                        //HBLogDebug(@"***********history: %@", history);
                        NSArray *timeStamps = [history allKeys];
                        //HBLogDebug(@"***********timeStamps: %@", timeStamps);
                        
                        double oldestTimeStamp = [[[NSDate date] dateByAddingTimeInterval:86400] timeIntervalSince1970];
                        for (id t in timeStamps){
                            if ([t doubleValue] < oldestTimeStamp){
                                oldestTimeStamp = [t doubleValue];
                            }
                        }
                        [history removeObjectForKey:@(oldestTimeStamp)];
                        //HBLogDebug(@"***********history222: %@", history);
                        
                        //NSMutableDictionary *historyDictAtInstance = [history[@(timeStamp)] mutableCopy];
                        NSMutableDictionary *historyDictAtInstance = [history[[[history allKeys] firstObject]] mutableCopy];
                        
                        //HBLogDebug(@"***********timeStamp: %f", timeStamp);
                        
                        //HBLogDebug(@"***********historyDictAtInstance: %@", historyDictAtInstance);
                        
                        if (cpuUsageEnabled){
                            [historyDictAtInstance setObject:@([self cpuUsageForBundleIdentifier:identifier]) forKey:@"cpu"];
                        }
                        if (systemCallsType > 0 || networkTransmissionType > 0){
                            shouldDeferChecking = YES;
                            [self setTaskEventsDeltaHistoryForBundleIdentifier:identifier newHistory:history lastHistory:historyDictAtInstance withNetstat:(networkTransmissionType > 0) timeStamp:timeStamp delay:1.0];
                            continue;
                        }else{
                            history[@(timeStamp)] = historyDictAtInstance;
                            self.advancedMonitoringHistory[identifier] = history;
                        }
                        break;
                    }
                    default:
                        break;
                }
                if (shouldDeferChecking) return;
            }
            
            
            if (self.advancedMonitoringHistory[identifier] && [[(NSMutableDictionary *)self.advancedMonitoringHistory[identifier] allKeys] count] > 1){
                
                
                float cpuUsageThreshold = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"cpuUsageThreshold"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"cpuUsageThreshold"] floatValue] : 0.5f;
                cpuUsageThreshold = cpuUsageThreshold <= 0.0f ? 0.0f : cpuUsageThreshold;
                cpuUsageThreshold = !cpuUsageThreshold ? 0.0f : cpuUsageThreshold;
                
                //HBLogDebug(@"cpuUsageThreshold: %f", cpuUsageThreshold);
                
                double rxbytesThreshold = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"rxbytesThreshold"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"rxbytesThreshold"] unsignedLongLongValue] : 0;
                
                double txbytesThreshold = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"txbytesThreshold"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"txbytesThreshold"] unsignedLongLongValue] : 0;
                
                int networkUnit = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"networkTransmissionUnit"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"networkTransmissionUnit"] unsignedLongLongValue] : 2;
                
                double networkThresholdUnitDenomination = (double)pow((double)1024,(double)2);
                switch (networkUnit) {
                    case 0:
                        networkThresholdUnitDenomination = (double)1;
                        break;
                    case 1:
                        networkThresholdUnitDenomination = (double)1024;
                        break;
                    case 2:
                        networkThresholdUnitDenomination = (double)pow((double)1024, (double)2);
                        break;
                    case 3:
                        networkThresholdUnitDenomination = (double)pow((double)1024, (double)3);
                        break;
                    default:
                        break;
                }
                
                int systemCallsThreshold = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"systemCallsThreshold"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"systemCallsThreshold"] intValue] : 0;
                systemCallsThreshold = systemCallsThreshold <= 0 ? 0 : systemCallsThreshold;
                
                //int criteriaToBeFullfilledCount = 0;
                //if (cpuUsageEnabled) criteriaToBeFullfilledCount++;
                NSString *selectedSystemCallsKey = @"syscalls_total";
                if (systemCallsType > 0){
                    //criteriaToBeFullfilledCount++;
                    
                    switch (systemCallsType) {
                        case 1:
                            selectedSystemCallsKey = @"syscalls_mach";
                            break;
                        case 2:
                            selectedSystemCallsKey = @"syscalls_unix";
                            break;
                        case 3:
                            selectedSystemCallsKey = @"syscalls_total";
                            break;
                        default:
                            break;
                    }
                }
                
                NSString *selectedNetworkTransmissionType = @"rxtxbytes";
                double networkThreshold = 0;
                if (networkTransmissionType > 0){
                    //criteriaToBeFullfilledCount++;
                    
                    switch (networkTransmissionType) {
                        case 1:
                            selectedNetworkTransmissionType = @"rxbytes";
                            networkThreshold = rxbytesThreshold;
                            break;
                        case 2:
                            selectedNetworkTransmissionType = @"txbytes";
                            networkThreshold = txbytesThreshold;
                            break;
                        case 3:
                            selectedNetworkTransmissionType = @"rxtxbytes";
                            networkThreshold = rxbytesThreshold + txbytesThreshold;
                            break;
                        default:
                            break;
                    }
                }
                
                BOOL hasFullfilledThresholdCrtiteria = YES;
                //NSMutableArray *values = [[NSMutableArray alloc] init];
                HBLogDebug(@"advancedMonitoringHistory %@", self.advancedMonitoringHistory);
                
                
                //int criteriaFullfilledCount = 0;
                for (NSString *timestampKey in self.advancedMonitoringHistory[identifier]){
                    //HBLogDebug(@"%@ ** rxbytesFormatted: %@", identifier, [NSByteCountFormatter stringFromByteCount:[self.advancedMonitoringHistory[identifier][timestampKey][@"rxbytes"] unsignedLongLongValue] countStyle:NSByteCountFormatterCountStyleFile]);
                    HBLogDebug(@"cpuUsageEnabled: %d",cpuUsageEnabled?1:0);
                    if (cpuUsageEnabled && [self.advancedMonitoringHistory[identifier][timestampKey][@"cpu"] floatValue] > cpuUsageThreshold){
                        hasFullfilledThresholdCrtiteria = NO;
                        break;
                    }
                    HBLogDebug(@"systemCallsType: %d",systemCallsType);
                    if ((systemCallsType > 0) && [self.advancedMonitoringHistory[identifier][timestampKey][selectedSystemCallsKey] intValue] > systemCallsThreshold){
                        hasFullfilledThresholdCrtiteria = NO;
                        break;
                    }
                    
                    HBLogDebug(@"Current Speed: %lf ** Threshold: %lf", [self.advancedMonitoringHistory[identifier][timestampKey][selectedNetworkTransmissionType] doubleValue] / networkThresholdUnitDenomination , networkThreshold);
                    
                    if ((networkTransmissionType > 0) && (([self.advancedMonitoringHistory[identifier][timestampKey][selectedNetworkTransmissionType] doubleValue] / networkThresholdUnitDenomination) > networkThreshold)){
                        hasFullfilledThresholdCrtiteria = NO;
                        break;
                    }
                    
                    
                    /*
                     if (cpuUsageEnabled && [self.advancedMonitoringHistory[identifier][timestampKey][@"cpu"] floatValue] <= cpuUsageThreshold){
                     criteriaFullfilledCount++;
                     }else if (cpuUsageEnabled){
                     criteriaFullfilledCount--;
                     }
                     if ((systemCallsType > 0) && [self.advancedMonitoringHistory[identifier][timestampKey][selectedSystemCallsKey] intValue] <= systemCallsThreshold){
                     criteriaFullfilledCount++;
                     }else if (systemCallsType > 0){
                     criteriaFullfilledCount--;
                     }
                     */
                    //HBLogDebug(@"criteriaFullfilledCount: %d", criteriaFullfilledCount);
                }
                
                /*
                 if ((criteriaToBeFullfilledCount*2) == criteriaFullfilledCount){
                 hasFullfilledThresholdCrtiteria = YES;
                 HBLogDebug(@"All criteria fullfilled");
                 }
                 */
                /*
                 //NSArray *allVal = [self.advancedMonitoringHistory[identifier][@"cpu"] allValues];
                 BOOL hasFullfilledThresholdCrtiteria = YES;
                 HBLogDebug(@"allVal: %@", allVal);
                 for (id val in allVal){
                 if ([val floatValue] > threshold){
                 hasFullfilledThresholdCrtiteria = NO;
                 break;
                 }
                 }
                 */
                if (hasFullfilledThresholdCrtiteria){
                    //[self invalidateQueue:identifier];
                    //[self _retireScene:identifier];
                    [toBeInvalidateQueues addObject:identifier];
                    [toBeRetiredIndentifiers addObject:identifier];
                    HBLogDebug(@"%@ fullfilled advanced monitoring criteria", identifier);
                }
            }
        }
        self.cachedNetstatOne = nil;
        self.cachedNetstatTwo = nil;
        
        
        dispatch_async(dispatch_get_main_queue(), ^ {
            [self invalidateAllQueuesIn:toBeInvalidateQueues];
            [self _retireAllScenesIn:toBeRetiredIndentifiers];
            
            
            if (scheduledCall){
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self monitoringUsage:nil];
                });
            }
            
            if ([self.advancedMonitoringIdentifiers count] == 0){
                [self.advancedMonitoringTimer invalidate];
                self.advancedMonitoringTimer = nil;
                HBLogDebug(@"Invalidated advanced monitoring timer");
            }else{
                [self.advancedMonitoringTimer invalidate];
                self.advancedMonitoringTimer = nil;
                [self startAdvancedMonitoringWithInterval:globalTimeSpan];
                HBLogDebug(@"%@", scheduledCall ? @"Monitoring checking in next 1 second cycle" : @"Rescheduled advanced monitoring");
            }
        });
    });
}

-(void)startAdvancedMonitoringWithInterval:(double)interval{
    if (!self.advancedMonitoringTimer){
        self.advancedMonitoringTimer = [[objc_getClass("PCPersistentTimer") alloc] initWithFireDate:[[NSDate date] dateByAddingTimeInterval:interval] serviceIdentifier:@"com.udevs.bakgrunnur-advanced-monitoring" target:self selector:@selector(monitoringUsage:) userInfo:@{@"scheduledCall":@YES}];
        
        [self.advancedMonitoringTimer setMinimumEarlyFireProportion:1];
        
        if ([NSThread isMainThread]) {
            [self.advancedMonitoringTimer scheduleInRunLoop:[NSRunLoop mainRunLoop]];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^ {
                [self.advancedMonitoringTimer scheduleInRunLoop:[NSRunLoop mainRunLoop]];
            });
        }
    }
}

-(BOOL)isEnabledForBundleIdentifier:(NSString *)bundleIdentifier{
    return [enabledIdentifier containsObject:bundleIdentifier];
}

-(BOOL)isEnabled{
    return enabled;
}

-(NSArray<SBSApplicationShortcutItem*>*) stackBakgrunnurShortcut:(NSArray<SBSApplicationShortcutItem*>*)stockShortcuts bundleIdentifier:(NSString *)bundleIdentifier{
    
    NSMutableArray *stackedShortcuts = [stockShortcuts mutableCopy];
    if (!stackedShortcuts) stackedShortcuts = [NSMutableArray new];
    
    //for (NSString *itemName in itemsList) {
    BOOL isEnabled = [enabledIdentifier containsObject:bundleIdentifier];
    
    if (quickActionMaster){
        SBSApplicationShortcutItem *item = [[objc_getClass("SBSApplicationShortcutItem") alloc] init];
        item.localizedTitle = @"Bakgrunnur";
        item.localizedSubtitle = isEnabled ? @"Disable" : @"Enable";
        item.bundleIdentifierToLaunch = bundleIdentifier;
        item.type = @"BakgrunnurShortcut";
        item.icon = [[objc_getClass("SBSApplicationShortcutSystemPrivateIcon") alloc] initWithSystemImageName:@"hourglass"];
        [stackedShortcuts addObject:item];
    }
    
    if (!isEnabled && quickActionOnce){
        SBSApplicationShortcutItem *itemOnce = [[objc_getClass("SBSApplicationShortcutItem") alloc] init];
        itemOnce.localizedTitle = @"Bakgrunnur";
        itemOnce.bundleIdentifierToLaunch = bundleIdentifier;
        itemOnce.type = @"BakgrunnurShortcut";
        itemOnce.icon = [[objc_getClass("SBSApplicationShortcutSystemPrivateIcon") alloc] initWithSystemImageName:@"1.circle"];
        if ([persistenceOnce containsObject:bundleIdentifier]){
            itemOnce.localizedSubtitle = @"Enable Once (Persistence)";
        }else{
            itemOnce.localizedSubtitle = @"Enable Once";
        }
        
        if ([self.queuedIdentifiers containsObject:bundleIdentifier] || [self.immortalIdentifiers containsObject:bundleIdentifier] || [self.advancedMonitoringIdentifiers containsObject:bundleIdentifier]){
            if ([persistenceOnce containsObject:bundleIdentifier]){
                itemOnce.localizedSubtitle = @"Disable Once (Persistence)";
            }else{
                itemOnce.localizedSubtitle = @"Disable Once";
            }
        }
        
        [stackedShortcuts addObject:itemOnce];
    }
    
    //quickPrefsItemsAboveStockItems ? [stockAndCustomItems addObject:item] : [stockAndCustomItems insertObject:item atIndex:0];
    //}
    return stackedShortcuts;
}

-(NSDictionary *)fetchPrefs{
    prefs = nil;
    NSData *data = [NSData dataWithContentsOfFile:PREFS_PATH];
    if (data){
        prefs = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:nil];
    }else{
        prefs = @{};
    }
    return prefs;
}

-(void)setObject:(NSDictionary *)objectDict bundleIdentifier:(NSString *)bundleIdentifier{
    NSMutableDictionary *prefs = [[self fetchPrefs] mutableCopy];
    NSMutableDictionary *identifierDict = [objectDict mutableCopy];
    
    identifierDict[@"identifier"] = bundleIdentifier;
    
    if (prefs && [prefs[@"enabledIdentifier"] firstObject] != nil){
        NSMutableArray *originalIdentifiers = [prefs[@"enabledIdentifier"] mutableCopy];
        NSArray *array = [prefs[@"enabledIdentifier"] valueForKey:@"identifier"];
        NSUInteger idx = [array indexOfObject:bundleIdentifier];
        if (idx != NSNotFound){
            NSMutableDictionary *mergedDict = originalIdentifiers[idx];
            [mergedDict addEntriesFromDictionary:identifierDict];
            [originalIdentifiers replaceObjectAtIndex:idx
                                           withObject:mergedDict];
        }else{
            [originalIdentifiers addObject:identifierDict];
        }
        NSOrderedSet *uniqueIdentifierSet = [NSOrderedSet orderedSetWithArray:originalIdentifiers];
        NSArray *newIdentifiers = [uniqueIdentifierSet array];
        prefs[@"enabledIdentifier"] = newIdentifiers;
    }else{
        prefs[@"enabledIdentifier"] = @[identifierDict];
    }
    [prefs writeToFile:PREFS_PATH atomically:NO];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
}

-(NSDictionary *)taskEventsDeltaForBundleIdentifier:(NSString *)bundleIdentifier history:(NSDictionary *)history{
    NSDictionary *currentTaskEvents = [self taskEventsForBundleIdentifier:bundleIdentifier];
    if (!history) return currentTaskEvents;
    NSMutableDictionary *deltas = [[NSMutableDictionary alloc] init];
    for (NSString *key in [history allKeys]){
        if (!currentTaskEvents[key]) continue;
        deltas[key] = @([currentTaskEvents[key] intValue] - [history[key] intValue]);
    }
    return deltas;
}


-(NSDictionary *)taskEventsForBundleIdentifier:(NSString *)bundleIdentifier{
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_int64(message, "taskEventsForPid", [self pidForBundleIdentifier:bundleIdentifier]);
    xpc_object_t reply = [self sendMessageWithObjectReplyXPC:message];
    return @{@"syscalls_mach":@(xpc_dictionary_get_int64(reply, "syscalls_mach")),
             @"syscalls_unix":@(xpc_dictionary_get_int64(reply, "syscalls_unix")),
             @"syscalls_total":@(xpc_dictionary_get_int64(reply, "syscalls_total")),
             @"messages_sent":@(xpc_dictionary_get_int64(reply, "messages_sent")),
             @"messages_received":@(xpc_dictionary_get_int64(reply, "messages_received")),
             @"faults":@(xpc_dictionary_get_int64(reply, "faults")),
             @"pageins":@(xpc_dictionary_get_int64(reply, "pageins")),
             @"cow_faults":@(xpc_dictionary_get_int64(reply, "cow_faults"))
    };
}

/*
 -(NSDictionary *)taskEventsForBundleIdentifier:(NSString *)bundleIdentifier{
 kern_return_t kr;
 task_info_data_t tinfo;
 mach_msg_type_number_t task_info_count;
 
 task_info_count = TASK_INFO_MAX;
 
 task_t task;
 task_for_pid(mach_task_self(), [self pidForBundleIdentifier:bundleIdentifier], &task);
 
 //mach calls
 kr = task_info(task, TASK_EVENTS_INFO, (task_info_t)tinfo, &task_info_count);
 if (kr != KERN_SUCCESS) {
 return @{};
 }
 task_events_info_t    events_info;
 events_info = (task_events_info_t)tinfo;
 return @{@"syscalls_mach":@(events_info->syscalls_mach),
 @"syscalls_unix":@(events_info->syscalls_unix),
 @"syscalls_total":@(events_info->syscalls_mach + events_info->syscalls_unix),
 @"messages_sent":@(events_info->messages_sent),
 @"messages_received":@(events_info->messages_received),
 @"faults":@(events_info->faults),
 @"pageins":@(events_info->pageins),
 @"cow_faults":@(events_info->cow_faults)
 };
 }
 */

-(float)cpuUsageForBundleIdentifier:(NSString *)bundleIdentifier{
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_int64(message, "cpuUsageForPid", [self pidForBundleIdentifier:bundleIdentifier]);
    xpc_object_t reply = [self sendMessageWithObjectReplyXPC:message];
    return xpc_dictionary_get_double(reply, "cpu_usage");
}

/*
 -(float)cpuUsageForBundleIdentifier:(NSString *)bundleIdentifier{
 kern_return_t kr;
 task_info_data_t tinfo;
 mach_msg_type_number_t task_info_count;
 
 task_info_count = TASK_INFO_MAX;
 
 task_t task;
 task_for_pid(mach_task_self(), [self pidForBundleIdentifier:bundleIdentifier], &task);
 
 HBLogDebug(@"task %u", task);
 
 kr = task_info(task, TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
 if (kr != KERN_SUCCESS) {
 return -1;
 }
 
 task_basic_info_t      basic_info;
 thread_array_t         thread_list;
 mach_msg_type_number_t thread_count;
 
 thread_info_data_t     thinfo;
 mach_msg_type_number_t thread_info_count;
 
 thread_basic_info_t basic_info_th;
 uint32_t stat_thread = 0; // Mach threads
 
 basic_info = (task_basic_info_t)tinfo;
 
 // get threads in the task
 kr = task_threads(task, &thread_list, &thread_count);
 if (kr != KERN_SUCCESS) {
 return -1;
 }
 if (thread_count > 0)
 stat_thread += thread_count;
 
 long tot_sec = 0;
 long tot_usec = 0;
 float tot_cpu = 0;
 int j;
 
 for (j = 0; j < (int)thread_count; j++)
 {
 thread_info_count = THREAD_INFO_MAX;
 kr = thread_info(thread_list[j], THREAD_BASIC_INFO,
 (thread_info_t)thinfo, &thread_info_count);
 if (kr != KERN_SUCCESS) {
 return -1;
 }
 
 basic_info_th = (thread_basic_info_t)thinfo;
 
 if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
 tot_sec = tot_sec + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
 tot_usec = tot_usec + basic_info_th->user_time.microseconds + basic_info_th->system_time.microseconds;
 tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
 }
 
 } // for each thread
 
 kr = vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
 assert(kr == KERN_SUCCESS);
 
 return tot_cpu;
 }
 */

-(int)threadsCountForBundleIdentifier:(NSString *)bundleIdentifier{
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_int64(message, "threadsCountForPid", [self pidForBundleIdentifier:bundleIdentifier]);
    xpc_object_t reply = [self sendMessageWithObjectReplyXPC:message];
    return xpc_dictionary_get_int64(reply, "threads_count");
}

/*
 -(int)threadsCountForBundleIdentifier:(NSString *)bundleIdentifier{
 thread_array_t threadList;
 mach_msg_type_number_t threadCount;
 task_t task;
 
 kern_return_t kernReturn = task_for_pid(mach_task_self(), [[Bakgrunnur sharedInstance] pidForBundleIdentifier:bundleIdentifier], &task);
 if (kernReturn != KERN_SUCCESS) {
 return -1;
 }
 
 kernReturn = task_threads(task, &threadList, &threadCount);
 if (kernReturn != KERN_SUCCESS) {
 return -1;
 }
 vm_deallocate (mach_task_self(), (vm_address_t)threadList, threadCount * sizeof(thread_act_t));
 
 return threadCount;
 }
 */

-(void)createXPCConnection{
    self.bkgd_xpc_connection =
    xpc_connection_create_mach_service("com.udevs.bkgd", NULL, 0);
    xpc_connection_set_event_handler(self.bkgd_xpc_connection, ^(xpc_object_t event) {
        // Same semantics as a connection created through
        // xpc_connection_create().
    });
    xpc_connection_resume(self.bkgd_xpc_connection);
}

/*
 -(void)createPowerdXPCConnection{
 self.powerd_xpc_connection =
 xpc_connection_create_mach_service(POWERD_XPC_NAME, NULL, 0);
 xpc_connection_set_event_handler(self.powerd_xpc_connection, ^(xpc_object_t event) {
 // Same semantics as a connection created through
 // xpc_connection_create().
 });
 xpc_connection_resume(self.powerd_xpc_connection);
 }
 
 -(BOOL)sendMessageWithBoolReplyPowerdXPC:(xpc_object_t)message{
 BOOL ret = NO;
 if (self.powerd_xpc_connection){
 xpc_object_t reply = xpc_connection_send_message_with_reply_sync(self.powerd_xpc_connection, message);
 if (xpc_get_type(reply) == XPC_TYPE_DICTIONARY){
 ret = xpc_dictionary_get_bool(reply, "result");
 }
 //xpc_release(reply);
 }
 return ret;
 }
 */

-(BOOL)sendMessageWithBoolReplyXPC:(xpc_object_t)message{
    BOOL ret = NO;
    if (self.bkgd_xpc_connection){
        xpc_object_t reply = xpc_connection_send_message_with_reply_sync(self.bkgd_xpc_connection, message);
        if (xpc_get_type(reply) == XPC_TYPE_DICTIONARY){
            ret = xpc_dictionary_get_bool(reply, "result");
        }
        //xpc_release(reply);
    }
    return ret;
}

-(xpc_object_t)sendMessageWithObjectReplyXPC:(xpc_object_t)message{
    //xpc_object_t ret = xpc_dictionary_create(NULL, NULL, 0);
    if (self.bkgd_xpc_connection){
        xpc_object_t reply = xpc_connection_send_message_with_reply_sync(self.bkgd_xpc_connection, message);
        /*
         HBLogDebug(@"reply type: %@", xpc_get_type(reply));
         if (xpc_get_type(reply) == XPC_TYPE_ERROR){
         HBLogDebug(@"reply error: %s", xpc_dictionary_get_string(reply, XPC_ERROR_KEY_DESCRIPTION));
         
         }
         */
        if (xpc_get_type(reply) == XPC_TYPE_DICTIONARY){
            xpc_object_t result = xpc_dictionary_get_value(reply, "result");
            //HBLogDebug(@"syscalls_mach %llu", xpc_dictionary_get_uint64(result, "syscalls_mach"));
            
            return result;
        }
        //xpc_release(reply);
    }
    return xpc_dictionary_create(NULL, NULL, 0);
}

-(void)notifySleepingState:(BOOL)sleep{
    HBLogDebug(@"Will notify to %@", sleep?@"be able to sleep again":@"standy system");
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_bool(message, "updateSleepingState", sleep);
    [self sendMessageWithBoolReplyXPC:message];
}

/*
 -(void)notifySleepingState:(BOOL)sleep{
 HBLogDebug(@"Will notify to %@", sleep?@"be able to sleep again":@"standy system");
 
 xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
 xpc_dictionary_set_bool(message, "BAKGRUNNUR_updateSleepingState", sleep);
 [self sendMessageWithBoolReplyPowerdXPC:message];
 }
 */


-(NSDictionary *)netstatForBundleIdentifiers:(NSArray *)identifiers{
    if (!identifiers) return nil;
    NSMutableDictionary *stats = [NSMutableDictionary dictionary];
    xpc_object_t pids = xpc_array_create(NULL, 0);
    NSMutableDictionary *pidsByIdentifier = [NSMutableDictionary dictionary];
    for (NSString *bundleIdentifier in identifiers){
        int pid = [self pidForBundleIdentifier:bundleIdentifier];
        xpc_array_set_uint64(pids, ((size_t)(-1)), (uint64_t)pid);
        pidsByIdentifier[bundleIdentifier] = @(pid);
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_value(message, "netstatForPids", pids);
    xpc_object_t reply = [self sendMessageWithObjectReplyXPC:message];
    
    NSUInteger idx = 0;
    for (NSNumber *pid in [pidsByIdentifier allValues]){
        __block NSMutableArray *activeConnectionsArray = [NSMutableArray array];
        xpc_object_t activeConnections = xpc_dictionary_get_value(reply, [[pid stringValue] UTF8String]);
        if (activeConnections && xpc_get_type(activeConnections) == XPC_TYPE_ARRAY){
            xpc_array_apply(activeConnections, ^_Bool(size_t index, xpc_object_t value) {
                
                NSDictionary *stat = @{@"rxbytes":@(xpc_dictionary_get_uint64(value, "rxbytes")),
                                       @"txbytes":@(xpc_dictionary_get_uint64(value, "txbytes")),
                                       @"rhiwat":@(xpc_dictionary_get_uint64(value, "rhiwat")),
                                       @"shiwat":@(xpc_dictionary_get_uint64(value, "shiwat")),
                                       @"send_q":@(xpc_dictionary_get_uint64(value, "send_q")),
                                       @"recv_q":@(xpc_dictionary_get_uint64(value, "recv_q")),
                                       @"epid":@(xpc_dictionary_get_uint64(value, "epid")),
                                       @"proto":[NSString stringWithCString:xpc_dictionary_get_string(value, "proto") encoding:NSUTF8StringEncoding],
                                       @"foreign_addr":[NSString stringWithCString:xpc_dictionary_get_string(value, "foreign_addr") encoding:NSUTF8StringEncoding],
                                       @"local_addr":[NSString stringWithCString:xpc_dictionary_get_string(value, "local_addr") encoding:NSUTF8StringEncoding],
                                       @"state":[NSString stringWithCString:xpc_dictionary_get_string(value, "state") encoding:NSUTF8StringEncoding]
                };
                [activeConnectionsArray addObject:stat];
                return YES;
            });
            
        }
        stats[[pidsByIdentifier allKeys][idx]] = activeConnectionsArray;
        idx++;
    }
    return stats;
}

-(void)netstatForBundleIdentifiers:(NSArray *)identifiers completion:(void (^)(NSDictionary *result))completionHandler{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (!identifiers && completionHandler){
            completionHandler(nil);
        }else{
            if (completionHandler){
                completionHandler([self netstatForBundleIdentifiers:identifiers]);
            }
        }
    });
}

-(NSDictionary *)rxbytesForBundleIdentifiers:(NSArray *)bundleIdentifiers stats:(NSDictionary *)stats{
    NSMutableDictionary *rxbytesResult = [NSMutableDictionary dictionary];
    for (NSString *bundleIdentifier in stats){
        NSArray *rxbytesESTABLISHED = [stats[bundleIdentifier] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(state == %@)", @"ESTABLISHED"]];
        NSNumber *rxbytesTotal = [[rxbytesESTABLISHED valueForKey:@"rxbytes"] valueForKeyPath:@"@sum.self"];
        rxbytesResult[bundleIdentifier] = rxbytesTotal;
        //HBLogDebug(@"%@ ** rxbytesFormatted: %@", bundleIdentifier, [NSByteCountFormatter stringFromByteCount:[rxbytesTotal unsignedLongLongValue] countStyle:NSByteCountFormatterCountStyleFile]);
    }
    return rxbytesResult;
}

-(void)rxbytesForBundleIdentifiers:(NSArray *)bundleIdentifiers stats:(NSDictionary *)stats completion:(void (^)(NSDictionary *result))completionHandler{
    if (!stats){
        [self netstatForBundleIdentifiers:bundleIdentifiers completion:^(NSDictionary *statsResult){
            if (completionHandler){
                completionHandler([self rxbytesForBundleIdentifiers:bundleIdentifiers stats:statsResult]);
            }
        }];
    }else{
        if (completionHandler){
            completionHandler([self rxbytesForBundleIdentifiers:bundleIdentifiers stats:stats]);
        }
    }
}

-(void)netStatDeltaForBundleIdentifiers:(NSArray *)bundleIdentifiers history:(NSDictionary *)histories cachedStats:(NSDictionary *)cachedStats completion:(void (^)(NSDictionary *deltas, NSDictionary *fullStats))completionHandler{
    
    __block NSMutableDictionary *deltas = [[NSMutableDictionary alloc] init];
    
    [self netstatForBundleIdentifiers:(cachedStats?nil:bundleIdentifiers) completion:^(NSDictionary *stats){
        
        if (cachedStats){
            stats = cachedStats;
        }
        
        [self rxbytesForBundleIdentifiers:bundleIdentifiers stats:stats completion:^(NSDictionary *rxbytesStats){
            
            for (NSString *bundleIdentifier in bundleIdentifiers){
                NSNumber *rxStats = rxbytesStats[bundleIdentifier];
                NSDictionary *history = histories[bundleIdentifier];
                //HBLogDebug(@"HISTORY: %@", history);
                NSMutableDictionary *delta = deltas[bundleIdentifier] ?: [NSMutableDictionary dictionary];
                if (rxStats && history){
                    delta[@"rxbytes"] = @(([rxStats unsignedLongLongValue] > [history[@"rxbytes"] unsignedLongLongValue] ? [rxStats unsignedLongLongValue] - [history[@"rxbytes"] unsignedLongLongValue] : 0));
                    HBLogDebug(@"delta: %@ rxStats - history: %llu - %llu", delta[@"rxbytes"], [rxStats unsignedLongLongValue], [history[@"rxbytes"] unsignedLongLongValue]);
                }else{
                    delta[@"rxbytes"] = rxStats?:@0;
                }
                //HBLogDebug(@"rx-delta: %@", delta);
                [deltas setObject:delta forKey:bundleIdentifier];
            }
            
            [self txbytesForBundleIdentifiers:bundleIdentifiers stats:stats completion:^(NSDictionary *txbytesStats){
                
                for (NSString *bundleIdentifier in bundleIdentifiers){
                    NSNumber *txStats = txbytesStats[bundleIdentifier];
                    NSDictionary *history = histories[bundleIdentifier];
                    NSMutableDictionary *delta = deltas[bundleIdentifier] ?: [NSMutableDictionary dictionary];
                    if (txStats && history){
                        delta[@"txbytes"] = @(([txStats unsignedLongLongValue] > [history[@"txbytes"] unsignedLongLongValue] ? [txStats unsignedLongLongValue] - [history[@"txbytes"] unsignedLongLongValue] : 0));
                    }else{
                        delta[@"txbytes"] = txStats?:@0;
                    }
                    //HBLogDebug(@"tx-delta: %@", delta);
                    [deltas setObject:delta forKey:bundleIdentifier];
                }
                
                if (completionHandler){
                    completionHandler(deltas, stats);
                }
            }];
            
        }];
    }];
}


-(NSDictionary *)txbytesForBundleIdentifiers:(NSArray *)bundleIdentifiers stats:(NSDictionary *)stats{
    NSMutableDictionary *txbytesResult = [NSMutableDictionary dictionary];
    for (NSString *bundleIdentifier in stats){
        NSArray *txbytesESTABLISHED = [stats[bundleIdentifier] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(state == %@)", @"ESTABLISHED"]];
        NSNumber *txbytesTotal = [[txbytesESTABLISHED valueForKey:@"txbytes"] valueForKeyPath:@"@sum.self"];
        txbytesResult[bundleIdentifier] = txbytesTotal;
        //HBLogDebug(@"%@ ** txbytesFormatted: %@", bundleIdentifier, [NSByteCountFormatter stringFromByteCount:[txbytesTotal unsignedLongLongValue] countStyle:NSByteCountFormatterCountStyleFile]);
    }
    
    return txbytesResult;
}

-(void)txbytesForBundleIdentifiers:(NSArray *)bundleIdentifiers stats:(NSDictionary *)stats  completion:(void (^)(NSDictionary *result))completionHandler{
    if (!stats){
        [self netstatForBundleIdentifiers:bundleIdentifiers completion:^(NSDictionary *statsResult){
            if (completionHandler){
                completionHandler([self txbytesForBundleIdentifiers:bundleIdentifiers stats:statsResult]);
            }
        }];
    }else{
        if (completionHandler){
            completionHandler([self txbytesForBundleIdentifiers:bundleIdentifiers stats:stats]);
        }
    }
}

-(void)launchBundleIdentifier:(NSString *)bundleID trusted:(BOOL)trusted suspended:(BOOL)suspend withPayloadURL:(NSString *)payloadURL completion:(void (^)(NSError *error))completionHandler{
    
    NSMutableDictionary *opts = [[NSMutableDictionary alloc] init];
    opts[@"__PayloadOptions"] = @{@"UIApplicationLaunchOptionsSourceApplicationKey":@"com.apple.springboard"};
    //if (suspend){
    opts[@"__ActivateSuspended"] = @(suspend);
    opts[@"__PromptUnlockDevice"] = @YES;
    opts[@"__UnlockDevice"] = @YES;
    opts[@"processLaunchIntent"] = @4;
    //}
    if (suspend){
        opts[@"__SBWorkspaceOpenOptionUnlockResult"] = @1;
    }
    if (payloadURL) opts[@"__PayloadURL"] = payloadURL;
    
    FBProcessManager *fbAppProcManager = [objc_getClass("FBProcessManager") sharedInstance];
    
    FBApplicationProcess *sbFBAppProc  = [[fbAppProcManager applicationProcessesForBundleIdentifier:@"com.apple.springboard"] firstObject];
    
    FBSystemServiceOpenApplicationRequest *fbOpenAppRequest = [objc_getClass("FBSystemServiceOpenApplicationRequest") request];
    [fbOpenAppRequest setClientProcess:sbFBAppProc];
    [fbOpenAppRequest setTrusted:trusted];
    [fbOpenAppRequest setBundleIdentifier:bundleID];
    
    FBSOpenApplicationOptions *fbOpenAppOpts = [objc_getClass("FBSOpenApplicationOptions") optionsWithDictionary:opts];
    [fbOpenAppRequest setOptions:fbOpenAppOpts];
    
    FBSystemService *sysService = [objc_getClass("FBSystemService") sharedInstance];
    SBMainWorkspace *sbMainWS = [objc_getClass("SBMainWorkspace") sharedInstance];
    
    
    [sbMainWS systemService:sysService handleOpenApplicationRequest:fbOpenAppRequest withCompletion:^(NSError *error){
        if (completionHandler){
            completionHandler(error);
        }
        
    }];
    
    //SUSPENDED
    //NSDictionary *opts = @{@"LSOpenSensitiveURLOption":@YES, @"__LaunchOrigin":@"CCUIAppLaunchOriginControlCenter", @"__PayloadOptions":@{@"UIApplicationLaunchOptionsSourceApplicationKey":@"com.apple.springboard"}, @"__PayloadURL":@"spotify:", @"__PromptUnlockDevice":@YES, @"__UnlockDevice":@YES, @"__ActivateSuspended":@NO};
    
    //FOREGROUND
    //NSDictionary *opts = @{@"LSOpenSensitiveURLOption":@1, @"__LaunchOrigin":@"CCUIAppLaunchOriginControlCenter", @"__PayloadOptions":@{@"UIApplicationLaunchOptionsSourceApplicationKey":@"com.apple.springboard"}, @"__PayloadURL":@"spotify://",@"__SBWorkspaceOpenOptionUnlockResult":@1, @"__LaunchEnvironment":@"secureOnLockScreen"};
    
}

@end
