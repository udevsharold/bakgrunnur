#import "common.h"
#import "PrivateHeaders.h"
#import "Bakgrunnur.h"
#import "NSTask.h"
#import <pthread.h>
#import <mach/mach.h>
#import <dlfcn.h>

#define defaultExpirationTime 10800 // 3hours

static NSDictionary *prefs;
static BOOL enabled = YES;
static NSArray *enabledIdentifier;
static NSArray *allEntriesIdentifier;
static BOOL firstInit = YES;
static long long preferredAccessoryType = 2;
static BOOL showIndicatorOnDock = NO;
static BOOL mainWSStarted = NO;
//static BOOL showForceTouchShortcut = YES;
static SBFloatingDockView *floatingDockView;
static BOOL isFolderTransitioning = NO;
static double globalTimeSpan = 1800.0/2.0;
static BOOL quickActionMaster = YES;
static BOOL quickActionOnce = NO;

@implementation Bakgrunnur

+(void)load{
    [self sharedInstance];
    /*
     @autoreleasepool {
     NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
     
     if (args.count != 0) {
     NSString *executablePath = args[0];
     
     if (executablePath) {
     NSString *processName = [executablePath lastPathComponent];
     if ([processName isEqualToString:@"SpringBoard"]){
     [self sharedInstance];
     }
     }
     }
     }
     */
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
        self.queuedIdentifiers = [[NSMutableArray alloc] init];
        self.immortalIdentifiers = [[NSMutableArray alloc] init];
        self.advancedMonitoringIdentifiers = [[NSMutableArray alloc] init];
        self.advancedMonitoringHistory = [[NSMutableDictionary alloc] init];
        self.pendingAccessoryUpdateFolderID = [[NSMutableArray alloc] init];
        self.grantedOnceIdentifiers = [[NSMutableArray alloc] init];

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
    BOOL isUILocked = [[%c(SBLockScreenManager) sharedInstance] isUILocked];
    if (isUILocked) isFrontMost = NO;
    return isFrontMost;
}

-(void)updateLabelAccessory:(NSString *)identifier{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[((SBIconController *)[%c(SBIconController) sharedInstance]).model applicationIconForBundleIdentifier:identifier] _notifyAccessoriesDidUpdate];
        [self updateLabelAccessoryForDockItem:identifier];
    });
}

-(void)updateLabelAccessoryForDockItem:(NSString *)identifier{
    if (floatingDockView){
        NSArray *fullIconsList = @[];
        fullIconsList = [fullIconsList arrayByAddingObjectsFromArray:floatingDockView.recentIconListView.visibleIcons];
        fullIconsList = [fullIconsList arrayByAddingObjectsFromArray:floatingDockView.recentIconListView.visibleIcons];
        
        for (SBApplicationIcon *icon in fullIconsList){
            if ([icon.applicationBundleID isEqualToString:identifier]){
                [icon _notifyAccessoriesDidUpdate];
                break;
            }
        }
    }
}

-(void)retireScene:(id)timer{
    NSDictionary *userInfo = [timer userInfo];
    [self _retireScene:userInfo[@"identifier"]];
}

-(void)_retireAllScenesIn:(NSMutableArray *)identifiers{
    HBLogDebug(@"Retiring all scenes in %@", identifiers);
    
    FBSceneManager *sceneManager  = [%c(FBSceneManager) sharedInstance];
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
            
            FBSMutableSceneSettings *backgroundingSceneSettings = scene.mutableSettings;
            [backgroundingSceneSettings setForeground:NO];
            [backgroundingSceneSettings setBackgrounded:YES];
            
            [sceneManager _applyMutableSettings:backgroundingSceneSettings toScene:scene withTransitionContext:nil completion:nil];
            
            //SBApplicationController *sbAppController = [%c(SBApplicationController) sharedInstance];
            //SBApplication *sbApp = [sbAppController applicationWithBundleIdentifier:scene.clientProcess.identity.embeddedApplicationIdentifier];
            //HBLogDebug(@"taskstate for %@: %lld", scene.clientProcess.identity.embeddedApplicationIdentifier, sbApp.processState.taskState);
            //HBLogDebug(@"running for %@: %@", scene.clientProcess.identity.embeddedApplicationIdentifier, sbApp.processState.running?@"YES":@"NO");
            
            //if (sbApp.processState.taskState <= 2){
            //[sceneManager destroyScene:scene.identifier withTransitionContext:nil];
            //}
            
            //[self.queuedIdentifiers removeObject:identifier];
            //[self.immortalIdentifiers removeObject:identifier];
            //[self.advancedMonitoringIdentifiers removeObject:identifier];
            //[self.advancedMonitoringHistory removeObjectForKey:identifier];
            
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

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self updateDarkWakeState];
    });
    
    for (NSString *key in toBeRemovedAdvancedMonitoringHistoryIdentifiers){
        [self.advancedMonitoringHistory removeObjectForKey:key];
    }
    
}

-(void)_retireScene:(NSString *)identifier{
    HBLogDebug(@"Retiring %@", identifier);
    
    FBSceneManager *sceneManager  = [%c(FBSceneManager) sharedInstance];
    NSMutableDictionary *scenesByID = [sceneManager valueForKey:@"_scenesByID"];
    
    [scenesByID enumerateKeysAndObjectsUsingBlock:^(NSString *sceneID, FBScene *scene, BOOL *stop) {
        if ([identifier isEqualToString:scene.clientProcess.identity.embeddedApplicationIdentifier]) {
            
            if (![self.retiringIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]){
                [self.retiringIdentifiers addObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
            }
            
            FBSMutableSceneSettings *backgroundingSceneSettings = scene.mutableSettings;
            [backgroundingSceneSettings setForeground:NO];
            [backgroundingSceneSettings setBackgrounded:YES];
            
            [sceneManager _applyMutableSettings:backgroundingSceneSettings toScene:scene withTransitionContext:nil completion:nil];
            
            //SBApplicationController *sbAppController = [%c(SBApplicationController) sharedInstance];
            //SBApplication *sbApp = [sbAppController applicationWithBundleIdentifier:scene.clientProcess.identity.embeddedApplicationIdentifier];
            //HBLogDebug(@"taskstate for %@: %lld", scene.clientProcess.identity.embeddedApplicationIdentifier, sbApp.processState.taskState);
            //HBLogDebug(@"running for %@: %@", scene.clientProcess.identity.embeddedApplicationIdentifier, sbApp.processState.running?@"YES":@"NO");
            
            //if (sbApp.processState.taskState <= 2){
            //[sceneManager destroyScene:scene.identifier withTransitionContext:nil];
            //}
            
            [self.queuedIdentifiers removeObject:identifier];
            [self.immortalIdentifiers removeObject:identifier];
            [self.advancedMonitoringIdentifiers removeObject:identifier];
            [self.grantedOnceIdentifiers removeObject:identifier];
            [self.advancedMonitoringHistory removeObjectForKey:identifier];
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
    FBProcessManager *processManager  = [%c(FBProcessManager) sharedInstance];
    FBProcess *proc = [[processManager processesForBundleIdentifier:bundleIdentifier] firstObject];
    return proc.pid;
}

-(void)terminateProcess:(id)timer{
    NSDictionary *userInfo = [timer userInfo];
    [self _terminateProcess:userInfo[@"identifier"]];
}

-(void)_terminateProcess:(NSString *)identifier{
    HBLogDebug(@"Terminating %@", identifier);
    FBProcessManager *processManager  = [%c(FBProcessManager) sharedInstance];
    FBProcess *proc = [[processManager processesForBundleIdentifier:identifier] firstObject];
    if (proc.pid > 0){
        HBLogDebug(@"pid for %@: %d", identifier, proc.pid);
        NSArray *taskArgs = @[@"-KILL", [NSString stringWithFormat:@"%d", proc.pid]];
        NSTask * task = [[NSTask alloc] init];
        [task setLaunchPath:@"/bin/kill"];
        [task setArguments:taskArgs];
        [task launch];
        [self.queuedIdentifiers removeObject:identifier];
        [self.immortalIdentifiers removeObject:identifier];
        [self.advancedMonitoringIdentifiers removeObject:identifier];
        [self.grantedOnceIdentifiers removeObject:identifier];
        [self.advancedMonitoringHistory removeObjectForKey:identifier];
        [self updateLabelAccessory:identifier];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [self updateDarkWakeState];
        });
        HBLogDebug(@"Terminated %@", identifier);
    }
    //[self.ipcCenter sendMessageAndReceiveReplyName:@"terminateProcess" userInfo:userInfo];
}


-(void)invalidateQueue:(NSString *)identifier{
    PCPersistentInterfaceManager *pctimermanager = [%c(PCPersistentInterfaceManager) sharedInstance];
    NSMapTable *queues = MSHookIvar<NSMapTable *>(pctimermanager, "_delegatesAndQueues");
    NSArray *timerinqueues = [queues allKeys];
    //HBLogDebug(@"allkeys: %@", timerinqueues);
    [self.immortalIdentifiers removeObject:identifier];
    [self.advancedMonitoringIdentifiers removeObject:identifier];
    [self.advancedMonitoringHistory removeObjectForKey:identifier];
    //[self.grantedOnceIdentifiers removeObject:identifier];

    for (PCPersistentTimer *persistenttimer in timerinqueues){
        PCSimpleTimer *_timer = MSHookIvar<PCSimpleTimer *>(persistenttimer, "_simpleTimer");
        NSString *serviceindentifier = MSHookIvar<NSString *>(_timer, "_serviceIdentifier");
        //HBLogDebug(@"serviceindentifier: %@", serviceindentifier);
        if ([serviceindentifier isEqualToString:[NSString stringWithFormat:@"com.udevs.bakgrunnur.%@", identifier]]){
            [self.queuedIdentifiers removeObject:identifier];
            //[self updateLabelAccessory:identifier];
            [_timer invalidate];
            _timer = nil;
            HBLogDebug(@"Invalidated %@", identifier);
            break;
        }
    }
    [self updateLabelAccessory:identifier];
    
}

-(void)invalidateAllQueues{
    PCPersistentInterfaceManager *pctimermanager = [%c(PCPersistentInterfaceManager) sharedInstance];
    NSMapTable *queues = MSHookIvar<NSMapTable *>(pctimermanager, "_delegatesAndQueues");
    NSArray *timerinqueues = [queues allKeys];
    //HBLogDebug(@"allkeys: %@", timerinqueues);
    for (NSString *identifier in self.immortalIdentifiers){
        [self _retireScene:identifier];
        [self.immortalIdentifiers removeObject:identifier];
        [self.advancedMonitoringIdentifiers removeObject:identifier];
        //[self.grantedOnceIdentifiers removeObject:identifier];
        [self.advancedMonitoringHistory removeObjectForKey:identifier];
        [self updateLabelAccessory:identifier];
    }
    
    
    for (PCPersistentTimer *persistenttimer in timerinqueues){
        PCSimpleTimer *_timer = MSHookIvar<PCSimpleTimer *>(persistenttimer, "_simpleTimer");
        NSString *serviceindentifier = MSHookIvar<NSString *>(_timer, "_serviceIdentifier");
        //HBLogDebug(@"serviceindentifier: %@", serviceindentifier);
        if ([serviceindentifier containsString:@"com.udevs.bakgrunnur."]){
            NSString *identifier = [serviceindentifier stringByReplacingOccurrencesOfString:@"com.udevs.bakgrunnur." withString:@""];
            [self _retireScene:identifier];
            [self.queuedIdentifiers removeObject:identifier];
            [self updateLabelAccessory:identifier];
            [_timer invalidate];
            _timer = nil;
            HBLogDebug(@"Invalidated %@", identifier);
        }
    }
}

-(void)invalidateAllQueuesIn:(NSArray *)identifiers{
    PCPersistentInterfaceManager *pctimermanager = [%c(PCPersistentInterfaceManager) sharedInstance];
    NSMapTable *queues = MSHookIvar<NSMapTable *>(pctimermanager, "_delegatesAndQueues");
    NSArray *timerinqueues = [queues allKeys];
    //HBLogDebug(@"allkeys: %@", timerinqueues);
    
    for (NSString *identifier in identifiers){
        [self _retireScene:identifier];
        [self.immortalIdentifiers removeObject:identifier];
        [self.advancedMonitoringIdentifiers removeObject:identifier];
        //[self.grantedOnceIdentifiers removeObject:identifier];
        [self.advancedMonitoringHistory removeObjectForKey:identifier];
        [self updateLabelAccessory:identifier];
    }
    
    for (PCPersistentTimer *persistenttimer in timerinqueues){
        PCSimpleTimer *_timer = MSHookIvar<PCSimpleTimer *>(persistenttimer, "_simpleTimer");
        NSString *serviceindentifier = MSHookIvar<NSString *>(_timer, "_serviceIdentifier");
        //HBLogDebug(@"serviceindentifier: %@", serviceindentifier);
        if ([serviceindentifier containsString:@"com.udevs.bakgrunnur."]){
            NSString *identifier = [serviceindentifier stringByReplacingOccurrencesOfString:@"com.udevs.bakgrunnur." withString:@""];
            if ([identifiers containsObject:identifier]){
                [self _retireScene:identifier];
                [self.queuedIdentifiers removeObject:identifier];
                [self updateLabelAccessory:identifier];
                [_timer invalidate];
                _timer = nil;
                HBLogDebug(@"Invalidated %@", identifier);
            }
        }
    }
}

-(void)queueProcess:(NSString *)identifier softRemoval:(BOOL)removeGracefully expirationTime:(double)expTime{
    
    PCPersistentTimer *timer = [[%c(PCPersistentTimer) alloc] initWithFireDate:[[NSDate date] dateByAddingTimeInterval:expTime] serviceIdentifier:[NSString stringWithFormat:@"com.udevs.bakgrunnur.%@", identifier] target:self selector:(removeGracefully?@selector(retireScene:):@selector(terminateProcess:)) userInfo:@{@"identifier":identifier}];
    
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
    //SBApplicationController *sbAppController = [%c(SBApplicationController) sharedInstance];
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
        self.advancedMonitoringTimer = [[%c(PCPersistentTimer) alloc] initWithFireDate:[[NSDate date] dateByAddingTimeInterval:interval] serviceIdentifier:@"com.udevs.bakgrunnur-advanced-monitoring" target:self selector:@selector(monitoringUsage:) userInfo:@{@"scheduledCall":@YES}];
        
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
        SBSApplicationShortcutItem *item = [[%c(SBSApplicationShortcutItem) alloc] init];
        item.localizedTitle = @"Bakgrunnur";
        item.localizedSubtitle = isEnabled ? @"Disable" : @"Enable";
        item.bundleIdentifierToLaunch = bundleIdentifier;
        item.type = @"BakgrunnurShortcut";
        item.icon = [[%c(SBSApplicationShortcutSystemPrivateIcon) alloc] initWithSystemImageName:@"hourglass"];
        [stackedShortcuts addObject:item];
    }
    
    if (!isEnabled && quickActionOnce){
        SBSApplicationShortcutItem *itemOnce = [[%c(SBSApplicationShortcutItem) alloc] init];
        itemOnce.localizedTitle = @"Bakgrunnur";
        itemOnce.bundleIdentifierToLaunch = bundleIdentifier;
        itemOnce.type = @"BakgrunnurShortcut";
        itemOnce.icon = [[%c(SBSApplicationShortcutSystemPrivateIcon) alloc] initWithSystemImageName:@"1.circle"];
        itemOnce.localizedSubtitle = @"Enable Once";
        
        if ([self.queuedIdentifiers containsObject:bundleIdentifier] || [self.immortalIdentifiers containsObject:bundleIdentifier] || [self.advancedMonitoringIdentifiers containsObject:bundleIdentifier]){
            itemOnce.localizedSubtitle = @"Disable Once";
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

@end

%group SPRINGBOARD_PROCESS
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
        Bakgrunnur *bakgrunnur = [Bakgrunnur sharedInstance];
        if ([enabledIdentifier containsObject:self.bundleIdentifier]){
            [[Bakgrunnur sharedInstance].grantedOnceIdentifiers removeObject:self.bundleIdentifier];
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
        Bakgrunnur *bakgrunnur = [Bakgrunnur sharedInstance];
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
        Bakgrunnur *bakgrunnur = [Bakgrunnur sharedInstance];
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
        if (([bakgrunnur.queuedIdentifiers containsObject:[self.icon applicationBundleID]] || [bakgrunnur.immortalIdentifiers containsObject:[self.icon applicationBundleID]] || (isInFolder && !isFolderTransitioning)) && (!self.labelHidden || (self.inDock && showIndicatorOnDock))){
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
    if (enabled && (quickActionMaster || quickActionOnce)){
        NSString *bundleIdentifier;
        if ([self respondsToSelector:@selector(applicationBundleIdentifier)]) {
            bundleIdentifier = [self applicationBundleIdentifier]; //iOS 13.1.3
        } else if ([self respondsToSelector:@selector(applicationBundleIdentifierForShortcuts)]) {
            bundleIdentifier = [self applicationBundleIdentifierForShortcuts]; //iOS 13.2.2
        }
        //if (![bundleIdentifier isEqualToString:@"com.apple.Preferences"]) return %orig;
        if (bundleIdentifier){
            NSArray<SBSApplicationShortcutItem*> *stackedShortcuts = [[Bakgrunnur sharedInstance] stackBakgrunnurShortcut:%orig bundleIdentifier:bundleIdentifier];
            return stackedShortcuts;
        }
    }
    return %orig;
}

+(void)activateShortcut:(SBSApplicationShortcutItem *)shortcut withBundleIdentifier:(NSString *)bundleIdentifier forIconView:(id)arg3{
    if (enabled && (quickActionMaster || quickActionOnce)){
        Bakgrunnur *bakgrunnur = [Bakgrunnur sharedInstance];
        if (bundleIdentifier && [[shortcut type] isEqualToString:@"BakgrunnurShortcut"]) {
            if ([shortcut.localizedSubtitle isEqualToString:@"Disable"]){
                [bakgrunnur.grantedOnceIdentifiers removeObject:bundleIdentifier];
                [bakgrunnur setObject:@{@"enabled":@NO} bundleIdentifier:bundleIdentifier];
                return;
            }else if (bundleIdentifier && [shortcut.localizedSubtitle isEqualToString:@"Enable"]){
                [bakgrunnur.grantedOnceIdentifiers removeObject:bundleIdentifier];
                [bakgrunnur setObject:@{@"enabled":@YES} bundleIdentifier:bundleIdentifier];
            }else if (bundleIdentifier && [shortcut.localizedSubtitle isEqualToString:@"Enable Once"]){
                [bakgrunnur.grantedOnceIdentifiers removeObject:bundleIdentifier];
                    [bakgrunnur.grantedOnceIdentifiers addObject:bundleIdentifier];
            }else if (bundleIdentifier && [shortcut.localizedSubtitle isEqualToString:@"Disable Once"]){
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
 Bakgrunnur *bakgrunnur = [Bakgrunnur sharedInstance];
 
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
 Bakgrunnur *bakgrunnur = [Bakgrunnur sharedInstance];
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
 Bakgrunnur *bakgrunnur = [Bakgrunnur sharedInstance];
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

%hook SBMainWorkspace
+(id)start{
    if (enabled){
        id rtn = %orig;
        mainWSStarted = YES;
        return rtn;
    }
    return %orig;
}
%end

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

%hook FBSceneManager

-(void)_noteSceneMovedToForeground:(FBScene *)scene{
    //HBLogDebug(@"_noteSceneMovedToForeground: %@", scene);
    %orig;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (enabled){
            Bakgrunnur *bakgrunnur = [Bakgrunnur sharedInstance];
            if ([enabledIdentifier
                 containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier] || [bakgrunnur.grantedOnceIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]){
                //NSUInteger identifierIdx = [enabledIdentifier indexOfObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                //BOOL isImmortal = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"retire"]) ? ([prefs[@"enabledIdentifier"][identifierIdx][@"retire"] intValue] > 1) : NO;
                //if (isImmortal){
                //[[Bakgrunnur sharedInstance].immortalIdentifiers removeObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                //}else{
                /*
                if ([bakgrunnur.queuedIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier] || [bakgrunnur.immortalIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier] || [bakgrunnur.advancedMonitoringIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]){
                [bakgrunnur.grantedOnceIdentifiers removeObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                }
                */
                [bakgrunnur invalidateQueue:scene.clientProcess.identity.embeddedApplicationIdentifier];
                HBLogDebug(@"Reset expiration for %@", scene.clientProcess.identity.embeddedApplicationIdentifier);
            }
        }
    });
}

-(void)_noteSceneMovedToBackground:(FBScene *)scene{
    //HBLogDebug(@"_noteSceneMovedToBackground: %@", [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication]);
    %orig;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (enabled){
            Bakgrunnur *bakgrunnur = [Bakgrunnur sharedInstance];
            //HBLogDebug(@"bakgrunnur.grantedOnceIdentifiers: %@", bakgrunnur.grantedOnceIdentifiers);
            BOOL alreadyQueued = [bakgrunnur.queuedIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier] || [bakgrunnur.immortalIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier] || [bakgrunnur.advancedMonitoringIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
            
            if (([enabledIdentifier containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier] || [bakgrunnur.grantedOnceIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]) && (![bakgrunnur.retiringIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]) && scene.valid && !alreadyQueued){
                
                NSUInteger identifierIdx = [allEntriesIdentifier indexOfObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                BOOL isImmortal = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"retire"]) ? ([prefs[@"enabledIdentifier"][identifierIdx][@"retire"] intValue] == 2) : NO;
                BOOL isAdvancedMonitoring = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"retire"]) ? ([prefs[@"enabledIdentifier"][identifierIdx][@"retire"] intValue] == 3) : NO;
                BOOL enabledAppNotifications = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"] boolValue] : NO;
                //[bakgrunnur.grantedOnceIdentifiers removeObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                [bakgrunnur invalidateQueue:scene.clientProcess.identity.embeddedApplicationIdentifier];
                if (isImmortal || isAdvancedMonitoring){
                    [bakgrunnur.immortalIdentifiers addObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                    [bakgrunnur updateLabelAccessory:scene.clientProcess.identity.embeddedApplicationIdentifier];
                    if (isAdvancedMonitoring){
                        [bakgrunnur.advancedMonitoringIdentifiers addObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                        [bakgrunnur startAdvancedMonitoringWithInterval:globalTimeSpan];
                    }
                }else{
                    double expiration = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"expiration"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"expiration"] doubleValue] : defaultExpirationTime;
                    expiration = expiration < 0 ? defaultExpirationTime : expiration;
                    expiration = expiration == 0 ? 1 : expiration;
                    expiration = !expiration ? defaultExpirationTime : expiration;
                    
                    HBLogDebug(@"expiration %f", expiration);
                    [bakgrunnur queueProcess:scene.clientProcess.identity.embeddedApplicationIdentifier  softRemoval:(identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"retire"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"retire"] boolValue] : YES expirationTime:expiration];
                }
                if (enabledAppNotifications){
                    [[%c(UNSUserNotificationServer) sharedInstance] _didChangeApplicationState:4 forBundleIdentifier:scene.clientProcess.identity.embeddedApplicationIdentifier];
                }
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    if ([bakgrunnur.darkWakeIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]){
                        [bakgrunnur updateDarkWakeState];
                    }
                });
                
                
                HBLogDebug(@"Queued %@ for invalidation", scene.clientProcess.identity.embeddedApplicationIdentifier);
            }else{
                [bakgrunnur.retiringIdentifiers removeObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
            }
        }
    });
}

-(void)_applyMutableSettings:(UIMutableApplicationSceneSettings *)settings toScene:(FBScene *)scene withTransitionContext:(id)transitionContext completion:(/*^block*/id)arg4{
    //HBLogDebug(@"withTransitionContext: %@",[[[transitionContext valueForKey:@"actions"] valueForKey:@"info"] valueForKey:@"intents"]);
    //HBLogDebug(@"scene: %@", scene.clientProcess.identity.embeddedApplicationIdentifier);
    //HBLogDebug(@"enabled: %@", enabled?@"YES":@"NO");
    //HBLogDebug(@"enabledIdentifier: %@", enabledIdentifier);
    
    //HBLogDebug(@"_scenesByID: %@", [self valueForKey:@"_scenesByID"]);
    if (enabled){
        Bakgrunnur *bakgrunnur = [Bakgrunnur sharedInstance];
        FBProcessManager *processManager  = [%c(FBProcessManager) sharedInstance];
        FBProcess *proc = [[processManager processesForBundleIdentifier:scene.clientProcess.identity.embeddedApplicationIdentifier] firstObject];
        
        NSUInteger identifierIdx = [allEntriesIdentifier indexOfObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
        
        if (([enabledIdentifier containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier] || [bakgrunnur.grantedOnceIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]) && ![bakgrunnur.retiringIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]  && (proc.pid > 0)){
            
            BOOL enabledAppNotifications = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"] boolValue] : NO;
            
            
            BOOL isFrontMost = NO;
            if (mainWSStarted){
                SBApplication *frontMostApp = [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
                isFrontMost = [frontMostApp.bundleIdentifier isEqualToString:scene.clientProcess.identity.embeddedApplicationIdentifier];
                BOOL isUILocked = [[%c(SBLockScreenManager) sharedInstance] isUILocked];
                if (isUILocked){
                    isFrontMost = NO;
                }
                if (isFrontMost && frontMostApp.bundleIdentifier && !isUILocked){
                    
                    BOOL alreadyQueued = [bakgrunnur.queuedIdentifiers containsObject:frontMostApp.bundleIdentifier] || [bakgrunnur.immortalIdentifiers containsObject:frontMostApp.bundleIdentifier] || [bakgrunnur.advancedMonitoringIdentifiers containsObject:frontMostApp.bundleIdentifier];
                    
                    if (alreadyQueued){
                        [bakgrunnur.grantedOnceIdentifiers removeObject:frontMostApp.bundleIdentifier];
                        HBLogDebug(@"Revoked \"Once\" token for %@", frontMostApp.bundleIdentifier);
                    }
                    
                    [bakgrunnur invalidateQueue:frontMostApp.bundleIdentifier];
                    
                    if (enabledAppNotifications){
                        [[%c(UNSUserNotificationServer) sharedInstance] _didChangeApplicationState:8 forBundleIdentifier:frontMostApp.bundleIdentifier];
                    }
                    
                    
                    HBLogDebug(@"Reset expiration for %@", frontMostApp.bundleIdentifier);
                }
            }
            
            if ([settings respondsToSelector:@selector(setForeground:)]){
                [settings setForeground:YES];
                [settings setBackgrounded:NO];
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    if ([bakgrunnur.darkWakeIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]){
                        [bakgrunnur updateDarkWakeState];
                    }
                });
                
                //NSUInteger identifierIdx = [allEntriesIdentifier indexOfObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                // BOOL enabledAppNotifications = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"enabledAppNotifications"] boolValue] : YES;
                //[settings setPrefersProcessTaskSuspensionWhileSceneForeground:enabledAppNotifications?!isFrontMost:[settings prefersProcessTaskSuspensionWhileSceneForeground]];
                
                HBLogDebug(@"Deferred backgrounding for %@", scene.clientProcess.identity.embeddedApplicationIdentifier);
            }
        }else if (([enabledIdentifier containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier] || [bakgrunnur.grantedOnceIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]) && !(proc.pid > 0)){
            [[Bakgrunnur sharedInstance].grantedOnceIdentifiers removeObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
            [[Bakgrunnur sharedInstance] invalidateQueue:scene.clientProcess.identity.embeddedApplicationIdentifier];
        }
        
        
        //else if (![enabledIdentifier containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier] && ([[Bakgrunnur sharedInstance].queuedIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier] || [[Bakgrunnur sharedInstance].immortalIdentifiers containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]){
        //[[Bakgrunnur sharedInstance].retiringIdentifiers removeObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
        //}
    }
    %orig;
}
%end
%end //SpringBoardProcess

static NSArray *getArray(NSString *keyName, NSString *identifier, BOOL enabled){
    
    NSArray *array = enabled ? [prefs[keyName] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"enabled = YES"]] : [prefs[keyName] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"enabled = NO"]];
    NSArray *filteredArray = [array valueForKey:identifier];
    return filteredArray;
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

    Bakgrunnur *bakgrunnur = [Bakgrunnur sharedInstance];
    
    if (prefs && [prefs[@"enabledIdentifier"] firstObject] != nil){
        enabledIdentifier = getArray(@"enabledIdentifier", @"identifier", YES);
        allEntriesIdentifier = getAllEntries(@"enabledIdentifier", @"identifier");
        if (!firstInit){
            NSMutableArray *disabledIdentifier = [getArray(@"enabledIdentifier", @"identifier", NO) mutableCopy];
            [disabledIdentifier removeObjectsInArray:bakgrunnur.grantedOnceIdentifiers];
            [bakgrunnur invalidateAllQueuesIn:disabledIdentifier];
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
    globalTimeSpan = prefs[@"timeSpan"] ? [prefs[@"timeSpan"] doubleValue]/2.0 : 1800.0/2.0;
    globalTimeSpan = globalTimeSpan <= 0.0 ? 1.0 : globalTimeSpan;
    globalTimeSpan = !globalTimeSpan ? 1.0 : globalTimeSpan;
    
    
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
    [[Bakgrunnur sharedInstance] invalidateAllQueues];
}

static void cliRequest(){
    
    reloadPrefs();
    NSDictionary *pending = prefs[@"pendingRequest"];
    if (pending){
        if (pending[@"retire"] && [pending[@"retire"] boolValue]){
            if (pending[@"expiration"]){
                [[Bakgrunnur sharedInstance].grantedOnceIdentifiers removeObject:pending[@"identifier"]];
                [[Bakgrunnur sharedInstance] invalidateQueue:pending[@"identifier"]];
                [[Bakgrunnur sharedInstance] queueProcess:pending[@"identifier"] softRemoval:YES expirationTime:[pending[@"expiration"] doubleValue]];
            }else{
                [[Bakgrunnur sharedInstance] _retireScene:pending[@"identifier"]];
            }
        }
        if (pending[@"remove"] && [pending[@"remove"] boolValue]){
            if (pending[@"expiration"]){
                [[Bakgrunnur sharedInstance].grantedOnceIdentifiers removeObject:pending[@"identifier"]];
                [[Bakgrunnur sharedInstance] invalidateQueue:pending[@"identifier"]];
                [[Bakgrunnur sharedInstance] queueProcess:pending[@"identifier"] softRemoval:NO expirationTime:[pending[@"expiration"] doubleValue]];
            }else{
                [[Bakgrunnur sharedInstance] _terminateProcess:pending[@"identifier"]];
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
                        [[Bakgrunnur sharedInstance].grantedOnceIdentifiers removeObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                        [[Bakgrunnur sharedInstance] invalidateQueue:scene.clientProcess.identity.embeddedApplicationIdentifier];
                        if (isImmortal || isAdvancedMonitoring){
                            [[Bakgrunnur sharedInstance].immortalIdentifiers addObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                            [[Bakgrunnur sharedInstance] updateLabelAccessory:scene.clientProcess.identity.embeddedApplicationIdentifier];
                            if (isAdvancedMonitoring){
                                [[Bakgrunnur sharedInstance].advancedMonitoringIdentifiers addObject:scene.clientProcess.identity.embeddedApplicationIdentifier];
                                [[Bakgrunnur sharedInstance] startAdvancedMonitoringWithInterval:globalTimeSpan];
                            }
                        }else{
                            double expiration = (identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"expiration"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"expiration"] doubleValue] : defaultExpirationTime;
                            expiration = expiration < 0 ? defaultExpirationTime : expiration;
                            expiration = expiration == 0 ? 1 : expiration;
                            expiration = !expiration ? defaultExpirationTime : expiration;
                            [[Bakgrunnur sharedInstance] queueProcess:scene.clientProcess.identity.embeddedApplicationIdentifier  softRemoval:(identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"retire"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"retire"] boolValue] : YES expirationTime:expiration];
                        }
                        
                        *stop = YES;
                    }
                }];
            }else{
                [[Bakgrunnur sharedInstance] _retireScene:pending[@"identifier"]];
            }
        }
    }
}

static void preming(){
    HBLogDebug(@"prerming");
    Bakgrunnur *bakgrunnur = [Bakgrunnur sharedInstance];
    bakgrunnur.isPreming = YES;
    [bakgrunnur notifySleepingState:YES];
    bakgrunnur.sleepingState = 0;
}

%ctor{
    //@autoreleasepool {
    //NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
    
    //if (args.count != 0) {
    //NSString *executablePath = args[0];
    
    //if (executablePath) {
    //NSString *processName = [executablePath lastPathComponent];
    
    //BOOL isRunningBoard = [processName isEqualToString:@"runningboardd"];
    //BOOL isSpringBoard = [processName isEqualToString:@"SpringBoard"];
    //BOOL isApplication = [executablePath rangeOfString:@"/Application"].location != NSNotFound;
    
    //if (isSpringBoard){
    %init();
    reloadPrefs();
    %init(SPRINGBOARD_PROCESS);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reloadPrefs, (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)cliRequest, (CFStringRef)CLI_REQUEST_NOTIFICATION_NAME, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)resetAll, (CFStringRef)RESET_ALL_NOTIFICATION_NAME, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)preming, (CFStringRef)PRERMING_NOTIFICATION_NAME, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    
    firstInit = NO;
    //}
    //}
    //}
    //}
}
