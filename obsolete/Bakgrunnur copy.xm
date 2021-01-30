#import "common.h"
#import "Bakgrunnur.h"

#define defaultRetireDuration 31450000000 //1 year in millisecconds
#define defaultMode 5 //role
#define defaultTerminationResistance 3
#define defaultTaskState 4
#define defaultExpirationTime 10800 // 3hours
#define charToInt(x) [[NSString stringWithFormat:@"%02x", x] intValue]

static NSDictionary *prefs;
static BOOL enabled = YES;
static NSArray *enabledIdentifier;

@interface Bakgrunnur : NSObject
//@property(nonatomic, strong) CPDistributedMessagingCenter *c;
@property(nonatomic, assign) BOOL isUILocked;
+ (instancetype)sharedInstance;
-(BOOL)isUILocked;
@end


%group RunningBoardProcess

@implementation Bakgrunnur

+ (void)load {
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
    if ((self = [super init])) {
        //self.c = [CPDistributedMessagingCenter centerNamed:kIPCCenterName];
        //rocketbootstrap_distributedmessagingcenter_apply(self.c);
        self.isUILocked = YES;
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)deviceUnlocked, (CFStringRef)@"com.apple.springboardservices.eventobserver.internalSBSEventObserverEventUnlocked", NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)deviceLocked, (CFStringRef)@"com.apple.springboardservices.eventobserver.internalSBSEventObserverEventDimmed", NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    return self;
}

//-(BOOL)isUILocked{
    //return self.isUILocked;
    //NSDictionary *reply = [self.c sendMessageAndReceiveReplyName:@"isUILocked" userInfo:nil];
    //return [reply[@"value"] boolValue];
//}

static void deviceUnlocked(){
    [Bakgrunnur sharedInstance].isUILocked = NO;
}

static void deviceLocked(){
    [Bakgrunnur sharedInstance].isUILocked = YES;
}
@end


%hook RBDaemon
static NSString *expiringAssertionsProcessIdentifier;

%new
-(void)expiringProcess:(id)timer{
    NSDictionary *userInfo = [timer userInfo];
    HBLogDebug(@"Expiring %@", userInfo[@"identifier"]);
    NSMutableOrderedSet *processes = [[[self valueForKey:@"_processManager"] valueForKey:@"_processIndex"] valueForKey:@"_processes"];
    [processes enumerateObjectsUsingBlock:^(RBProcess *proc, NSUInteger idx, BOOL *stop) {
        if ([userInfo[@"identifier"] isEqualToString:proc.identity.embeddedApplicationIdentifier]) {
            expiringAssertionsProcessIdentifier = userInfo[@"identifier"];
            RBProcessMap *procMap = [[self valueForKey:@"_processManager"] valueForKey:@"_processState"];
            RBMutableProcessState *rbState = [[procMap stateForIdentity:proc.identity] mutableCopy];
            [rbState setRole:1];
            [rbState setTerminationResistance:1];
            [proc _applyState:rbState];
            [[self valueForKey:@"_processMonitor"] _queue_updateServerState:rbState forProcess:proc force:YES];
            
            
            
            //RBSProcessState *rbsState = [%c(RBSProcessState) stateWithProcess:proc];
            //[rbsState setTaskState:1];
            //[rbsState setTerminationResistance:1];
            [self assertionManager:[self valueForKey:@"_processManager"] willExpireAssertionsSoonForProcess:proc expirationTime:1];
            HBLogDebug(@"Added into expiring queue %@", proc.identity.embeddedApplicationIdentifier);
            *stop = YES;
        }
    }];
}

%new
-(void)terminateProcess:(id)timer{
    NSDictionary *userInfo = [timer userInfo];
    HBLogDebug(@"Terminating %@", userInfo[@"identifier"]);
    
    NSMutableOrderedSet *processes = [[[self valueForKey:@"_processManager"] valueForKey:@"_processIndex"] valueForKey:@"_processes"];
    [processes enumerateObjectsUsingBlock:^(RBProcess *proc, NSUInteger idx, BOOL *stop) {
        if ([userInfo[@"identifier"] isEqualToString:proc.identity.embeddedApplicationIdentifier]) {
            [proc terminateWithContext:nil];
            HBLogDebug(@"Terminated %@", proc.identity.embeddedApplicationIdentifier);
            *stop = YES;
        }
    }];
}

%new
-(void)invalidateQueue:(NSString *)identifier{
    PCPersistentInterfaceManager *pctimermanager = [%c(PCPersistentInterfaceManager) sharedInstance];
    NSMapTable *queues = MSHookIvar<NSMapTable *>(pctimermanager, "_delegatesAndQueues");
    NSArray *timerinqueues = [queues allKeys];
    //HBLogDebug(@"allkeys: %@", timerinqueues);
    for (PCPersistentTimer *persistenttimer in timerinqueues){
        PCSimpleTimer *_timer = MSHookIvar<PCSimpleTimer *>(persistenttimer, "_simpleTimer");
        NSString *serviceindentifier = MSHookIvar<NSString *>(_timer, "_serviceIdentifier");
        //HBLogDebug(@"serviceindentifier: %@", serviceindentifier);
        if ([serviceindentifier isEqualToString:[NSString stringWithFormat:@"com.udevs.bakgrunnur.%@", identifier]]){
            [_timer invalidate];
            _timer = nil;
            HBLogDebug(@"Invalidated %@", identifier);
            break;
        }
    }
}

%new
-(void)queueProcess:(NSString *)identifier softRemoval:(BOOL)removeGracefully expirationTime:(double)expTime{
    
    PCPersistentTimer *timer = [[%c(PCPersistentTimer) alloc] initWithFireDate:[[NSDate date] dateByAddingTimeInterval:expTime] serviceIdentifier:[NSString stringWithFormat:@"com.udevs.bakgrunnur.%@", identifier] target:self selector:removeGracefully?@selector(expiringProcess:):@selector(terminateProcess:) userInfo:@{@"identifier":identifier}];
    
    [timer setMinimumEarlyFireProportion:1];
    
    if ([NSThread isMainThread]) {
        [timer scheduleInRunLoop:[NSRunLoop mainRunLoop]];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^ {
            [timer scheduleInRunLoop:[NSRunLoop mainRunLoop]];
        });
    }
}

-(void)assertionManager:(id)manager willExpireAssertionsSoonForProcess:(RBProcess *)proc expirationTime:(double)time{
    if (enabled){
        
        //time in millieseconds
        HBLogDebug(@"willExpireAssertionsSoonForProcess: %@", proc);
        
        
        if (expiringAssertionsProcessIdentifier){
            %orig;
            expiringAssertionsProcessIdentifier = nil;
            return;
        }
        
        
        if ([enabledIdentifier containsObject:proc.identity.embeddedApplicationIdentifier]){
            NSUInteger idx = [enabledIdentifier indexOfObject:proc.identity.embeddedApplicationIdentifier];
            %orig(manager, proc, (idx != NSNotFound && prefs[@"enabledIdentifier"][idx][@"retiringDuration"]) ? [prefs[@"enabledIdentifier"][idx][@"retiringDuration"] doubleValue] : defaultRetireDuration);
            HBLogDebug(@"Deferred expiration of %@", proc.identity.embeddedApplicationIdentifier);
            return;
        }
    }
    %orig;
}

%end

%hook RBProcessMonitor

+(RBSProcessState *)_clientStateForServerState:(RBProcessState *)state process:(RBProcess *)proc{
    
    //MSHookIvar<unsigned char>(state, "_role") = 5; //running-active
    //2-background //5-active-running
    // MSHookIvar<unsigned char>(state, "_terminationResistance") = 3;
    if (enabled){
        //HBLogDebug(@"arg2: %@", [proc class ]);
        //if (retiringProcess) return %orig;
        
        
        //HBLogDebug(@"_clientStateForServerState: %@", c);
        //HBLogDebug(@"RBProcessMonitor: %@, %@", state, arg2);
        RBSProcessState *rbsState;
        if ([enabledIdentifier containsObject:state.identity.embeddedApplicationIdentifier]/* && !bakgrunnurRetiring[proc.identity.embeddedApplicationIdentifier]*/){
            
            NSUInteger idx = [enabledIdentifier indexOfObject:proc.identity.embeddedApplicationIdentifier];
            
            RBMutableProcessState *newState = [state mutableCopy];
            [newState setRole:(idx != NSNotFound && prefs[@"enabledIdentifier"][idx][@"mode"]) ? (unsigned char)[prefs[@"enabledIdentifier"][idx][@"mode"] intValue] : defaultMode];
            [newState setTerminationResistance:(idx != NSNotFound && prefs[@"enabledIdentifier"][idx][@"resistance"]) ? (unsigned char)[prefs[@"enabledIdentifier"][idx][@"resistance"] intValue] : defaultTerminationResistance];
            [proc _applyState:newState];
            
            //MSHookIvar<unsigned char>(state, "_role") = (idx != NSNotFound && prefs[@"enabledIdentifier"][idx][@"mode"]) ? (unsigned char)[prefs[@"enabledIdentifier"][idx][@"mode"] intValue] : defaultMode; //running-active
            //2-background //5-active-running
            //MSHookIvar<unsigned char>(state, "_terminationResistance") = (idx != NSNotFound && prefs[@"enabledIdentifier"][idx][@"resistance"]) ? (unsigned char)[prefs[@"enabledIdentifier"][idx][@"resistance"] intValue] : defaultTerminationResistance;
            rbsState = %orig(newState, proc);
            //HBLogDebug(@"-------endowmentNamespaces: %@", [c endowmentNamespaces]);
            //HBLogDebug(@"-------assertions: %@", [c assertions]);
            //HBLogDebug(@"-------legacyAssertions: %@", [c legacyAssertions]);
            //HBLogDebug(@"-------primitiveAssertions: %@", [c primitiveAssertions]);
            
            [rbsState setTaskState:(idx != NSNotFound && prefs[@"enabledIdentifier"][idx][@"taskState"]) ? (unsigned char)[prefs[@"enabledIdentifier"][idx][@"taskState"] intValue] : defaultTaskState];
            [rbsState setTerminationResistance:(idx != NSNotFound && prefs[@"enabledIdentifier"][idx][@"resistance"]) ? (unsigned char)[prefs[@"enabledIdentifier"][idx][@"resistance"] intValue] : defaultTerminationResistance];
            [rbsState setEndowmentNamespaces:[[NSSet alloc]initWithArray:@[@"com.apple.boardservices.endpoint-injection", @"com.apple.frontboard.visibility"]]];
        }
        return rbsState ? rbsState : %orig;
    }
    return %orig;
}
%end

%hook RBProcessStateChange

-(id)initWithIdentity:(RBSProcessIdentity *)identity originalState:(RBProcessState *)oriState updatedState:(RBProcessState *)newState{
    //HBLogDebug(@"%@, %@, %@#", identity, oriState, newState);
    //return %orig;
    if (enabled && [enabledIdentifier containsObject:identity.embeddedApplicationIdentifier] && oriState && newState){
       // HBLogDebug(@"%@", [c sendMessageAndReceiveReplyName:@"isUILocked" userInfo:nil]);
        
        RBDaemon *daemon = [%c(RBDaemon) _sharedInstance];
        BOOL isUILocked = [Bakgrunnur sharedInstance].isUILocked;

        HBLogDebug(@"oriState %@ ROLE %d", identity.embeddedApplicationIdentifier, charToInt(oriState.role));
        HBLogDebug(@"newState %@ ROLE %d", identity.embeddedApplicationIdentifier, charToInt(newState.role));
        HBLogDebug(@"isUILocked: %@", isUILocked?@"YES":@"NO");
    
        if ((charToInt(newState.role) <= 2) && (charToInt(oriState.role) >= 4)){
            
            //bakgrunnurRetiring[identity.embeddedApplicationIdentifier] = @YES;
            
            
            //NSDictionary *pending = prefs[@"pendingProcess"];
            NSMutableOrderedSet *processes = [[[daemon valueForKey:@"_processManager"] valueForKey:@"_processIndex"] valueForKey:@"_processes"];
            //RBMutableProcessState *newNewState = [newState mutableCopy];
            
            NSUInteger identifierIdx = [enabledIdentifier indexOfObject:identity.embeddedApplicationIdentifier];
            
            [processes enumerateObjectsUsingBlock:^(RBProcess *proc, NSUInteger idx, BOOL *stop) {
                if ([proc.identity.embeddedApplicationIdentifier isEqualToString:enabledIdentifier[identifierIdx]]) {
                    
                    [daemon invalidateQueue:identity.embeddedApplicationIdentifier];
                    [daemon queueProcess:identity.embeddedApplicationIdentifier softRemoval:NO expirationTime:(identifierIdx != NSNotFound && prefs[@"enabledIdentifier"][identifierIdx][@"expiration"]) ? [prefs[@"enabledIdentifier"][identifierIdx][@"expiration"] doubleValue] : defaultExpirationTime];
                    //[newNewState setRole:1];
                    
                    //[newNewState setTerminationResistance:1];
                    //[daemon assertionManager:[daemon valueForKey:@"_processManager"] willExpireAssertionsSoonForProcess:proc expirationTime:1000];
                    HBLogDebug(@"Queued %@ for invalidation", identity.embeddedApplicationIdentifier);
                    *stop = YES;
                    
                }
            }];
        }else if (!isUILocked &&  ((charToInt(newState.role) != charToInt(oriState.role)) && (charToInt(newState.role) >= 4))){
            [daemon invalidateQueue:identity.embeddedApplicationIdentifier];
            HBLogDebug(@"Reset expiration for %@", identity.embeddedApplicationIdentifier);
            //[bakgrunnurRetiring removeObjectForKey:identity.embeddedApplicationIdentifier];
        }
    }
    //HBLogDebug(@"%@ originalState: %@ updatedState: %@", arg1, arg2, arg3);
    return %orig;
}
%end

%hook RBProcess
-(void)setTerminating:(BOOL)terminating{
    %orig;
    HBLogDebug(@"setTerminating: %@", self.identity.embeddedApplicationIdentifier);
    if (enabled && terminating){
        if ([enabledIdentifier containsObject:self.identity.embeddedApplicationIdentifier]){
            RBDaemon *daemon = [%c(RBDaemon) _sharedInstance];
            [daemon invalidateQueue:self.identity.embeddedApplicationIdentifier];
        }
    }
}
%end
%end //RunningBoardProcess

%group AppProcess

@implementation Bakgrunnur

+ (void)load {
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
    if ((self = [super init])) {
    }
    return self;
}


@end

%hook FBSceneManager
-(void)_applyMutableSettings:(UIMutableApplicationSceneSettings *)settings toScene:(FBScene *)scene withTransitionContext:(id)arg3 completion:(/*^block*/id)arg4{
    //HBLogDebug(@"scene: %@", scene.clientProcess.identity.embeddedApplicationIdentifier);
    //HBLogDebug(@"enabled: %@", enabled?@"YES":@"NO");
    //HBLogDebug(@"enabledIdentifier: %@", enabledIdentifier);
    HBLogDebug(@"is foreground: %@", settings.foreground?@"YES":@"NO");
    if (enabled){
        if ([enabledIdentifier containsObject:scene.clientProcess.identity.embeddedApplicationIdentifier]){
            if ([settings respondsToSelector:@selector(setForeground:)]){
                [settings setForeground:YES];
                [settings setBackgrounded:NO];
            }
        }
    }
    %orig;
}
%end

/*
%hook FBScene
-(void)updateSettings:(UIMutableApplicationSceneSettings *)settings withTransitionContext:(UIApplicationSceneTransitionContext *)context completion:(id)handler{
    if ([settings respondsToSelector:@selector(setForeground:)]){
        [settings setForeground:YES];
        [settings setBackgrounded:NO];
    }
    %orig(settings, context, handler);
}
%end
*/
%end

static NSArray *getArray(NSString *keyName, NSString *identifier){
    NSArray *array = [prefs[keyName] valueForKey:identifier];
    return array;
}

static void reloadPrefs(){
    prefs = nil;
    NSData *data = [NSData dataWithContentsOfFile:kPrefsPath];
    if(data) {
        prefs = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:nil];
    } else{
        prefs = @{};
    }
    
    enabled = prefs[@"enabled"] ?  [prefs[@"enabled"] boolValue] : YES;
    
    if (prefs && [prefs[@"enabledIdentifier"] firstObject] != nil){
        enabledIdentifier = getArray(@"enabledIdentifier", @"id");
    }
    
    //HBLogDebug(@"%@",prefs[@"enabledIdentifier"]);
    //if (!rbProcessState) rbProcessState = [[NSMutableDictionary alloc] init];
}

static void cliRequest(){
    
    reloadPrefs();
    RBSProcessIdentity *identity = [%c(RBSProcessIdentity) identityForEmbeddedApplicationIdentifier:@"com.spotify.client"];
    HBLogDebug(@"identity: %@", identity);
    
    // NSDictionary *pending = valueForKey(@"pendingProcess");
    NSDictionary *pending = prefs[@"pendingProcess"];
    //HBLogDebug(@"pendingProcess: %@", pending);
    if (pending && [pending[@"retire"] boolValue]){
        //HBLogDebug(@"%@", [[[[%c(RBDaemon) _sharedInstance] valueForKey:@"_processManager"] valueForKey:@"_processIndex"] valueForKey:@"_processByIdentity"]);
        RBDaemon *daemon = [%c(RBDaemon) _sharedInstance];
        NSMutableOrderedSet *processes = [[[daemon valueForKey:@"_processManager"] valueForKey:@"_processIndex"] valueForKey:@"_processes"];
        
        [processes enumerateObjectsUsingBlock:^(RBProcess *proc, NSUInteger idx, BOOL *stop) {
            if ([proc.identity.embeddedApplicationIdentifier isEqualToString:pending[@"identifier"]]) {
                [proc terminateWithContext:nil];
                *stop = YES;
            }
        }];
    }
}

%ctor{
    @autoreleasepool {
        NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
        
        if (args.count != 0) {
            NSString *executablePath = args[0];
            
            if (executablePath) {
                NSString *processName = [executablePath lastPathComponent];
                
                BOOL isRunningBoard = [processName isEqualToString:@"runningboardd"];
                BOOL isSpringBoard = [processName isEqualToString:@"SpringBoard"];
                BOOL isApplication = [executablePath rangeOfString:@"/Application"].location != NSNotFound;
                
                if (isRunningBoard || isSpringBoard || isApplication){
                    %init();
                }
                
                if (isApplication || isSpringBoard){
                    reloadPrefs();
                    %init(AppProcess);
                }
                
                if (isRunningBoard) {
                    reloadPrefs();
                    %init(RunningBoardProcess);
                    //[%c(Bakgrunnur) sharedInstance];

                    
                    
                    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reloadPrefs, (CFStringRef)kPrefsChangedIdentifier, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)cliRequest, (CFStringRef)kRetireProcessIndentifier, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                    
                }
            }
        }
    }
}
