#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface RBSProcessIdentity : NSObject
@property (nonatomic,copy,readonly) NSString * embeddedApplicationIdentifier;
@property (nonatomic,copy,readonly) NSString * executablePath;
@property (nonatomic,readonly) unsigned euid;
+(id)identityForEmbeddedApplicationIdentifier:(id)arg1 ;
@end


@interface RBSDaemonProcessIdentity : RBSProcessIdentity
-(NSString *)daemonJobLabel;
@end


@interface RBProcessState : NSObject
@property (nonatomic,copy,readonly) RBSProcessIdentity * identity;
@property (nonatomic,readonly) unsigned char role;
@property (nonatomic,readonly) unsigned char terminationResistance;
-(id)initWithIdentity:(id)arg1 ;
@end

@interface RBMutableProcessState : RBProcessState
-(void)setRole:(unsigned char)arg1;
-(void)setPreventIdleSleep:(BOOL)arg1 ;
-(void)setTerminationResistance:(unsigned char)arg1 ;
-(void)setIsBeingDebugged:(BOOL)arg1 ;
-(void)setPreventIdleSleep:(BOOL)arg1 ;
@end

@interface RBSProcessHandle : NSObject
//@property (nonatomic,readonly) RBSProcessState * currentState;
@property (nonatomic,copy,readonly) RBSProcessIdentity * identity;
+(id)currentProcess;
//-(RBSProcessState *)currentState;
@end

@interface RBSProcessState : NSObject
@property (assign,nonatomic) unsigned char taskState;
@property (assign,nonatomic) unsigned char terminationResistance;
@property (getter=isRunning,nonatomic,readonly) BOOL running;
@property (nonatomic,readonly) RBSProcessHandle * process;
@property (nonatomic,copy) NSSet * legacyAssertions;
@property (nonatomic,copy) NSSet * primitiveAssertions;
+(id)stateWithProcess:(id)arg1 ;
-(void)setTaskState:(unsigned char)arg1 ;
-(void)setDebugState:(unsigned char)arg1 ;
-(void)setPreventLaunchState:(unsigned char)arg1 ;
-(void)setTerminationResistance:(unsigned char)arg1 ;
-(void)setEndowmentNamespaces:(NSSet *)arg1 ;
-(void)setLegacyAssertions:(NSSet *)arg1 ;
-(void)setPrimitiveAssertions:(NSSet *)arg1 ;
-(unsigned char)preventLaunchState;
-(BOOL)isRunning;
-(BOOL)isEmptyState;
-(NSSet *)endowmentNamespaces;
-(NSSet *)assertions;
-(NSSet *)legacyAssertions;
-(NSSet *)primitiveAssertions;
-(BOOL)isPreventedFromLaunching;
-(void)encodeWithPreviousState:(id)arg1 ;
@end

typedef NS_ENUM(NSUInteger, RBSTaskState) {
    RBSTaskStateUnknown = 0,
    RBSTaskStateNone = 1,
    RBSTaskStateRunning = 2,
    RBSTaskStateRunningSuspended = 3,
    RBSTaskStateRunningActive = 4,
};

@interface RBProcess : NSObject
@property (nonatomic,copy,readonly) RBSProcessIdentity * identity;
@property (getter=isSuspended,nonatomic,readonly) BOOL suspended;
@property (nonatomic,copy,readonly) RBSProcessHandle * handle;
-(void)setTerminating:(BOOL)arg1 ;
-(id)processPredicate;
-(BOOL)terminateWithContext:(id)arg1 ;
-(void)_lock_suspend;
-(void)_lock_resume;
-(void)_lock_applyRole;
-(void)_applyState:(id)arg1 ;
-(BOOL)_sendSignal:(int)arg1 ;
-(void)invalidate;
-(BOOL)terminateWithContext:(id)arg1 ;
-(void)_lock_applyCurrentStateIfPossible;
-(BOOL)_lock_terminateWithContext:(id)arg1 ;
@end

@interface RBProcessStateChange : NSObject
@property (nonatomic,copy,readonly) RBSProcessIdentity * identity;
@end

@interface RBProcessMonitor : NSObject
+(id)_clientStateForServerState:(id)arg1 process:(id)arg2 ;
-(void)suppressUpdatesForIdentity:(id)arg1 ;
-(void)unsuppressUpdatesForIdentity:(id)arg1 ;
-(void)_queue_updateServerState:(id)arg1 forProcess:(id)arg2 force:(BOOL)arg3 ;
-(void)didUpdateProcessStates:(id)arg1 ;
-(void)removeStateForProcessIdentity:(id)arg1 ;
@end
/*
 %hook RBProcessStateChangeSet
 -(id)initWithChanges:(NSSet *)arg1{
 for (RBProcessStateChange *stateChange in arg1){
 HBLogDebug(@"initWithChanges: %@", stateChange.identity);
 
 }
 return %orig;
 }
 %end
 
 %hook RBMutableProcessState
 -(void)setRole:(unsigned char)arg1{
 if ([self.identity.embeddedApplicationIdentifier isEqualToString:@"com.spotify.client"]){
 %orig(2);
 return;
 }
 %orig;
 }
 
 -(void)setTerminationResistance:(unsigned char)arg1{
 HBLogDebug(@"%@ setTerminationResistance: %c", self.identity.embeddedApplicationIdentifier, arg1);
 %orig;
 }
 %end
 */


@interface RBSProcessAssertionInfo : NSObject
-(void)setReason:(unsigned long long)arg1 ;
-(id)initWithType:(unsigned char)arg1 ;
@end







@interface RBProcessManager : NSObject
-(void)start;
-(void)_removeProcess:(id)arg1 ;
-(id)processForIdentifier:(id)arg1 ;
-(RBSProcessHandle *)executeLaunchRequest:(id)arg1 withError:(out id*)arg2 ;
-(BOOL)isActiveProcess:(id)arg1 ;
@end



@interface RBDaemon : NSObject
+(id)_sharedInstance;
-(void)assertionManager:(id)arg1 willExpireAssertionsSoonForProcess:(id)arg2 expirationTime:(double)arg3 ;
-(id)_reconnectOriginatorProcess;
-(void)terminateProcess:(id)timer;
-(void)invalidateQueue:(NSString *)identifier;
-(void)queueProcess:(NSString *)identifier softRemoval:(BOOL)removeGracefully expirationTime:(double)expTime;
-(BOOL)isUILocked;
@end

@interface FBProcessState : NSObject
-(void)setTaskState:(long long)arg1 ;
-(void)setVisibility:(long long)arg1 ;
-(int)pid;

@end

@interface BSProcessHandle : NSObject
@property (nonatomic,readonly) int pid;
+(id)processHandleForPID:(int)arg1 ;
@end

@interface FBProcessCPUStatistics : NSObject
-(double)totalElapsedUserTime;
-(double)totalElapsedSystemTime;
-(double)totalElapsedIdleTime;
@end

@interface FBSProcessTerminationRequest : NSObject
+(id)requestForProcess:(id)arg1 withLabel:(id)arg2 ;
@end

@interface RBSProcessIdentifier : NSObject
@property (nonatomic,readonly) int pid;
+(id)identifierWithPid:(int)arg1 ;
+(id)identifierForIdentifier:(id)arg1 ;
+(id)identifierForCurrentProcess;
@end

@interface RBSTarget : NSObject
@property (nonatomic,readonly) RBSProcessIdentifier * processIdentifier; //pid
@property (nonatomic,readonly) RBSProcessIdentity * processIdentity;
@property (nonatomic,copy,readonly) NSString * environment;
+(id)targetWithProcessIdentity:(id)arg1 ;
+(BOOL)supportsRBSXPCSecureCoding;
+(id)currentProcess;
+(id)targetWithProcessIdentifier:(id)arg1 ;
+(id)systemTarget;
+(id)targetWithProcessIdentity:(id)arg1 environmentIdentifier:(id)arg2 ;
+(id)targetWithPid:(int)arg1 ;
+(id)targetWithProcessIdentifier:(id)arg1 environmentIdentifier:(id)arg2 ;
+(id)targetWithPid:(int)arg1 environmentIdentifier:(id)arg2 ;
@end

@interface FBProcess : NSObject{
    FBProcessCPUStatistics* _cpuStatistics;
}
@property (nonatomic,readonly) int pid;
@property (nonatomic,readonly) BSProcessHandle * handle;
@property (nonatomic,readonly) RBSProcessIdentity * identity;
@property (nonatomic,copy,readonly) NSString * bundleIdentifier;
@property (nonatomic,copy,readonly) NSString * executablePath;
@property (nonatomic,readonly) RBSTarget * target;
+(id)calloutQueue;
-(FBProcessState *)state;
-(id)initWithHandle:(id)arg1 identity:(id)arg2 executionContext:(id)arg3 ;
-(void)_queue_rebuildState;
-(void)_queue_executeLaunchCompletionBlocks:(BOOL)arg1 ;
-(void)_queue_updateStateWithBlock:(/*^block*/id)arg1 ;
-(void)_queue_setTaskState:(long long)arg1 ;
-(void)_queue_setVisibility:(long long)arg1 ;
-(void)launchWithDelegate:(id)arg1 ;
-(void)_lock_consumeLock_performGracefulKill;
-(void)_terminateWithRequest:(id)arg1 completion:(/*^block*/id)arg2 ;
-(void)_setSceneLifecycleState:(unsigned char)arg1 ;
@end

@interface FBApplicationProcess : FBProcess
-(void)setNowPlayingWithAudio:(BOOL)arg1 ;
@end



@interface FBSSceneSettings : NSObject
@property (nonatomic,readonly) double level;
-(BOOL)isOccluded;
-(BOOL)prefersProcessTaskSuspensionWhileSceneForeground;
-(void)setPrefersProcessTaskSuspensionWhileSceneForeground:(BOOL)arg1 ;
@end

@interface FBSMutableSceneSettings : FBSSceneSettings
@property (assign,nonatomic) long long userInterfaceStyle;
@property (assign,nonatomic) BOOL underLock;
@property (nonatomic,copy) NSArray * occlusions;
@property (assign,getter=isForeground,nonatomic) BOOL foreground;
@property (assign,getter=isBackgrounded,nonatomic) BOOL backgrounded;
@property (assign,nonatomic) double level;
@property (assign,nonatomic) long long interruptionPolicy;
-(void)setForeground:(BOOL)arg1 ;
-(BOOL)isForeground;
-(void)setBackgrounded:(BOOL)arg1 ;
-(void)setUnderLock:(BOOL)arg1 ;
-(void)setDeactivationReasons:(unsigned long long)arg1 ;
-(void)setUserInterfaceStyle:(long long)arg1 ;
-(CGRect)frame;
-(void)setFrame:(CGRect)arg1 ;
-(void)setBackgrounded:(BOOL)arg1 ;
-(void)setIdleModeEnabled:(BOOL)arg1 ;
-(void)setPersistenceIdentifier:(NSString *)arg1 ;
-(id)otherSettings;
-(void)setOcclusions:(NSArray *)arg1;
-(void)setLevel:(double)arg1 ;
-(void)setOccluded:(BOOL)arg1 ;
@end

@interface UIMutableApplicationSceneSettings : FBSMutableSceneSettings
@property (nonatomic,retain) NSString * persistenceIdentifier;
@property (assign,nonatomic) BOOL idleModeEnabled;
-(void)setUnderLock:(BOOL)arg1 ;
-(void)setDeactivationReasons:(unsigned long long)arg1 ;
@end

@interface FBSSceneSpecification : NSObject
@property (nonatomic,readonly) NSString * uiSceneSessionRole;
@end

@protocol FBSceneClientProvider <NSObject>
@required
-(void)unregisterHost:(id)arg1;
-(id)registerHost:(id)arg1 withSpecification:(id)arg2 settings:(id)arg3 initialClientSettings:(id)arg4 fromRemnant:(id)arg5;
-(void)registerInvalidationAction:(id)arg1;

@end



@interface FBScene : NSObject
@property (nonatomic,copy,readonly) FBSSceneSpecification * specification;
@property (nonatomic,retain) FBSMutableSceneSettings * mutableSettings;
@property (nonatomic,readonly) long long contentState;
@property (nonatomic,copy,readonly) NSString * identifier;
@property (nonatomic,copy,readonly) NSString * workspaceIdentifier;
@property (nonatomic,readonly) FBSSceneSettings * settings;
@property (nonatomic,readonly) FBProcess * clientProcess;
@property (nonatomic,readonly) id<FBSceneClientProvider> clientProvider;
@property (getter=isValid,nonatomic,readonly) BOOL valid;
@property (getter=_isInTransaction,nonatomic,readonly) BOOL _inTransaction;
@property (nonatomic,readonly) unsigned long long _transactionID;
-(void)updateUISettingsWithBlock:(/*^block*/id)arg1 ;
-(void)updateSettingsWithBlock:(/*^block*/id)arg1 ;
-(void)_applyUpdateWithContext:(id)arg1 completion:(/*^block*/id)arg2 ;
-(unsigned long long)_beginTransaction;
-(void)_setContentState:(long long)arg1 ;
-(void)updateSettings:(id)arg1 withTransitionContext:(id)arg2 ;
-(void)updateSettings:(id)arg1 withTransitionContext:(id)arg2 completion:(/*^block*/id)arg3 ;
-(void)_setContentState:(long long)arg1 ;
-(void)updateSettingsWithTransitionBlock:(/*^block*/id)arg1 ;
-(void)_invalidateWithTransitionContext:(id)arg1 ;
-(unsigned long long)_beginTransaction;
-(void)_endTransaction:(unsigned long long)arg1 ;
@end




@interface FBSSceneTransitionContext : NSObject
@end

@interface UIApplicationSceneTransitionContext : FBSSceneTransitionContext
@end

@interface FBSceneManager : NSObject{
    NSMutableDictionary* _scenesByID;
}
+(id)sharedInstance;
+(void)synchronizeChanges:(/*^block*/id)arg1 ;
-(void)_noteSceneChangedLevel:(id)arg1 ;
-(void)_noteSceneMovedToForeground:(id)arg1 ;
-(void)_noteSceneMovedToBackground:(id)arg1 ;
-(id)sceneWithIdentifier:(id)arg1 ;
-(void)_applyMutableSettings:(id)arg1 toScene:(id)arg2 withTransitionContext:(id)arg3 completion:(/*^block*/id)arg4 ;
-(void)destroyScene:(id)arg1 withTransitionContext:(id)arg2 ;
-(void)_destroyScene:(id)arg1 withTransitionContext:(id)arg2 ;
-(void)_updateScene:(id)arg1 withSettings:(id)arg2 transitionContext:(id)arg3 completion:(/*^block*/id)arg4 ;
-(void)scene:(id)arg1 handleUpdateToSettings:(id)arg2 withTransitionContext:(id)arg3 completion:(/*^block*/id)arg4 ;
-(id)createSceneFromRemnant:(id)arg1 withSettings:(id)arg2 transitionContext:(id)arg3 ;
@end

@interface SBApplicationWakeScheduler : NSObject
-(void)wakeImmediately;
-(void)scheduleWakeForDate:(id)arg1 ;
-(void)flushSnapshotsForAllScenes;
@end

@interface SBApplicationProcessState : NSObject
@property (nonatomic,readonly) int pid;
@property (getter=isRunning,nonatomic,readonly) BOOL running;
@property (getter=isForeground,nonatomic,readonly) BOOL foreground;
@property (nonatomic,readonly) long long taskState;
@property (nonatomic,readonly) long long visibility;
@property (nonatomic,readonly) BOOL isBeingDebugged;
-(id)_initWithProcess:(id)arg1 stateSnapshot:(id)arg2 ;
@end

@interface SBApplication : NSObject
@property (nonatomic,readonly) SBApplicationWakeScheduler * legacyVOIPPeriodicWakeScheduler;
@property (nonatomic,readonly) NSString * bundleIdentifier;
@property (nonatomic,readonly) SBApplicationProcessState * processState;
@property (assign,getter=isPlayingAudio,nonatomic) BOOL playingAudio;
@property (nonatomic,readonly) NSString * displayName; 
-(void)flushSnapshotsForAllScenes;
-(void)setPlayingAudio:(BOOL)arg1 ;
-(void)_setApplicationRestorationCheckState:(int)arg1 ;
-(void)_setRecentlyUpdated:(BOOL)arg1 ;
-(void)purgeCaches;
-(void)_processWillLaunch:(id)arg1 ;
-(void)_processDidLaunch:(id)arg1 ;
-(void)_setInternalProcessState:(id)arg1 ;
-(void)setNextWakeDate:(NSDate *)arg1 ;
-(void)setWantsAutoLaunchForVOIP:(BOOL)arg1 ;
-(void)_setApplicationRestorationCheckState:(int)arg1 ;
-(void)_updateProcess:(id)arg1 withState:(id)arg2 ;
-(void)_setNewlyInstalled:(BOOL)arg1 ;
-(void)_setRecentlyUpdated:(BOOL)arg1 ;
-(NSString *)bundleIdentifier;
-(void)saveSnapshotForSceneHandle:(id)arg1 context:(id)arg2 completion:(/*^block*/id)arg3 ;
-(void)_didSuspend;
@end

@interface SBApplicationController : NSObject
+(id)sharedInstance;
+(id)sharedInstanceIfExists;
-(SBApplication *)applicationWithBundleIdentifier:(id)arg1 ;
-(void)applicationVisibilityMayHaveChanged;
-(SBApplication *)applicationWithPid:(int)arg1 ;
@end

@interface RBProcessMap : NSObject
-(id)allState;
-(id)stateForIdentity:(id)arg1 ;
-(id)setState:(id)arg1 forIdentity:(id)arg2 ;
@end

@interface RBPowerAssertion : NSObject
@end

@interface RBSystemPowerAssertion : RBPowerAssertion
@end

@interface RBProcessPowerAssertion : RBPowerAssertion
@end

@interface RBPowerAssertionManager : NSObject
@end


@interface RBAssertion : NSObject
@property (nonatomic,copy,readonly) NSArray * attributes;
@end


@interface RBAssertionManager : NSObject
-(id)allEntitlements;
@end

@interface RBSLaunchContext : NSObject
+(id)contextWithIdentity:(id)arg1 ;
@end

@interface RBSRequest : NSObject
@end

@interface RBSLaunchRequest : RBSRequest
-(id)initWithContext:(id)arg1 ;
@end

@interface RBLaunchdJob : NSObject
+(id)newJobWithIdentity:(id)arg1 launchContext:(id)arg2 error:(id*)arg3 ;
-(BOOL)startWithError:(id*)arg1 ;
@end

@interface FBProcessExecutionContext : NSObject
-(id)initWithIdentity:(id)arg1;
-(void)setLaunchIntent:(long long)arg1 ;
@end




@interface FBApplicationProcessWatchdogPolicy : NSObject
+(id)defaultPolicy;
@end


@interface FBProcessManager : NSObject
+(id)sharedInstance;
-(id)processesForBundleIdentifier:(id)arg1 ;
-(void)launchProcessWithContext:(id)arg1 ;
-(void)_queue_addProcess:(id)arg1 ;
-(void)_queue_addForegroundRunningProcess:(id)arg1 ;
-(id)allApplicationProcesses;
-(id)allProcesses;
-(void)launchProcessWithContext:(id)arg1 ;
-(id)applicationProcessesForBundleIdentifier:(id)arg1 ;
-(void)_setPreferredForegroundApplicationProcess:(id)arg1 deferringToken:(id)arg2 ;
-(void)setDefaultWatchdogPolicy:(FBApplicationProcessWatchdogPolicy *)arg1 ;
-(void)_queue_evaluateForegroundEventRouting;
-(id)_createProcessWithExecutionContext:(id)arg1 ;
-(id)registerProcessForHandle:(id)arg1 ;
-(void)_queue_removeProcess:(id)arg1 withPID:(int)arg2 ;
-(void)_queue_removeForegroundRunningProcess:(id)arg1 ;
@end

@interface FBApplicationProcessLaunchTransaction : NSObject
-(FBProcess *)process;
-(void)_queue_launchProcess:(id)arg1 ;
-(void)_queue_processWillLaunch:(id)arg1 ;
-(void)_queue_finishProcessLaunch:(BOOL)arg1 ;
-(id)initWithApplicationProcess:(id)arg1 ;
@end



@interface SpringBoard : UIApplication
-(BOOL)launchApplicationWithIdentifier:(id)arg1 suspended:(BOOL)arg2;
-(void)_simulateLockButtonPress;
-(void)_simulateHomeButtonPress;
-(void)takeScreenshot;
-(void)setBatterySaverModeActive:(BOOL)arg1;
-(BOOL)isBatterySaverModeActive;
-(void)showPowerDownAlert;
-(BOOL)isShowingHomescreen;
- (void)setNextAssistantRecognitionStrings:(id)arg1;
-(int)nowPlayingProcessPID;
-(SBApplication *)_accessibilityFrontMostApplication;

@end

@interface SBWorkspace : NSObject
@end

@interface SBWorkspaceEntity : NSObject
+(instancetype)entity;
-(id)deviceApplicationSceneEntity;
@end

@interface SBApplicationSceneEntity : SBWorkspaceEntity
@end

@interface SBDeviceApplicationSceneEntity : SBApplicationSceneEntity
-(id)initWithApplicationSceneHandle:(id)arg1 ;
+(id)newEntityWithApplicationForMainDisplay:(id)arg1 ;
+(id)defaultEntityWithApplicationForMainDisplay:(id)arg1 ;
+(id)defaultEntityWithApplicationForMainDisplay:(id)arg1 targetContentIdentifier:(id)arg2 ;
+(id)entityWithApplicationForMainDisplay:(id)arg1 withScenePersistenceIdentifier:(id)arg2 ;
@end



@interface BSEventQueueLock : NSObject
@end

@interface RBSAssertionIdentifier : NSObject
@property (nonatomic,readonly) int pid;
@end


@interface RBSConnection : NSObject{
    NSMapTable* _acquiredAssertionsByIdentifier;
}
+(id)sharedInstance;
+(id)connectionQueue;
-(BOOL)invalidateAssertion:(id)arg1 error:(NSError **)arg2 ;
-(RBSAssertionIdentifier *)acquireAssertion:(id)arg1 error:(NSError **)arg2 ;
-(BOOL)invalidateAssertionWithIdentifier:(id)arg1 error:(NSError **)arg2 ;
-(void)subscribeToProcessDeath:(RBSProcessIdentifier *)arg1 handler:(/*^block*/id)arg2 ;
@end

@interface RBSXPCMessage : NSObject
+(id)messageForMethod:(SEL)arg1 varguments:(id)arg2 ;
+(id)messageForXPCMessage:(id)arg1;
@end

@interface RBConnectionContext : NSObject
@end

@interface RBConnectionClient : NSObject
@property (nonatomic,readonly) RBProcess * process;
@property (nonatomic,copy,readonly) RBSProcessIdentity * processIdentity;
+(id)sharedLaunchWorkloop;
+(id)sharedTerminationWorkloop;
-(BOOL)invalidateAssertionWithIdentifier:(id)arg1 error:(out id*)arg2 ;
-(id)initWithContext:(RBConnectionContext *)context process:(RBProcess *)proc connection:(id)connection ;
-(void)willExpireAssertionsSoonForProcess:(id)arg1 expirationTime:(double)arg2 ;
-(void)willInvalidateAssertion:(id)arg1 ;
-(void)didInvalidateAssertions:(id)arg1 ;
-(void)didRemoveProcess:(id)arg1 withState:(id)arg2 ;
@end

@interface SBRestartManager : NSObject
@end

@interface SBSyncController : NSObject
+(id)sharedInstance;
@end

@interface SBFMobileKeyBagState : NSObject
@end

@interface SBFMutableMobileKeyBagState : SBFMobileKeyBagState
-(id)init;
-(id)copyWithZone:(NSZone*)arg1 ;
-(void)setLockState:(long long)arg1 ;
-(void)setFailedAttemptCount:(unsigned long long)arg1 ;
-(id)initWithMKBLockStateInfo:(id)arg1 ;
-(id)_mutableState;
-(void)setBackOffTime:(double)arg1 ;
-(void)setPermanentlyBlocked:(BOOL)arg1 ;
-(void)setShouldWipe:(BOOL)arg1 ;
-(void)setRecoveryRequired:(BOOL)arg1 ;
-(void)setRecoveryPossible:(BOOL)arg1 ;
-(void)setRecoveryEnabled:(BOOL)arg1 ;
-(void)setEscrowCount:(long long)arg1 ;
@end

@interface SBFMobileKeyBag : NSObject
@property (nonatomic,copy,readonly) SBFMobileKeyBagState * state;
@property (nonatomic,copy,readonly) SBFMobileKeyBagState * extendedState;
@property (nonatomic,readonly) BOOL hasBeenUnlockedSinceBoot;
@property (nonatomic,readonly) BOOL hasPasscodeSet;
@property (nonatomic,readonly) long long maxUnlockAttempts; 
+(id)sharedInstance;
-(id)init;
-(void)_queue_handleKeybagStatusChanged;
@end

@interface SBApplicationAutoLaunchService : NSObject
-(id)_initWithWorkspace:(id)arg1 applicationController:(id)arg2 restartManager:(id)arg3 syncController:(id)arg4 keybag:(id)arg5 ;
-(BOOL)_shouldAutoLaunchApplication:(id)arg1 forReason:(unsigned long long)arg2 ;
@end

@interface SBPrototypeController : NSObject
@property (assign,nonatomic) SBRestartManager * restartManager;
+(id)sharedInstance;
@end


@protocol SBActivationSettings <NSObject>
@required
-(BOOL)boolForActivationSetting:(unsigned)arg1;
-(id)objectForActivationSetting:(unsigned)arg1;
-(void)applyActivationSettings:(id)arg1;
-(void)setObject:(id)arg1 forActivationSetting:(unsigned)arg2;
-(void)setFlag:(long long)arg1 forActivationSetting:(unsigned)arg2;
-(long long)flagForActivationSetting:(unsigned)arg1;
-(id)copyActivationSettings;
-(void)clearActivationSettings;

@end

@interface SBActivationSettings : NSObject <SBActivationSettings>
@end


@interface FBSOpenApplicationOptions : NSObject
+(id)optionsWithDictionary:(id)arg1 ;
-(void)_sanitizeAndValidatePayload;
@end


@interface FBSystemServiceOpenApplicationRequest : NSObject
+(id)request;
-(void)setOptions:(FBSOpenApplicationOptions *)arg1 ;
-(void)setBundleIdentifier:(NSString *)arg1 ;
-(void)setTrusted:(BOOL)arg1 ;
-(void)setClientProcess:(FBProcess *)arg1 ;
@end

@interface FBSystemService : NSObject
+(id)sharedInstance;
@end

@interface SBWorkspaceTransitionContext : NSObject
@end

@interface SBWorkspaceApplicationSceneTransitionContext : SBWorkspaceTransitionContext
-(void)setEntity:(id)arg1 forLayoutRole:(long long)arg2 ;
-(id)entityForLayoutRole:(long long)arg1 ;
@end


@interface SBWorkspaceTransitionRequest : NSObject
@property (nonatomic,retain) BSProcessHandle * originatingProcess;
-(void)setApplicationContext:(SBWorkspaceApplicationSceneTransitionContext *)arg1 ;
@end


@interface SBMainWorkspaceTransitionRequest : SBWorkspaceTransitionRequest
-(id)initWithDisplayConfiguration:(id)arg1 ;
@end

@interface SBMainWorkspace : SBWorkspace
+(id)sharedInstance;
+(id)_instanceIfExists;
+(id)_sharedInstanceWithNilCheckPolicy:(long long)arg1 ;
-(void)systemService:(FBSystemService *)arg1 handleOpenApplicationRequest:(FBSystemServiceOpenApplicationRequest *)arg2 withCompletion:(/*^block*/id)arg3 ;
-(void)_resume;
-(void)applicationProcessWillLaunch:(FBApplicationProcess *)arg1 ;
-(void)applicationProcessDidLaunch:(FBApplicationProcess *)arg1 ;
-(void)_updateFrontMostApplicationEventPort;
-(void)_finishInitialization;
-(void)_updateMedusaEnablementAndNotify:(BOOL)arg1 ;
-(void)_handleTrustedOpenRequestForApplication:(id)arg1 options:(id)arg2 activationSettings:(id)arg3 origin:(id)arg4 withResult:(/*^block*/id)arg5 ;
-(void)_handleOpenApplicationRequest:(id)arg1 options:(id)arg2 activationSettings:(id)arg3 origin:(id)arg4 withResult:(/*^block*/id)arg5 ;
-(id)_validateRequestToOpenApplication:(id)arg1 options:(id)arg2 origin:(id)arg3 error:(out id*)arg4 ;
-(SBMainWorkspaceTransitionRequest *)createRequestWithOptions:(unsigned long long)arg1 ; //12
-(SBMainWorkspaceTransitionRequest *)createRequestForApplicationActivation:(SBDeviceApplicationSceneEntity *)arg1 options:(unsigned long long)arg2 ; //0
-(void)_suspend;
-(void)_resume;
-(BOOL)executeTransitionRequest:(id)arg1 ;
-(void)setCurrentTransaction:(id)arg1 ;
-(id)_transactionForTransitionRequest:(id)arg1 ;
-(void)_destroyApplicationSceneEntity:(id)arg1 ;
-(void)applicationProcessDidExit:(id)arg1 withContext:(id)arg2 ;
-(void)updateFrontMostApplicationEventPort;
@end

@interface RBConnectionListener : NSObject
@property (nonatomic,readonly) NSArray * clients;
+(id)sharedConnectionWorkloop;
@end

@interface RBSProcessStateUpdate : NSObject
+(id)updateWithState:(id)arg1 previousState:(id)arg2 ;
@end


@interface PCPersistentInterfaceManager : NSObject{
    NSMapTable *_delegatesAndQueues;
}
+(id)sharedInstance;
@end

@interface NSMapTable(Bakgrunnur)
-(id)allKeys;
@end


//timer
@interface PCSimpleTimer : NSObject
@property BOOL disableSystemWaking;
- (BOOL)disableSystemWaking;
- (id)initWithFireDate:(id)arg1 serviceIdentifier:(id)arg2 target:(id)arg3 selector:(SEL)arg4 userInfo:(id)arg5;
- (id)initWithTimeInterval:(double)arg1 serviceIdentifier:(id)arg2 target:(id)arg3 selector:(SEL)arg4 userInfo:(id)arg5;
- (void)invalidate;
- (BOOL)isValid;
- (void)scheduleInRunLoop:(id)arg1;
- (void)setDisableSystemWaking:(BOOL)arg1;
- (id)userInfo;
@end

//timer
@interface PCPersistentTimer : NSObject
@property BOOL disableSystemWaking;
- (BOOL)disableSystemWaking;
- (id)initWithFireDate:(id)arg1 serviceIdentifier:(id)arg2 target:(id)arg3 selector:(SEL)arg4 userInfo:(id)arg5;
- (id)initWithTimeInterval:(double)arg1 serviceIdentifier:(id)arg2 target:(id)arg3 selector:(SEL)arg4 userInfo:(id)arg5;
- (void)invalidate;
- (BOOL)isValid;
- (void)scheduleInRunLoop:(id)arg1;
- (void)setDisableSystemWaking:(BOOL)arg1;
-(void)setMinimumEarlyFireProportion:(double)arg1 ;
-(void)setEarlyFireConstantInterval:(double)arg1 ;
-(NSDictionary *)userInfo;
@end

@interface SBLockScreenManager : NSObject
+(id)sharedInstanceIfExists;
-(BOOL)isUILocked;
@end

@interface SBLockStateAggregator : NSObject
+(id)sharedInstance;
-(id)init;
-(void)dealloc;
-(id)description;
-(unsigned long long)lockState;
-(void)_updateLockState;
-(BOOL)hasAnyLockState;
@end

@interface SBSRelaunchAction : NSObject
@property (nonatomic, readonly) unsigned long long options;
@property (nonatomic, readonly, copy) NSString *reason;
@property (nonatomic, readonly, retain) NSURL *targetURL;
+ (id)actionWithReason:(id)arg1 options:(unsigned long long)arg2 targetURL:(id)arg3;
- (id)initWithReason:(id)arg1 options:(unsigned long long)arg2 targetURL:(id)arg3;
- (unsigned long long)options;
- (id)reason;
- (id)targetURL;

@end

@interface FBSSystemService : NSObject
+ (id)sharedService;
- (void)sendActions:(id)arg1 withResult:(/*^block*/id)arg2;
-(int)pidForApplication:(id)arg1 ;
-(void)openApplication:(id)arg1 options:(id)arg2 withResult:(/*^block*/id)arg3 ;
-(void)terminateApplication:(id)arg1 forReason:(long long)arg2 andReport:(BOOL)arg3 withDescription:(id)arg4 completion:(/*^block*/id)arg5 ;
@end

@interface SBIcon : NSObject
-(id)applicationBundleID;
-(void)_notifyAccessoriesDidUpdate;
@end

@interface SBHIconModel : NSObject
-(void)reloadIcons;
@property (assign,getter=isRestoring,nonatomic) BOOL restoring;
@end

@interface SBIconModel : SBHIconModel
-(id)applicationWithBundleIdentifier:(id)arg1 ;
-(SBIcon *)applicationIconForBundleIdentifier:(id)arg1 ;
@end

@interface SBIconController : UIViewController
+(id)sharedInstance;
-(SBIconModel *)model;
@end

@interface SBFolderIcon : SBIcon
//@property (nonatomic,readonly) SBFolder * folder;
@end

@interface SBFolder : NSObject
@property (assign,nonatomic) SBFolderIcon * icon;
@property (nonatomic,copy,readonly) NSArray * icons;
@property (nonatomic,copy,readonly) NSArray * iconsInLists;
@property (assign,getter=isOpen,nonatomic) BOOL open;
@property (nonatomic,copy,readonly) NSString * uniqueIdentifier;
-(id)folderIcons;
-(id)allIcons;

@end



@interface SBIconView : UIView
@property (nonatomic,retain) SBIcon * icon;
@property (assign,getter=isLabelHidden,nonatomic) BOOL labelHidden;
@property (assign,getter=isInDock,nonatomic) BOOL inDock;
@property (nonatomic,retain) SBFolderIcon * folderIcon;
@property (nonatomic,copy) NSString * location; // iOS 14 - SBIconLocationDock | SBIconLocationRoot | SBIconLocationFolder | SBIconLocationFloatingDockSuggestions
@property (nonatomic,copy,readonly) NSString * representedFolderIconLocation; // iOS 14 - SBIconLocationFolder
-(void)setLabelAccessoryHidden:(BOOL)arg1 ;
-(void)_updateLabelAccessoryView;
-(BOOL)isDragging;
-(void)_updateLabel;
-(id)applicationBundleIdentifier;
-(id)applicationBundleIdentifierForShortcuts;
-(SBFolder *)folder;
-(void)setLabelAccessoryHidden:(BOOL)arg1 ;
@end

@interface SBFolderView : UIView
@property (nonatomic,retain) SBFolder * folder;
@end

@interface SBSApplicationShortcutIcon : NSObject
@property (readonly) unsigned long long hash;
@property (readonly) Class superclass;
@property (copy,readonly) NSString * description;
@property (copy,readonly) NSString * debugDescription;
-(id)init;
-(void)encodeWithXPCDictionary:(id)arg1 ;
-(id)initWithXPCDictionary:(id)arg1 ;
-(id)_initForSubclass;
@end

@interface SBSApplicationShortcutSystemPrivateIcon : SBSApplicationShortcutIcon {
    NSString* _systemImageName;
}
@property (nonatomic,readonly) NSString * systemImageName;
-(BOOL)isEqual:(id)arg1 ;
-(unsigned long long)hash;
-(void)encodeWithXPCDictionary:(id)arg1 ;
-(id)initWithXPCDictionary:(id)arg1 ;
-(id)initWithSystemImageName:(id)arg1 ;
-(id)_initForSubclass;
-(NSString *)systemImageName;
@end



@interface SBSApplicationShortcutItem : NSObject <NSCopying>
@property (nonatomic,copy) NSString * type;
@property (nonatomic,copy) NSString * localizedTitle;
@property (nonatomic,copy) NSString * localizedSubtitle;
@property (nonatomic,copy) NSString * bundleIdentifierToLaunch;
@property (nonatomic,copy) SBSApplicationShortcutIcon * icon;
@property (assign,nonatomic) unsigned long long activationMode; 
@end

//iOS 11/12 only
@interface SBUIAppIconForceTouchControllerDataProvider : NSObject
-(NSString *)applicationBundleIdentifier;
@end
//end iOS 11/12 only

@interface SBLeafIcon : SBIcon
@property (nonatomic,copy,readonly) NSString * applicationBundleID; 
@end

@interface SBApplicationIcon : SBLeafIcon
@end

@interface SBIconListView : UIView
@property (nonatomic,copy,readonly) NSArray <SBApplicationIcon *>* icons;
@property (nonatomic,copy,readonly) NSArray <SBApplicationIcon *>* visibleIcons;
@end

@interface SBDockIconListView : SBIconListView
@end

@interface SBFloatingDockView : NSObject
@property (nonatomic,retain) SBDockIconListView * userIconListView;
@property (nonatomic,retain) SBDockIconListView * recentIconListView;
@end

@interface SBControlCenterController : NSObject
+(id)sharedInstance;
-(void)dismissAnimated:(BOOL)arg1 completion:(/*^block*/id)arg2 ;
@end

@interface NCNotificationRequest : NSObject
@property (nonatomic,copy,readonly) NSString * sectionIdentifier;
+(id)notificationRequest;
-(id)initWithNotificationRequest:(id)arg1 ;
@end

#import <UserNotifications/UserNotifications.h>

@interface UNNotification (Private)
+(id)notificationWithRequest:(id)arg1 date:(id)arg2;
@end

@interface NCMutableNotificationRequest : NCNotificationRequest
@property (nonatomic,copy) NSString * sectionIdentifier;
@property (nonatomic,copy) NSString * notificationIdentifier;
@property (nonatomic,copy) NSString * threadIdentifier;
@property (nonatomic,copy) NSString * categoryIdentifier;
@property (nonatomic,copy) NSSet * subSectionIdentifiers;
@property (nonatomic,copy) NSString * highestPrioritySubSectionIdentifier;
@property (nonatomic,copy) NSArray * intentIdentifiers;
@property (nonatomic,copy) NSArray * peopleIdentifiers;
@property (nonatomic,copy) NSString * parentSectionIdentifier;
@property (assign,getter=isUniqueThreadIdentifier,nonatomic) BOOL uniqueThreadIdentifier;
@property (nonatomic,retain) NSDate * timestamp;
@property (nonatomic,copy) NSSet * requestDestinations;
@property (nonatomic,copy) NSDictionary * context;
@property (nonatomic,copy) NSSet * settingsSections;
@property (nonatomic,retain) UNNotification * userNotification;
@end

@interface APSMessage : NSObject
@property (nonatomic,retain) NSString * topic;
@property (nonatomic,retain) NSDictionary * userInfo;
@property (assign,nonatomic) unsigned long long identifier;
@property (nonatomic,retain) NSString * correlationIdentifier;
@end

@interface APSIncomingMessage : APSMessage
@end

@interface NCNotificationDispatcher : NSObject
-(void)postNotificationWithRequest:(id)arg1 ;
@end

@interface SBNCNotificationDispatcher : NSObject
@property (nonatomic,retain) NCNotificationDispatcher * dispatcher;
@end

@interface UNSApplicationService : NSObject
-(void)willPresentNotification:(id)arg1 forBundleIdentifier:(id)arg2 withCompletionHandler:(/*^block*/id)arg3 ;
-(void)_queue_willPresentNotification:(id)arg1 forBundleIdentifier:(id)arg2 withCompletionHandler:(/*^block*/id)arg3 ;
@end

@interface UNSUserNotificationServer : NSObject
-(void)addNotificationRequest:(id)arg1 forBundleIdentifier:(id)arg2 withCompletionHandler:(/*^block*/id)arg3;
-(void)_didChangeApplicationState:(unsigned)arg1 forBundleIdentifier:(id)arg2 ;
@end


@interface SBDisplayItem : NSObject
@property (nonatomic,copy,readonly) NSString * bundleIdentifier;
@end

@interface SBAppLayout : NSObject
@property (nonatomic,copy) NSDictionary * rolesToLayoutItemsMap;
@end

@protocol SBSwitcherContentViewControlling
-(void)noteAppLayoutsDidChange;
@end


@interface SBFluidSwitcherViewController : UIViewController
-(void)noteAppLayoutsDidChange;
-(void)_updateVisibleItemsLayoutAndStyleWithBehaviorMode:(long long)arg1 completion:(/*^block*/id)arg2 ;
-(void)_updateVisibleItems;
@end

@interface SBGridSwitcherViewController : SBFluidSwitcherViewController
@end

@interface SBMainSwitcherViewController : UIViewController
@property (nonatomic,readonly) UIViewController <SBSwitcherContentViewControlling> *contentViewController;
-(void)_insertCardForDisplayIdentifier:(id)arg1 atIndex:(unsigned long long)arg2 ;
-(void)switcherContentController:(id)arg1 bringAppLayoutToFront:(id)arg2 ;
-(void)_addAppLayoutToFront:(id)arg1 ;
@end

@interface SBDashBoardApplicationLauncher : NSObject
-(void)_activateAppSceneBelowDashBoard:(id)arg1 secureAppType:(unsigned long long)arg2 withActions:(id)arg3 interactive:(BOOL)arg4 completion:(/*^block*/id)arg5 ;
@end

@interface SBDashBoardLockScreenEnvironment : NSObject{
    SBDashBoardApplicationLauncher* _applicationLauncher;
}
@end

@interface SBSceneManagerReference : NSObject
-(id)initWithDisplayIdentity:(id)arg1 ;
@end

@interface BSEventQueue : NSObject
@property (nonatomic,copy,readonly) NSString * name;
@property (getter=isLocked,nonatomic,readonly) BOOL locked;
@property (getter=isEmpty,nonatomic,readonly) BOOL empty;
@property (nonatomic,copy,readonly) NSArray * pendingEvents;
@end

@interface UIApplicationSceneDeactivationAssertion : NSObject
-(void)acquire;
-(void)acquireWithPredicate:(/*^block*/id)arg1 transitionContext:(id)arg2 ;
@end

@interface UIApplicationSceneDeactivationManager : NSObject
-(void)_setDeactivationReasons:(unsigned long long)arg1 onScene:(FBScene *)arg2 withSettings:(UIMutableApplicationSceneSettings *)arg3 reason:(NSString *)arg4;
-(void)_untrackScene:(id)arg1 ;
-(void)endTrackingScene:(id)arg1 ;
-(UIApplicationSceneDeactivationAssertion *)newAssertionWithReason:(long long)arg1 ;
-(void)_updateScenesWithTransitionContext:(id)arg1 reason:(id)arg2 ;
@end

@interface SBSceneManagerCoordinator : NSObject
@property (nonatomic,readonly) UIApplicationSceneDeactivationManager * sceneDeactivationManager;
+(id)sharedInstance;
+(id)mainDisplaySceneManager;
+(id)secureMainDisplaySceneManager;
-(UIApplicationSceneDeactivationManager *)sceneDeactivationManager;
@end

@interface SBDeactivationSettings : NSObject
-(void)setFlag:(long long)arg1 forDeactivationSetting:(unsigned)arg2 ;
@end


@interface SBApplication ()
-(void) _setDeactivationSettings:(SBDeactivationSettings*)arg1;
@end

@interface BSTransaction : NSObject
@end

@interface SBTransaction : BSTransaction
@end

@interface SBWorkspaceTransaction : SBTransaction
@end

@interface SBMainWorkspaceTransaction : SBWorkspaceTransaction
@end

@interface SBToAppsWorkspaceTransaction : SBMainWorkspaceTransaction
@end

@interface SBAppToAppWorkspaceTransaction : SBToAppsWorkspaceTransaction
-(id)initWithTransitionRequest:(id)arg1 ;
-(void)_begin;
@end

@interface FBWorkspaceEventQueue : BSEventQueue
+(id)sharedInstance;
-(void)executeOrAppendEvent:(id)arg1 ;
-(void)executeOrPrependEvent:(id)arg1 ;
-(void)executeOrPrependEvents:(id)arg1 ;
@end

@interface BSEventQueueEvent : NSObject
+(id)eventWithName:(id)arg1 handler:(/*^block*/id)arg2 ;
@end

@interface FBWorkspaceEvent : BSEventQueueEvent
@end

@interface BKSAssertion : NSObject
-(void)invalidate;
-(BOOL)acquire;
-(BOOL)valid;
@end

@interface BKSProcessAssertion : BKSAssertion
+(id)NameForReason:(unsigned)arg1 ;
-(id)initWithPID:(int)arg1 flags:(unsigned)arg2 reason:(unsigned)arg3 name:(id)arg4 withHandler:(/*^block*/id)arg5 acquire:(BOOL)arg6 ;
-(void)assertion:(id)arg1 didInvalidateWithError:(id)arg2 ;
-(id)initWithPID:(int)arg1 flags:(unsigned)arg2 reason:(unsigned)arg3 name:(id)arg4 ;
-(id)initWithBundleIdentifier:(id)arg1 flags:(unsigned)arg2 reason:(unsigned)arg3 name:(id)arg4 ;
-(id)initWithBundleIdentifier:(id)arg1 flags:(unsigned)arg2 reason:(unsigned)arg3 name:(id)arg4 withHandler:(/*^block*/id)arg5 acquire:(BOOL)arg6 ;
-(void)dealloc;
-(id)initWithBundleIdentifier:(id)arg1 pid:(int)arg2 flags:(unsigned)arg3 reason:(unsigned)arg4 name:(id)arg5 withHandler:(/*^block*/id)arg6 acquire:(BOOL)arg7 ;
-(BOOL)acquire;
-(id)initWithBundleIdentifier:(id)arg1 flags:(unsigned)arg2 reason:(unsigned)arg3 name:(id)arg4 withHandler:(/*^block*/id)arg5 ;
-(unsigned long long)_legacyFlagsForFlags:(unsigned)arg1 ;
-(id)initWithPID:(int)arg1 flags:(unsigned)arg2 reason:(unsigned)arg3 name:(id)arg4 withHandler:(/*^block*/id)arg5 ;
-(unsigned long long)_legacyReasonForReason:(unsigned)arg1 ;
-(void)setFlags:(unsigned)arg1 ;
-(unsigned)reason;
-(unsigned)flags;
-(void)invalidate;
@end

typedef NS_ENUM(NSUInteger, ProcessAssertionFlags) {
    ProcessAssertionFlagNone = 0,
    ProcessAssertionFlagPreventSuspend         = 1 << 0,
    ProcessAssertionFlagPreventThrottleDownCPU = 1 << 1,
    ProcessAssertionFlagAllowIdleSleep         = 1 << 2,
    ProcessAssertionFlagWantsForegroundResourcePriority  = 1 << 3
};

@interface FBSSceneSnapshotContext : NSObject
+(id)contextWithSceneID:(NSString *)arg1 settings:(FBSSceneSettings *)arg2 ;
@end

@interface BSAction : NSObject
@end

@interface FBSSceneSnapshotRequestAction : BSAction
-(id)initWithType:(unsigned long long)arg1 context:(FBSSceneSnapshotContext *)arg2 completion:(/*^block*/id)arg3 ;
@end


@protocol BSInvalidatable <NSObject>
@required
-(void)invalidate;

@end

@interface SBSceneBackgroundedStatusAssertion : NSObject
-(void)invalidate;
@end

@interface SBSceneManager : NSObject{
    NSCountedSet* _assertedBackgroundScenes;
}
-(SBSceneBackgroundedStatusAssertion *)assertBackgroundedStatusForScenes:(NSSet *)scenes ;
-(void)invalidate;
-(void)_reconnectSceneRemnant:(id)arg1 forProcess:(id)arg2 sceneManager:(id)arg3 ;
-(id)existingSceneHandleForScene:(id)arg1 ;
@end

@interface SBMainDisplaySceneManager : SBSceneManager
-(BOOL)_handleAction:(FBSSceneSnapshotRequestAction *)arg1 forScene:(FBScene *)arg2 ;
@end


@interface SBSceneDisconnectionManager : NSObject
+(id)sharedManager;
-(void)disconnectScenes:(id)arg1 completion:(/*^block*/id)arg2 ;
-(id)liveScenesForApplication:(id)arg1 ;
@end

@interface CLAssertion : NSObject
-(void)invalidate;
@end

@interface CLInUseAssertion : CLAssertion
+(id)newAssertionForBundleIdentifier:(id)arg1 withReason:(id)arg2 ;
+(id)newAssertionForBundle:(id)arg1 withReason:(id)arg2 ;
+(id)newAssertionForBundleIdentifier:(id)arg1 bundlePath:(id)arg2 reason:(id)arg3 level:(int)arg4 ;
+(id)newAssertionForBundleIdentifier:(id)arg1 withReason:(id)arg2 level:(int)arg3 ;
+(id)newAssertionForBundle:(id)arg1 withReason:(id)arg2 level:(int)arg3 ;
@end

@interface RBSAttribute : NSObject
@end

enum {
	BKSProcessAssertionNone = 0,
	BKSProcessAssertionPreventTaskSuspend  = 1 << 0,             // prevents a process from being task suspended. If currently suspended, wakes it up.
	BKSProcessAssertionPreventTaskThrottleDown = 1 << 1,         // prevents a process from being deprioritized. If already throttled down, throttles it up.
	BKSProcessAssertionAllowIdleSleep = 1 << 2,                  // indicates if the process assertion should allow idle sleep or not
	BKSProcessAssertionWantsForegroundResourcePriority = 1 << 3, // suggests the jetsam priority be kept at the foreground level and prevents throttling of UI
	BKSProcessAssertionAllowSuspendOnSleep = 1 << 4,             // indicates if the process should be suspended on sleep until the device is again in use
	BKSProcessAssertionPreventThrottleDownUI = 1 << 5            // allows the process full graphics capabilities
};
typedef uint32_t BKSProcessAssertionFlags;

// BKSProcessAssertionReason
enum {
	BKSProcessAssertionReasonNone,
	BKSProcessAssertionReasonMediaPlayback,
	BKSProcessAssertionReasonLocation,
	BKSProcessAssertionReasonExternalAccessory,
	BKSProcessAssertionReasonFinishTask,
	BKSProcessAssertionReasonBluetooth,
	BKSProcessAssertionReasonNetworkAuthentication,
	BKSProcessAssertionReasonBackgroundUI,          // deprecated. Use BKSProcessAssertionReasonViewService instead.
	BKSProcessAssertionReasonInterAppAudioStreaming,
	BKSProcessAssertionReasonViewService,
	BKSProcessAssertionReasonNewsstandDownload,
	BKSProcessAssertionReasonBackgroundDownload,
	BKSProcessAssertionReasonVoIP,
	BKSProcessAssertionReasonExtension,
	BKSProcessAssertionReasonContinuityStreams,
	BKSProcessAssertionReasonHealthKit,
	BKSProcessAssertionReasonWatchConnectivity,
	BKSProcessAssertionReasonSnapshot,
	BKSProcessAssertionReasonComplicationUpdate,
	BKSProcessAssertionReasonWorkoutProcessing,
	BKSProcessAssertionReasonComplicationPushUpdate,
	BKSProcessAssertionReasonBackgroundLocationProcessing,
	BKSProcessAssertionReasonBackgroundComputation,
	BKSProcessAssertionReasonAudioRecording,
	BKSProcessAssertionReasonFinishTaskReduced,

	// The following reasons can only be taken by SpringBoard
	BKSProcessAssertionReasonResume = 10000,
	BKSProcessAssertionReasonSuspend,
	BKSProcessAssertionReasonTransientWakeup, // systemApp only
	BKSProcessAssertionReasonPeriodicTask,
	BKSProcessAssertionReasonFinishTaskUnbounded, // internal and systemApp only
	BKSProcessAssertionReasonContinuous,
	BKSProcessAssertionReasonBackgroundContentFetching,
	BKSProcessAssertionReasonNotificationAction,
	BKSProcessAssertionReasonPIP,

	// The following reasons are internal only and should not be used by any clients
	BKSProcessAssertionReasonFinishTaskAfterBackgroundContentFetching = 50000,
	BKSProcessAssertionReasonFinishTaskAfterBackgroundDownload,
	BKSProcessAssertionReasonFinishTaskAfterPeriodicTask,
	BKSProcessAssertionReasonFinishTaskAfterNotificationAction,
	BKSProcessAssertionReasonFinishTaskAfterWatchConnectivity,
};
typedef uint32_t BKSProcessAssertionReason;

/*
typedef NS_ENUM(NSUInteger, RBSLegacyFlags) {
    RBSLegacyFlagAllowIdleSleep = 4,
    RBSLegacyFlagAllowSuspendOnSleep = 16,
    RBSLegacyFlagPreventTaskSuspend = 1,
    RBSLegacyFlagPreventTaskThrottleDown = 2,
    RBSLegacyFlagPreventThrottleDownUI = 32,
    RBSLegacyFlagWantsForegroundResourcePriority = 8
};
*/

@interface RBSLegacyAttribute : RBSAttribute
+(id)attributeWithReason:(BKSProcessAssertionReason)arg1 flags:(BKSProcessAssertionFlags)arg2 ;
@end

@interface RBSGrant : RBSAttribute
@end

@interface RBSHereditaryGrant : RBSGrant
+(id)grantWithNamespace:(id)arg1 sourceEnvironment:(id)arg2 endowment:(id)arg3 attributes:(id)arg4 ;
+(id)grantWithNamespace:(id)arg1 sourceEnvironment:(id)arg2 attributes:(id)arg3 ;
+(id)grantWithNamespace:(id)arg1 endowment:(id)arg2 attributes:(id)arg3 ;
@end

@interface RBSPreventIdleSleepGrant : RBSGrant
+(id)grant;
@end

@interface RBSAppNapPreventBackgroundSocketsGrant : RBSGrant
+(id)grant;
@end

@interface RBSAppNapInactiveGrant : RBSGrant
+(id)grant;
@end

@interface RBSResistTerminationGrant : RBSGrant
+(id)grantWithResistance:(unsigned char)arg1 ;
@end

@interface RBSRunningReasonAttribute : RBSAttribute
+(id)withReason:(unsigned long long)arg1 ;
@end

@interface RBSLimitation : RBSAttribute
@end

typedef NS_ENUM(NSUInteger, RBSRole){
	RBSRoleUnknown,
	RBSRoleBackground,
	RBSRoleLaunchTAL,
	RBSRoleNonUserInteractive,
	RBSRoleUserInteractiveNonFocal,
	RBSRoleUserInteractive,
	RBSRoleUserInteractiveFocal
};

typedef NS_ENUM(NSUInteger, RBSCPUViolationPolicy){
	RBSCPUViolationPolicyInvalidateAndTerminateProcess,
	RBSCPUViolationPolicyInvalidate,
	RBSCPUViolationPolicyLog
};

@interface RBSCPUMaximumUsageLimitation : RBSLimitation
+(id)limitationForRole:(unsigned char)arg1 withPercentage:(unsigned long long)arg2 duration:(double)arg3 violationPolicy:(unsigned long long)arg4 ;
@end

@interface RBSCPUAccessGrant : RBSGrant
+(id)grantWithRole:(unsigned char)arg1 ;
+(id)grantWithUserInteractivityAndFocus;
+(id)grant;
+(id)grantUserInitiated;
+(id)grantWithUserInteractivity;
@end

@interface RBSGPUAccessGrant : RBSGrant
+(id)grant;
@end

@interface RBSAssertion : NSObject
@property (nonatomic,readonly) RBSTarget * target;
@property (nonatomic,copy,readonly) RBSAssertionIdentifier * identifier;
@property (nonatomic,readonly) unsigned long long state;
@property (getter=isValid,nonatomic,readonly) BOOL valid;
@property (nonatomic,copy,readonly) NSArray * attributes;
-(id)initWithExplanation:(NSString *)arg1 target:(RBSTarget *)arg2 attributes:(NSArray *)arg3 ;
-(BOOL)acquireWithError:(NSError **)arg1 ;
-(void)acquireWithInvalidationHandler:(/*^block*/id)arg1 ;
-(void)invalidate;
@end
