#import "common.h"
#import "Bakgrunnur.h"
#import "BakgrunnurServer.h"

#define defaultRetireDuration 31450000000 //1 year in millisecconds
#define defaultMode 5 //role
#define defaultTerminationResistance 3
#define defaultTaskState 4
#define defaultExpirationTime 10800 // 3hours
#define charToInt(x) [[NSString stringWithFormat:@"%02x", x] intValue]

static BOOL enabled = YES;
static NSDictionary *prefs;
static NSArray *enabledIdentifier;
static NSMutableDictionary *bakgrunnurRetiring;
static CPDistributedMessagingCenter *c;
//static NSMutableDictionary *rbProcessState;
//[[[[NSClassFromString(@"RBDaemon") _sharedInstance] valueForKey:@"_processManager"] valueForKey:@"_processIndex"] valueForKey:@"_processByIdentifier"]
//[[[NSClassFromString(@"RBDaemon") _sharedInstance] valueForKey:@"_processManager"] _processForIdentifier:1704]
//[[[NSClassFromString(@"RBDaemon") _sharedInstance] valueForKey:@"_processManager"] _removeProcess:p]






/*
%hook RBPowerAssertionManager

-(void)_queue_updateProcessAssertion:(RBProcessPowerAssertion *)assertion withState:(RBProcessState *)state{
    
    if ([enabledIdentifier containsObject:state.identity.embeddedApplicationIdentifier]){
        NSUInteger idx = [enabledIdentifier indexOfObject:state.identity.embeddedApplicationIdentifier];
        if ([assertion valueForKey:@"_state"]){
            MSHookIvar<unsigned char>([assertion valueForKey:@"_state"], "_role") = (idx != NSNotFound && prefs[@"enabledIdentifier"][idx][@"mode"]) ? [prefs[@"enabledIdentifier"][idx][@"mode"] intValue] : defaultMode;
            MSHookIvar<unsigned char>([assertion valueForKey:@"_state"], "_terminationResistance") = (idx != NSNotFound && prefs[@"enabledIdentifier"][idx][@"resistance"]) ? [prefs[@"enabledIdentifier"][idx][@"resistance"] intValue] : defaultTerminationResistance;
        }
        
        MSHookIvar<unsigned char>(state, "_role") = (idx != NSNotFound && prefs[@"enabledIdentifier"][idx][@"mode"]) ? [prefs[@"enabledIdentifier"][idx][@"mode"] intValue] : defaultMode;
        MSHookIvar<unsigned char>(state, "_terminationResistance") = (idx != NSNotFound && prefs[@"enabledIdentifier"][idx][@"resistance"]) ? [prefs[@"enabledIdentifier"][idx][@"resistance"] intValue] : defaultTerminationResistance;
    }
     
    HBLogDebug(@"%@ *********** %@", [assertion valueForKey:@"_state"], [assertion valueForKey:@"_process"]);

    %orig;
}

%end
*/
/*
%hook RBAssertionManager
-(void)_lock_setState:(RBProcessState *)state forProcessIdentity:(id)arg2{
    HBLogDebug(@"_lock_setState: %@ ******* %@", state, arg2);
    if ([enabledIdentifier containsObject:state.identity.embeddedApplicationIdentifier]){
        return;
        NSUInteger idx = [enabledIdentifier indexOfObject:state.identity.embeddedApplicationIdentifier];
        MSHookIvar<unsigned char>(state, "_role") = (idx != NSNotFound && prefs[@"enabledIdentifier"][idx][@"mode"]) ? [prefs[@"enabledIdentifier"][idx][@"mode"] intValue] : defaultMode;
        MSHookIvar<unsigned char>(state, "_terminationResistance") = (idx != NSNotFound && prefs[@"enabledIdentifier"][idx][@"resistance"]) ? [prefs[@"enabledIdentifier"][idx][@"resistance"] intValue] : defaultTerminationResistance;
    }
    %orig;
}
%end
*/

/*
%hook SBFMobileKeyBagState
-(long long)lockState{
    
    //long long result = %orig;
    //HBLogDebug(@"SBFMobileKeyBagState: %lld", result);
    return 7;
}

-(BOOL)isEffectivelyLocked{
    return NO;
}
%end

%hook SBFMobileKeyBag
//-(BOOL)hasPasscodeSet{
    //return NO;
//}
-(long long)maxUnlockAttempts{
    return 10;
}
%end
*/

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
    HBLogDebug(@"allkeys: %@", timerinqueues);
    for (PCPersistentTimer *persistenttimer in timerinqueues){
        PCSimpleTimer *_timer = MSHookIvar<PCSimpleTimer *>(persistenttimer, "_simpleTimer");
        NSString *serviceindentifier = MSHookIvar<NSString *>(_timer, "_serviceIdentifier");
        HBLogDebug(@"serviceindentifier: %@", serviceindentifier);
        if ([serviceindentifier isEqualToString:[NSString stringWithFormat:@"com.udevs.bakgrunnur.%@", identifier]]){
            [_timer invalidate];
            _timer = nil;
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








/*
 -(void)assertionManager:(id)arg1 didAddProcess:(RBProcess *)proc withState:(RBProcessState *)state{
 HBLogDebug(@"didAddProcess: %@", proc);
 %orig;
 if (proc.identity.embeddedApplicationIdentifier) rbProcessState[proc.identity.embeddedApplicationIdentifier] = state;
 HBLogDebug(@"Added rbProcessState: %@", rbProcessState);
 }
 
 -(void)processManager:(id)arg1 didRemoveProcess:(RBProcess *)proc{
 HBLogDebug(@"didRemoveProcess: %@", proc);
 %orig;
 if (proc.identity.embeddedApplicationIdentifier) [rbProcessState removeObjectForKey:proc.identity.embeddedApplicationIdentifier];
 HBLogDebug(@"Remove rbProcessState: %@", rbProcessState);
 }
 */


-(void)assertionManager:(id)manager willExpireAssertionsSoonForProcess:(RBProcess *)proc expirationTime:(double)time{
    if (enabled){
        
        //time in millieseconds
        HBLogDebug(@"willExpireAssertionsSoonForProcess: %@", proc);
        
        
        if (expiringAssertionsProcessIdentifier){
            %orig;
            expiringAssertionsProcessIdentifier = nil;
            return;
        }
        
        //NSDate *date = [NSDate date];
        //HBLogDebug(@"currentTime: %f", [date timeIntervalSince1970]);
        //HBLogDebug(@"expirationTime: %f", time/1000);
        //HBLogDebug(@"added: %f",[date timeIntervalSince1970]+time/1000);
        //HBLogDebug(@"rbsState.bakgrunnurRetiring: %@", [bakgrunnurRetiring[proc.identity.embeddedApplicationIdentifier] boolValue ]?@"YES":@"NO");
        //RBSProcessState *rbsState = [%c(RBSProcessState) stateWithProcess:proc];
        //RBProcessState *rbState = [[%c(RBProcessState) alloc] initWithIdentity:proc.identity];
        
        //RBProcessManager *procManager = [self valueForKey:@"_processManager"];
        //RBProcessMap *procMap = [procManager valueForKey:@"_processState"];
        //RBProcessState *rbState = [procMap stateForIdentity:proc.identity];
         //HBLogDebug(@"isActiveProcessc: %@", [procManager isActiveProcess:proc]?@"YES":@"NO");
        
        //RBConnectionClient *connectionClient = [[%c(RBConnectionClient) alloc] init];
        //[connectionClient willExpireAssertionsSoonForProcess:proc expirationTime:1000];
        //for (id x in rbsStates){
        //HBLogDebug(@"connectionClient: %@", connectionClient.description);
       // }
        //RBMutableProcessState *rbState = [[[%c(RBProcessState) alloc] initWithIdentity:proc.identity] mutableCopy];

        
        //RBSProcessState *rbsState  = [%c(RBSProcessState) stateWithProcess:proc];
/*
        
        if ([enabledIdentifier containsObject:proc.identity.embeddedApplicationIdentifier]){
            HBLogDebug(@"****TASK ROLE: %@ --- %@", proc.identity.embeddedApplicationIdentifier, [NSString stringWithFormat:@"%02x", rbState.role]);
            HBLogDebug(@"****TASK RESIST: %@ --- %@",proc.identity.embeddedApplicationIdentifier, [NSString stringWithFormat:@"%02x", rbState.terminationResistance]);
            }
            */
        //HBLogDebug(@"procMap stateForIdentity: %@", [ procMap stateForIdentity:proc.identity]);
        if ([enabledIdentifier containsObject:proc.identity.embeddedApplicationIdentifier] /*&& !bakgrunnurRetiring[proc.identity.embeddedApplicationIdentifier]*/){
            

            NSUInteger idx = [enabledIdentifier indexOfObject:proc.identity.embeddedApplicationIdentifier];
            %orig(manager, proc, (idx != NSNotFound && prefs[@"enabledIdentifier"][idx][@"retiringDuration"]) ? [prefs[@"enabledIdentifier"][idx][@"retiringDuration"] doubleValue] : defaultRetireDuration);
            HBLogDebug(@"Deferred expiration of %@", proc.identity.embeddedApplicationIdentifier);
            return;
        }
    }
    %orig;
}

%end

/*
 %hook RBSProcessMonitor
 -(void)_handleProcessStateChange:(RBSProcessState *)state{
 RBSProcessIdentity *identity = [[state valueForKey:@"_process"] valueForKey:@"_identity"];
 if ([enabledIdentifier containsObject:identity.embeddedApplicationIdentifier]){
 [state setTaskState:4];
 [state setTerminationResistance:3];
 [state setEndowmentNamespaces:[[NSSet alloc]initWithArray:@[@"com.apple.boardservices.endpoint-injection", @"com.apple.frontboard.visibility"]]];
 HBLogDebug(@"_handleProcessStateChange %@", state);
 }
 %orig;
 }
 %end
 */

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
            /*
             RBProcessState *rbState = [proc valueForKey:@"_lock_state"];
             RBMutableProcessState *newState = [rbState mutableCopy];
             [newState setRole:5];
             [newState setTerminationResistance:2];
             [proc _applyState:newState];
             
             //MSHookIvar<RBProcessState *>(proc, "_lock_appliedState") = (RBProcessState *)newState;
             //MSHookIvar<RBProcessState *>(proc, "_lock_state") = (RBProcessState *)newState;
             [proc _lock_applyRole];
             [proc _lock_resume];
             */
            //HBLogDebug(@"%c", [c preventLaunchState]);
            //HBLogDebug(@"%@", [c isEmptyState]?@"YES":@"NO");
            
            //MSHookIvar<unsigned char>(state, "_terminationResistance") = 3;
            
            //NSSet <RBSProcessAssertionInfo *> *assertionInfo = (NSSet *)[[%c(RBSProcessAssertionInfo) alloc] initWithType:0];
            //[assertionInfo setReason:0];
            //[c setLegacyAssertions:assertionInfo];
            //[c setPrimitiveAssertions:assertionInfo];
            //HBLogDebug(@"RETURNED: %@", rbsState);
            
            //[self suppressUpdatesForIdentity:arg2];
        }/*else if ([enabledIdentifier containsObject:state.identity.embeddedApplicationIdentifier] && bakgrunnurRetiring[proc.identity.embeddedApplicationIdentifier] && (charToInt(state.role) < 5)){
            
            HBLogDebug(@"SET NONE");
            RBMutableProcessState *newState = [state mutableCopy];
            //[newState setRole:1];
            [newState setTerminationResistance:1];
            [proc _applyState:newState];
            rbsState = %orig(newState, proc);
            //[rbsState setTaskState:1];
            [rbsState setTerminationResistance:1];
            
            
        }
        */
        return rbsState ? rbsState : %orig;
    }
return %orig;
}
%end

%hook RBProcess
-(void)_applyState:(RBProcessState *)state{
    //HBLogDebug(@"_applyState: %@", state);
    /*\\
     if ([enabledIdentifier containsObject:state.identity.embeddedApplicationIdentifier]){
     RBMutableProcessState *newState = [state mutableCopy];
     [newState setRole:5];
     [newState setTerminationResistance:4];
     [newState setPreventIdleSleep:YES];
     //[newState setIsBeingDebugged:YES];
     %orig(newState);
     return;
     }
     */
    /*
     if ([state.identity.embeddedApplicationIdentifier isEqualToString:@"com.spotify.client"] ){
     MSHookIvar<unsigned char>(state, "_role") = 5;
     HBLogDebug(@"_hostProcess: %@", MSHookIvar<RBProcessState *>(self, "_hostProcess"));
     
     
     /*
     RBMutableProcessState *newState = [state mutableCopy];
     [newState setRole:5];
     MSHookIvar<RBProcessState *>(self, "_lock_state") = (RBProcessState *)newState;
     MSHookIvar<RBProcessState *>(self, "_lock_appliedState") = (RBProcessState *)newState;
     
     /*
     RBMutableProcessState *newState = [state mutableCopy];
     [newState setRole:5];
     [newState setTerminationResistance:2];
     [newState setPreventIdleSleep:YES];
     //[newState setIsBeingDebugged:YES];
     %orig(newState);
     */
    //return;
    //}
    %orig;
    
}

-(void)setTerminating:(BOOL)arg1{
    %orig;
    HBLogDebug(@"setTerminating: %@ %@", self.identity.embeddedApplicationIdentifier, arg1?@"YES":@"NO");
    
}

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
    
    if (!bakgrunnurRetiring) bakgrunnurRetiring = [[NSMutableDictionary alloc] init];
    //HBLogDebug(@"%@",prefs[@"enabledIdentifier"]);
    //if (!rbProcessState) rbProcessState = [[NSMutableDictionary alloc] init];
}

%hook RBConnectionClient
-(id)initWithContext:(id)arg1 process:(id)arg2 connection:(id)arg3 {
    //HBLogDebug(@"initWithContext: %@ ** %@ ** %@", arg1, [arg2 class], arg3);
    return %orig;
}
%end

%hook FBProcess
-(id)initWithHandle:(id)arg1 identity:(id)arg2 executionContext:(id)arg3{
    HBLogDebug(@"initWithHandle: %@ ** %@ ** %@", arg1, [ arg2 class], arg3);
    return %orig;
}

%end

%hook FBProcessExecutionContext
-(void)setLaunchIntent:(long long)arg1{
    HBLogDebug(@"setLaunchIntent: %lld", arg1);
    %orig;
}
%end

%hook SBApplication
-(void)_processWillLaunch:(id)arg1{
    HBLogDebug(@"_processWillLaunch: %@", arg1);
    %orig;
}
%end

%hook RBProcessManager
-(BOOL)isActiveProcess:(id)arg1 {
    //HBLogDebug(@"isActiveProcess: %@", [arg1 class ]);
    return %orig;
}
%end

%hook RBProcess
-(id)_initWithInstance:(id)arg1 taskNameRight:(id)arg2 job:(id)arg3 bundleProperties:(id)arg4 jetsamBandProvider:(id)arg5 initialState:(id)arg6 hostProcess:(id)arg7 properties:(id)arg8 systemPreventsIdleSleep:(BOOL)arg9{
    //HBLogDebug(@"_initWithInstance: %@ ** taskNameRight: %@ ** job: %@ ** bundleProperties: %@ ** jetsamBandProvider: %@ ** initialState: ^%@ ** hostProcess: %@ ** properties: %@ ** systemPreventsIdleSleep: %@", arg1, arg2, arg3,arg4, arg5, arg6, arg7, arg8, arg9?@"YES":@"NO");
    return %orig;
}
%end

%hook FBProcessManager
-(void)_queue_addForegroundRunningProcess:(id)arg1{
    HBLogDebug(@"_queue_addForegroundRunningProcess: %@", [arg1 class]);
    %orig;
}

-(void)launchProcessWithContext:(id)arg1{
    HBLogDebug(@"launchProcessWithContext: %@", arg1);
    %orig;
}

-(void)_setPreferredForegroundApplicationProcess:(id)arg1 deferringToken:(id)arg2{
    HBLogDebug(@"_setPreferredForegroundApplicationProcess: %@ ** %@", arg1, arg2);
    %orig;
}

-(void)_queue_evaluateForegroundEventRouting{
    HBLogDebug(@"_queue_evaluateForegroundEventRouting");
    %orig;
}
%end

%hook SBMainWorkspace
//-(BOOL)_preflightTransitionRequest:(id)arg1{
   // %orig;
    //return YES;
//}

-(BOOL)_executeApplicationTransitionRequest:(id)arg1{
    //HBLogDebug(@"_executeApplicationTransitionRequest: %@", arg1);
    return %orig;
}

-(id)_selectTransactionForAppActivationUnderMainScreenLockRequest:(id)arg1 {
        HBLogDebug(@"_selectTransactionForAppActivationUnderMainScreenLockRequest: %@", arg1);
    return %orig;

}
-(id)createRequestForApplicationActivation:(id)arg1 options:(unsigned long long)arg2{
    id req = %orig;
    //HBLogDebug(@"createRequestForApplicationActivation: %lld ***** %@", arg2, req);
    return req;
}
-(id)createRequestWithOptions:(unsigned long long)arg1{
    id req = %orig;
    //HBLogDebug(@"createRequestWithOptions: %lld ******* %@", arg1, req);
    return req;
}

-(void)_registerHandler:(id)arg1 forExtensionPoint:(id)arg2{
    HBLogDebug(@"_registerHandler: %@ forExtensionPoint: %@", arg1, arg2);
    %orig;
}

-(void)systemService:(id)arg1 handleOpenApplicationRequest:(id)arg2 withCompletion:(/*^block*/id)arg3{
    HBLogDebug(@"systemService: %@ ** %@", arg1, arg2);
    %orig;
}

-(void)applicationProcessWillLaunch:(id)arg1{
    HBLogDebug(@"applicationProcessWillLaunch: %@", arg1);
    %orig;
}

-(void)systemService:(id)arg1 isPasscodeLockedOrBlockedWithResult:(/*^block*/id)arg2{
    HBLogDebug(@"isPasscodeLockedOrBlockedWithResult: %@", arg1);
    %orig;
}

-(id)_validateRequestToOpenApplication:(id)arg1 options:(id)arg2 origin:(id)arg3 error:(id*)arg4{
    HBLogDebug(@"_validateRequestToOpenApplication: %@ ** %@ ** %@", arg1, arg2, arg3);
    return %orig;
}

-(void)_handleOpenApplicationRequest:(id)arg1 options:(id)arg2 activationSettings:(id)arg3 origin:(id)arg4 withResult:(/*^block*/id)arg5{
    HBLogDebug(@"_handleOpenApplicationRequest: %@", arg3 );
    %orig;
}

-(void)_handleTrustedOpenRequestForApplication:(id)arg1 options:(id)arg2 activationSettings:(id)arg3 origin:(id)arg4 withResult:(/*^block*/id)arg5{
    //HBLogDebug(@"_handleTrustedOpenRequestForApplication: %@ ** %@ ** %@ ** %@", arg1, arg2, arg3, arg4);
    HBLogDebug(@"activationSettings: %@ ** %@", arg3, arg4);
    %orig;
}
-(void)_handleUntrustedOpenRequestForApplication:(id)arg1 options:(id)arg2 activationSettings:(id)arg3 origin:(id)arg4 withResult:(/*^block*/id)arg5{
    HBLogDebug(@"_handleUntrustedOpenRequestForApplication: %@ ** %@ ** %@ ** %@", arg1, arg2, arg3, arg4);
    %orig;
}
%end

%hook FBSystemService
-(void)systemService:(id)arg1 handleOpenApplicationRequest:(id)arg2 withCompletion:(/*^block*/id)arg3{
    HBLogDebug(@"handleOpenApplicationRequest: %@", arg2);
    %orig;
}
%end

%hook FBSystemServiceOpenApplicationRequest
-(void)setClientProcess:(FBProcess *)arg1{
    HBLogDebug(@"setClientProcess: %@", arg1);
    %orig;
}
%end

%hook FBSOpenApplicationOptions
+(id)optionsWithDictionary:(id)arg1{
    HBLogDebug(@"optionsWithDictionary: %@", arg1);
    return %orig;
}
-(void)setDictionary:(NSDictionary *)arg1{
    HBLogDebug(@"setDictionary: %@", arg1);
    return %orig;
}
%end
//static IMP (*original_hasPasscodeSet)();
//BOOL replaced_hasPasscodeSet() {
    //return NO;
//}

//static IMP (*original_lockState)();
//long long replaced_lockState() {
    //return 7;
//}


%hook SBActivationSettings
-(void)setFlag:(long long)arg1 forActivationSetting:(unsigned)arg2{
    HBLogDebug(@"setFlag: %lld forActivationSetting: %d", arg1, arg2);
    %orig;
}
%end

%hook CCUIContentModuleContext
-(void)openApplication:(id)arg1 withOptions:(id)arg2 completionHandler:(/*^block*/id)arg3{
    HBLogDebug(@"CCUIContentModuleContext: %@ *** %@", arg1, arg2);
    %orig;
}
%end



%hook RBProcessStateChange


-(id)initWithIdentity:(RBSProcessIdentity *)identity originalState:(RBProcessState *)oriState updatedState:(RBProcessState *)newState{

    RBDaemon *daemon = [%c(RBDaemon) _sharedInstance];
    if ([enabledIdentifier containsObject:identity.embeddedApplicationIdentifier] ){
    HBLogDebug(@"oriState %@ ROLE %d", identity.embeddedApplicationIdentifier, charToInt(oriState.role));
    HBLogDebug(@"newState %@ ROLE %d", identity.embeddedApplicationIdentifier, charToInt(newState.role));
        HBLogDebug(@"isUILocked: %@", [[c sendMessageAndReceiveReplyName:@"isUILocked" userInfo:nil][@"value"] boolValue]?@"YES":@"NO");
    }
    if ([enabledIdentifier containsObject:identity.embeddedApplicationIdentifier] && /*bakgrunnurRetiring[identity.embeddedApplicationIdentifier] &&*/ (charToInt(newState.role) <= 2) && (charToInt(oriState.role) >= 4)){

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
        //return %orig(identity, oriState, newNewState);

        
        /*
         RBMutableProcessState *newNewState = [newState mutableCopy];
         [newNewState setRole:2];
         [newNewState setTerminationResistance:1];
         //[proc _applyState:newState];
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
         HBLogDebug(@"=================================REALLY REMOVED");
         [bakgrunnurRetiring removeObjectForKey:identity.embeddedApplicationIdentifier];
         });
         
         return %orig(identity, oriState, newNewState);
         */
    }else if ([enabledIdentifier containsObject:identity.embeddedApplicationIdentifier] && ![[c sendMessageAndReceiveReplyName:@"isUILocked" userInfo:nil][@"value"] boolValue] && /*bakgrunnurRetiring[identity.embeddedApplicationIdentifier] &&*/ ((charToInt(newState.role) != charToInt(oriState.role)) && (charToInt(newState.role) >= 4))){
        [daemon invalidateQueue:identity.embeddedApplicationIdentifier];
        HBLogDebug(@"Reset expiration for %@", identity.embeddedApplicationIdentifier);
        //[bakgrunnurRetiring removeObjectForKey:identity.embeddedApplicationIdentifier];
    }
    
    
    
    //HBLogDebug(@"%@ originalState: %@ updatedState: %@", arg1, arg2, arg3);
    return %orig;
}
%end

/*
%hook RBSProcessStateUpdate
+(id)updateWithState:(RBSProcessState *)newState previousState:(RBSProcessState *)prevState{
    
    /*if ([enabledIdentifier containsObject:newState.process.identity.embeddedApplicationIdentifier] && bakgrunnurRetiring[newState.process.identity.embeddedApplicationIdentifier] &&
        ![[NSString stringWithFormat:@"%02x", newState.taskState] isEqualToString:@"04"]){
        HBLogDebug(@"=================================REALLY REMOVED");
        [bakgrunnurRetiring removeObjectForKey:newState.process.identity.embeddedApplicationIdentifier];

     }else
    HBLogDebug(@"%@ newState: %d", newState.process.identity.embeddedApplicationIdentifier,  charToInt(newState.taskState));
    HBLogDebug(@"%@ prevState: %d", newState.process.identity.embeddedApplicationIdentifier, charToInt(prevState.taskState));
    HBLogDebug(@"%@ newState - Resistance: %d", newState.process.identity.embeddedApplicationIdentifier, charToInt(prevState.terminationResistance));
    HBLogDebug(@"%@ prevState - Resistance: %d", prevState.process.identity.embeddedApplicationIdentifier, charToInt(prevState.terminationResistance));

    if ([enabledIdentifier containsObject:newState.process.identity.embeddedApplicationIdentifier] && bakgrunnurRetiring[newState.process.identity.embeddedApplicationIdentifier] && (charToInt(newState.taskState) < 4) && (charToInt(prevState.taskState) == 4)){
        HBLogDebug(@"=================================REALLY REMOVED");

        [bakgrunnurRetiring removeObjectForKey:newState.process.identity.embeddedApplicationIdentifier];
    }
    
    //HBLogDebug(@"updateWithState: %@ ** %@", arg1, arg2);
    return %orig;
}
%end
*/
static void cliRequest(){
    //RBSProcessIdentity *identity2 = [%c(RBSProcessIdentity) identityForEmbeddedApplicationIdentifier:@"com.spotify.client"];
    //FBProcessExecutionContext *fbContext = [[%c(FBProcessExecutionContext) alloc] initWithIdentity:identity2];
    //[fbContext setLaunchIntent:4];
    //FBApplicationProcess *appProc = [[%c(FBApplicationProcess) alloc] initWithHandle:nil identity:identity2 executionContext:fbContext];
    //FBApplicationProcess *appProc = [[%c(FBProcessManager) sharedInstance] _createProcessWithExecutionContext:fbContext];
    //FBProcessState *state = [appProc state];
    //[state setTaskState:4];
    //[state setVisibility:2];
    //FBApplicationProcess *appProc = [[%c(FBProcessManager) sharedInstance] _createProcessWithExecutionContext:fbContext];
    //[[%c(FBProcessManager) sharedInstance] launchProcessWithContext:fbContext];

    //FBProcessState *state = [appProc state];

    //int pid = [state pid];
    //[[%c(FBProcessManager) sharedInstance] registerProcessForHandle:[%c(BSProcessHandle) processHandleForPID:pid]];
    //SBApplicationController *sbAppController = [%c(SBApplicationController) sharedInstance];
    
    //SBApplication *sbApp = [sbAppController applicationWithBundleIdentifier:@"com.spotify.client"];
    //[sbApp _processWillLaunch:appProc];
    //[sbApp _processDidLaunch:appProc];
    //[state setTaskState:4];
    //[state setVisibility:2];
    //SBApplicationProcessState *sbAppProcState = [[%c(SBApplicationProcessState) alloc] _initWithProcess:appProc stateSnapshot:nil];
    //[sbApp _setInternalProcessState:sbAppProcState];
    
    
    /*
    NSDictionary *opts = @{ @"__PayloadOptions":@{@"UIApplicationLaunchOptionsSourceApplicationKey":@"com.apple.springboard"}, @"__PayloadURL":@"spotify://",@"__SBWorkspaceOpenOptionUnlockResult":@1, @"__LaunchEnvironment":@"secureOnLockScreen",@"__ActivateSuspended":@YES};
    
    NSString *bundleID = @"com.spotify.client";
    //NSDictionary *opts = @{@"LSOpenSensitiveURLOption":@YES, @"__LaunchOrigin":@"CCUIAppLaunchOriginControlCenter", @"__PayloadOptions":@{@"UIApplicationLaunchOptionsSourceApplicationKey":@"com.apple.springboard"}, @"__PayloadURL":@"spotify:", @"__PromptUnlockDevice":@YES, @"__UnlockDevice":@YES, @"__ActivateSuspended":@NO};
    
    FBProcessManager *fbAppProcManager = [%c(FBProcessManager) sharedInstance];
    HBLogDebug(@"allProcesses: %@", [fbAppProcManager allProcesses]);
    
    FBApplicationProcess *sbFBAppProc  = [[fbAppProcManager applicationProcessesForBundleIdentifier:@"com.apple.springboard"] firstObject];
    
    HBLogDebug(@"sbFBAppProc: %@", sbFBAppProc);
    
    FBSystemServiceOpenApplicationRequest *fbOpenAppRequest = [%c(FBSystemServiceOpenApplicationRequest) request];
    [fbOpenAppRequest setClientProcess:sbFBAppProc];
    [fbOpenAppRequest setTrusted:YES];
    [fbOpenAppRequest setBundleIdentifier:bundleID];
    HBLogDebug(@"fbOpenAppRequest: %@", fbOpenAppRequest);
    FBSOpenApplicationOptions *fbOpenAppOpts = [%c(FBSOpenApplicationOptions) optionsWithDictionary:opts];
    [fbOpenAppRequest setOptions:fbOpenAppOpts];
    HBLogDebug(@"options: %@", [%c(FBSOpenApplicationOptions) optionsWithDictionary:opts]);
    FBSystemService *sysService = [%c(FBSystemService) sharedInstance];
    SBMainWorkspace *sbMainWS = [%c(SBMainWorkspace) sharedInstance];
    
    SBActivationSettings *actSettings = [[%c(SBActivationSettings) alloc] init];
    [actSettings setFlag:1 forActivationSetting:44];

 
    //launchForegroundUnderLockScreen
    //[actSettings setFlag:0 forActivationSetting:33];
    HBLogDebug(@"actSettings: %@", actSettings);


    //[sbMainWS _handleTrustedOpenRequestForApplication:@"com.spotify.client" options:opts activationSettings:actSettings origin:sbFBAppProc.handle withResult:nil];
    //[sbMainWS _handleOpenApplicationRequest:@"com.spotify.client" options:opts activationSettings:actSettings origin:sbFBAppProc.handle withResult:nil];
    [sbMainWS systemService:sysService handleOpenApplicationRequest:fbOpenAppRequest withCompletion:^(NSError *error){
        HBLogDebug(@"ERROR: %@", error.localizedDescription);
    }];
    */
//"__LaunchEnvironment" = secureOnLockScreen
    
    
    //SBActivationSettings *actSettings = [[%c(SBActivationSettings) alloc] init];
    //[actSettings setFlag:1 forActivationSetting:44]; //44 = fromTrustedSystemServiceRequest
    //HBLogDebug(@"actSettings: %@", actSettings);
    
    //[sbMainWS _handleOpenApplicationRequest:@"com.spotify.client" options:opts activationSettings:actSettings origin:sbFBAppProc.handle withResult:nil];

    //[sbMainWS _validateRequestToOpenApplication:@"com.spotify.client" options:opts origin:sbFBAppProc.handle error:nil];

    //return;
    /*
    SBFMobileKeyBag *keyBag = [%c(SBFMobileKeyBag) sharedInstance];
    //SBFMutableMobileKeyBagState *newKeyBagState = [keyBag.state mutableCopy];
    //[newKeyBagState setLockState:7];
    //MSHookMessageEx(%c(SBFMobileKeyBagState), @selector(lockState), (IMP)replaced_lockState, (IMP *)&original_lockState);
    //MSHookMessageEx(%c(SBFMobileKeyBag), @selector(hasPasscodeSet), (IMP)replaced_hasPasscodeSet, (IMP *)&original_hasPasscodeSet);
    //[(SpringBoard *)[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.spotify.client" suspended:YES];
    SBApplicationAutoLaunchService *autoLaunchService = [[%c(SBApplicationAutoLaunchService) alloc] _initWithWorkspace:[%c(SBMainWorkspace) sharedInstance] applicationController:[%c(SBApplicationController) sharedInstance] restartManager:((SBPrototypeController *)[%c(SBPrototypeController) sharedInstance]).restartManager syncController:[%c(SBSyncController) sharedInstance] keybag:keyBag];
    HBLogDebug(@"autoLaunchService: %@", autoLaunchService);
    
    SBApplicationController *sbAppController = [%c(SBApplicationController) sharedInstance];
    SBApplication *sbApp = [sbAppController applicationWithBundleIdentifier:@"com.spotify.client"];
    
    
    [autoLaunchService _shouldAutoLaunchApplication:sbApp forReason:1];
    return;
    */
    
    //RBDaemon *daemon = [%c(RBDaemon) _sharedInstance];
    
    //RBProcessManager *procManager = [daemon valueForKey:@"_processManager"];
    //HBLogDebug(@"procManager: %@", procManager);
    
    RBSProcessIdentity *identity = [%c(RBSProcessIdentity) identityForEmbeddedApplicationIdentifier:@"com.spotify.client"];
    HBLogDebug(@"identity: %@", identity);
    

    
    /*
    RBSLaunchContext *context = [%c(RBSLaunchContext) contextWithIdentity:identity];
    HBLogDebug(@"context: %@", context);

    RBSLaunchRequest *request = [[%c(RBSLaunchRequest) alloc] initWithContext:context];
    HBLogDebug(@"request: %@", request);

    NSError *error = nil;

    RBLaunchdJob *job = [%c(RBLaunchdJob) newJobWithIdentity:identity launchContext:context error:nil];
    [job startWithError:&error];
    HBLogDebug(@"error: %@", error.localizedDescription);
    
    RBSProcessHandle  *rbsHandle = [procManager executeLaunchRequest:request withError:&error];
    HBLogDebug(@"error: %@", error.localizedDescription);
    
    RBSProcessState *procState = [rbsHandle currentState];
    [procState setTaskState:4];
    HBLogDebug(@"isRunning: %@", [procState isRunning]?@"YES":@"NO");
    
    NSMutableOrderedSet *processes = [[[daemon valueForKey:@"_processManager"] valueForKey:@"_processIndex"] valueForKey:@"_processes"];
           
           [processes enumerateObjectsUsingBlock:^(RBProcess *proc, NSUInteger idx, BOOL *stop) {
               if ([proc.identity.embeddedApplicationIdentifier isEqualToString:@"com.spotify.client"]) {
                   HBLogDebug(@"isActiveProcessc: %@", [procManager isActiveProcess:proc]?@"YES":@"NO");


                   *stop = YES;
               }
           }];
    */
    
    //RBProcessIndex *procIndex =
    
    //[procManager start];
    
    /*
    FBProcessExecutionContext *fbContext = [[%c(FBProcessExecutionContext) alloc] initWithIdentity:identity];
     [fbContext setLaunchIntent:2];
    FBApplicationProcess *fbProc = [[%c(FBApplicationProcess) alloc] initWithHandle:nil identity:identity executionContext:fbContext];
    
    FBProcessState *state = [fbProc state];
    int pid = [state pid];
    [[%c(FBProcessManager) sharedInstance] registerProcessForHandle:[%c(BSProcessHandle) processHandleForPID:pid]];
    //[[%c(FBProcessManager) sharedInstance] _queue_evaluateForegroundEventRouting];
    
    SBMainWorkspace *sbMainWS = [%c(SBMainWorkspace) sharedInstance];
    [sbMainWS applicationProcessWillLaunch:fbProc];
    */
    
    /*
    FBProcessExecutionContext *fbContext = [[%c(FBProcessExecutionContext) alloc] initWithIdentity:identity];
    [fbContext setLaunchIntent:4];
    //FBApplicationProcess *fbProc = [[%c(FBApplicationProcess) alloc] initWithHandle:nil identity:identity executionContext:fbContext];
    //FBProcessState *state = [fbProc state];
    //[state setTaskState:2];
    //[state setVisibility:1];
    //[[%c(FBProcessManager) sharedInstance] launchProcessWithContext:fbContext];
    FBApplicationProcess *appProc = [[%c(FBProcessManager) sharedInstance] _createProcessWithExecutionContext:fbContext];
    
      FBProcessState *state = [appProc state];

    int pid = [state pid];
    [[%c(FBProcessManager) sharedInstance] registerProcessForHandle:[%c(BSProcessHandle) processHandleForPID:pid]];
    
    [[%c(FBProcessManager) sharedInstance] _setPreferredForegroundApplicationProcess:appProc deferringToken:nil];

    SBApplicationController *sbAppController = [%c(SBApplicationController) sharedInstance];
    SBApplication *sbApp = [sbAppController applicationWithBundleIdentifier:@"com.spotify.client"];
    [sbApp _processWillLaunch:appProc];
    [sbApp _processDidLaunch:appProc];
    [state setTaskState:4];
    [state setVisibility:2];
    SBApplicationProcessState *sbAppProcState = [[%c(SBApplicationProcessState) alloc] _initWithProcess:appProc stateSnapshot:nil];
    [sbApp _setInternalProcessState:sbAppProcState];
    [sbApp _updateProcess:appProc withState:state];
    //[(SpringBoard *)[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.spotify.client" suspended:YES];
    [sbAppController applicationVisibilityMayHaveChanged];
    SBMainWorkspace *sbMainWS = [%c(SBMainWorkspace) sharedInstance];
    [sbApp setWantsAutoLaunchForVOIP:YES];
    [sbMainWS applicationProcessWillLaunch:appProc];
    [sbMainWS applicationProcessDidLaunch:appProc];

     
     
     
    //[[%c(FBProcessManager) sharedInstance] launchProcessWithContext:fbContext];
    //[sbApp setNextWakeDate:[NSDate date]];
   // [appProc _queue_setTaskState:4];
    //[appProc _queue_setVisibility:2];
    
    //[[%c(FBProcessManager) sharedInstance] launchProcessWithContext:fbContext];

 //[[%c(FBProcessManager) sharedInstance] _setPreferredForegroundApplicationProcess:appProc deferringToken:nil];

    //FBApplicationProcess *appProc = [[%c(FBProcessManager) sharedInstance] applicationProcessesForBundleIdentifier:@"com.spotify.client"];
    
    //FBApplicationProcessLaunchTransaction *procLaunchTrans = [[%c(FBApplicationProcessLaunchTransaction) alloc] initWithApplicationProcess:appProc];
    //[procLaunchTrans _queue_launchProcess:[procLaunchTrans process]];
    
    //if (appProc) [[%c(FBProcessManager) sharedInstance] _queue_addForegroundRunningProcess:appProc];
    
    //[[%c(FBProcessManager) sharedInstance] _setPreferredForegroundApplicationProcess:appProc deferringToken:nil];
    //if (appProc) [[%c(FBProcessManager) sharedInstance] _queue_addProcess:appProc];


    //[[%c(FBProcessManager) sharedInstance] _queue_evaluateForegroundEventRouting];

    HBLogDebug(@"appProc: %@", appProc);
    //if (appProc) [[%c(FBProcessManager) sharedInstance] _queue_addProcess:appProc];


    HBLogDebug(@"%@",[[%c(FBProcessManager) sharedInstance] allApplicationProcesses]);
    */
    
    
    
    
    
    /*
    SBApplicationController *sbAppController = [%c(SBApplicationController) sharedInstance];
    SBApplication *sbApp = [sbAppController applicationWithBundleIdentifier:@"com.spotify.client"];
    [sbApp _processWillLaunch:fbProc];
    [sbApp _processDidLaunch:fbProc];
    [state setTaskState:2];
    [state setVisibility:1];
    SBApplicationProcessState *sbAppProcState = [[%c(SBApplicationProcessState) alloc] _initWithProcess:fbProc stateSnapshot:nil];
    [sbApp _setInternalProcessState:sbAppProcState];
    */
    //return;

    
    reloadPrefs();
    return;
    // NSDictionary *pending = valueForKey(@"pendingProcess");
    NSDictionary *pending = prefs[@"pendingProcess"];
    //HBLogDebug(@"pendingProcess: %@", pending);
    if (pending && [pending[@"retire"] boolValue]){
        //HBLogDebug(@"%@", [[[[%c(RBDaemon) _sharedInstance] valueForKey:@"_processManager"] valueForKey:@"_processIndex"] valueForKey:@"_processByIdentity"]);
        RBDaemon *daemon = [%c(RBDaemon) _sharedInstance];
        NSMutableOrderedSet *processes = [[[daemon valueForKey:@"_processManager"] valueForKey:@"_processIndex"] valueForKey:@"_processes"];
        
        [processes enumerateObjectsUsingBlock:^(RBProcess *proc, NSUInteger idx, BOOL *stop) {
            if ([proc.identity.embeddedApplicationIdentifier isEqualToString:pending[@"identifier"]]) {
                
                bakgrunnurRetiring[proc.identity.embeddedApplicationIdentifier] = @YES;

                
                
                
                //[rbsState encodeWithPreviousState:rbsState];
                
                
                //RBMutableProcessState *rbState = [[[%c(RBProcessState) alloc] initWithIdentity:proc.identity] mutableCopy];
                RBProcessManager *procManager = [daemon valueForKey:@"_processManager"];
                RBProcessMap *procMap = [procManager valueForKey:@"_processState"];
                RBMutableProcessState *rbState = [[procMap stateForIdentity:proc.identity] mutableCopy];
                //HBLogDebug(@"ABC- %d", (int)(rbState.terminationResistance));

                [rbState setRole:2];
                [rbState setTerminationResistance:1];
                //HBLogDebug(@"DEF- %d", (int)(rbState.terminationResistance));
                
                [proc _applyState:rbState];
                //[procMap setState:rbState forIdentity:proc.identity];
                //[proc _lock_suspend];

                [daemon assertionManager:[daemon valueForKey:@"_processManager"] willExpireAssertionsSoonForProcess:proc expirationTime:3000];
                /*
                RBSProcessState *rbsState = [%c(RBSProcessState) stateWithProcess:proc];
                //RBSProcessState *rbsStatePrev = [[%c(RBSProcessState) stateWithProcess:proc] copy];
                 [rbsState setTaskState:1];
                 [rbsState setTerminationResistance:1];
                RBProcessMonitor *procMonitor = [daemon valueForKey:@"_processMonitor"];
                
                 //[%c(RBSProcessStateUpdate) updateWithState:rbsState previousState:rbsStatePrev];
                [procMonitor _queue_updateServerState:rbState forProcess:proc force:YES];
                
                 HBLogDebug(@"bakgrunnurRetiring: %@", bakgrunnurRetiring);
                 */
                 //RBSProcessState *rbsState = [%c(RBProcessMonitor) _clientStateForServerState:rbState process:proc];
                 //[rbsState setTaskState:1];
                //[rbsState setTerminationResistance:1];
                
                //[proc terminateWithContext:nil];
                //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
                    //[daemon assertionManager:[daemon valueForKey:@"_processManager"] willExpireAssertionsSoonForProcess:proc expirationTime:1000]; //1 second
                //});
                

                
                
                //[[daemon valueForKey:@"_processManager"] _removeProcess:proc];

                
                
                //[proc setTerminating:YES];
                //MSHookIvar<unsigned char>([proc valueForKey:@"_lock_appliedState"], "_role") = 0; //running-active
                //MSHookIvar<unsigned char>([proc valueForKey:@"_lock_state"], "_terminationResistance") = 0;
                //RBSProcessState *currentState = [%c(RBSProcessState) stateWithProcess:proc];
                //[currentState setTaskState:0];
                //[currentState setTerminationResistance:0];
                //[currentState setEndowmentNamespaces:[[NSSet alloc]initWithArray:@[]]];
                //[proc setTerminating:YES];
                //HBLogDebug(@"currentState: %@", currentState);
                
                /*
                 retiringProcess = YES;
                 [daemon assertionManager:[daemon valueForKey:@"_processManager"] willExpireAssertionsSoonForProcess:proc expirationTime:1000]; //1 second
                 retiringProcess = NO;
                 */
                
                *stop = YES;
            }
        }];
        
        //for (NSDictionary *identity in processIdentity){
        //if ([identity.embeddedApplicationIdentifier isEqualToString:@"com.spotify.client"]){
        //    break;
        //}
        //HBLogDebug(@"%@", identity.euid);
        //}
    }
    //[[[[%c(RBDaemon) _sharedInstance] valueForKey:@"_processManager"] valueForKey:@"_processIndex"] valueForKey:@"_processByIdentifier"];
    //[[[%c(RBDaemon) _sharedInstance] valueForKey:@"_processManager"] _processForIdentifier:1704];
    //[[[%c(RBDaemon) _sharedInstance] valueForKey:@"_processManager"] _removeProcess:p];
}

/*
 %hook FBScene
 -(void)updateSettings:(UIMutableApplicationSceneSettings *)settings withTransitionContext:(UIApplicationSceneTransitionContext *)context completion:(id)arg3{
 //HBLogDebug(@"context: %@", [self valueForKey:@"_contentStateIsChanging"]);
 RBSProcessIdentity *identity = [[self valueForKey:@"_clientProcess"] valueForKey:@"_identity"];
 //RBSProcessState *state = [[self valueForKey:@"_clientProcess"] valueForKey:@"_rbsState"];
 if ([enabledIdentifier containsObject:identity.embeddedApplicationIdentifier]){
 if ([settings respondsToSelector:@selector(setForeground:)]){
 //[self _setContentState:0];
 //[self _setContentState:2];
 //[self _setContentState:2];
 [settings setForeground:YES];
 //return;
 //[[[%c(SBApplicationController) sharedInstance] applicationWithBundleIdentifier:identity.embeddedApplicationIdentifier] _setRecentlyUpdated:YES];
 
 //[self _setContentState:2]; // 2 == ready, 1 == preparing, 0 == not ready
 //FBSMutableSceneSettings *sceneSettings = self.mutableSettings;
 //[sceneSettings setForeground:YES]; // This is important for the view to be interactable.
 //[self updateSettings:sceneSettings withTransitionContext:nil]; // Enact the changes made
 //[(FBProcess *)[self valueForKey:@"_clientProcess"] _queue_rebuildState];
 
 //return;
 
 //return;
 //MSHookIvar<BOOL>([[self valueForKey:@"_clientProcess"] valueForKey:@"_state"], "_foreground") = YES;
 //MSHookIvar<BOOL>([[self valueForKey:@"_clientProcess"] valueForKey:@"_state"], "_running") = YES;
 //[(FBProcessState  *)[[self valueForKey:@"_clientProcess"] valueForKey:@"_state"] setTaskState:2];
 //[(FBProcessState  *)[[self valueForKey:@"_clientProcess"] valueForKey:@"_state"] setVisibility:2];
 
 }
 }
 %orig;
 HBLogDebug(@"withTransitionContext: %@",context);
 }
 %end
 */


%ctor{
    reloadPrefs();
    
    @autoreleasepool {
          NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
          
          if (args.count != 0) {
              NSString *executablePath = args[0];
              
              if (executablePath) {
                  NSString *processName = [executablePath lastPathComponent];
                  
                  BOOL isRunningBoard = [processName isEqualToString:@"runningboardd"];
                  
                  if (isRunningBoard) {
                      c = [CPDistributedMessagingCenter centerNamed:kIdentifier];
                      rocketbootstrap_distributedmessagingcenter_apply(c);
                      
                  }
              }
          }
      }
    
    
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reloadPrefs, (CFStringRef)kPrefsChangedIdentifier, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)cliRequest, (CFStringRef)kRetireProcessIndentifier, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    
    
}
