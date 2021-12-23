#import <xpc/xpc.h>
#import <os/lock.h>
#import "PrivateHeaders.h"

@class RBSAssertion, FBScene;

@interface BKGBakgrunnur : NSObject{
    NSMutableDictionary <NSString *, RBSAssertion *>*_assertions;
    NSMutableDictionary <NSString *, RBSAssertionIdentifier *>*_assertionIdentifiers;
}
@property(nonatomic, strong) NSMutableArray *retiringIdentifiers;
@property(nonatomic, strong) NSMutableArray *queuedIdentifiers;
@property(nonatomic, strong) NSMutableArray *immortalIdentifiers;
@property(nonatomic, strong) NSMutableArray *advancedMonitoringIdentifiers;
@property(nonatomic, strong) __block NSMutableDictionary *advancedMonitoringHistory;
@property(nonatomic, strong) PCPersistentTimer *advancedMonitoringTimer;
@property(nonatomic, strong) NSMutableArray *pendingAccessoryUpdateFolderID;
@property(nonatomic, strong) NSArray *darkWakeIdentifiers;
//@property(nonatomic, strong) xpc_connection_t powerd_xpc_connection;
@property(nonatomic, strong) xpc_connection_t bkgd_xpc_connection;
@property(nonatomic, assign) BOOL isPreming;
@property(nonatomic, assign) int sleepingState;
@property(nonatomic, strong) __block NSDictionary *cachedNetstatOne;
@property(nonatomic, strong) __block NSDictionary *cachedNetstatTwo;
@property(nonatomic, strong) NSMutableArray *grantedOnceIdentifiers;
@property(nonatomic, strong) NSMutableArray *userInitiatedIdentifiers;
@property(nonatomic, strong) NSArray *dormantDarkWakeIdentifiers;
@property(nonatomic, assign) BOOL presentBanner;
@property(nonatomic, assign) BOOL temporarilyHaltBanner;

+(instancetype)sharedInstance;
-(void)setObject:(NSDictionary *)objectDict bundleIdentifier:(NSString *)bundleIdentifier;
-(BOOL)isEnabledForBundleIdentifier:(NSString *)bundleIdentifier;
-(BOOL)isEnabled;
-(void)update;
-(void)updateDarkWakeState;

-(void)invalidateQueue:(NSString *)identifier;
-(void)invalidateAllQueues;
-(void)invalidateAllQueuesIn:(NSArray *)identifiers;
-(void)queueProcess:(NSString *)identifier softRemoval:(BOOL)removeGracefully expirationTime:(double)expTime  completion:(void (^)())completionHandler;
-(NSArray<SBSApplicationShortcutItem*>*) stackBakgrunnurShortcut:(NSArray<SBSApplicationShortcutItem*>*)stockShortcuts bundleIdentifier:(NSString *)bundleIdentifier;
-(void)updateLabelAccessory:(NSString *)identifier;
-(void)updateLabelAccessoryForDockItem:(NSString *)identifier;
-(void)_retireAllScenesIn:(NSMutableArray *)identifiers;
-(void)_retireScene:(NSString *)identifier;
-(void)_terminateProcess:(NSString *)identifier;
-(void)startAdvancedMonitoringWithInterval:(double)interval;
-(void)notifySleepingState:(BOOL)sleep;
-(void)launchBundleIdentifier:(NSString *)bundleID trusted:(BOOL)trusted suspended:(BOOL)suspend withPayloadURL:(NSString *)payloadURL completion:(void (^)(NSError *error))completionHandler;
-(BOOL)isQueued:(NSString *)identifier;
//-(BOOL)invalidateAssertion:(NSString *)identifier;
-(int)pidForBundleIdentifier:(NSString *)bundleIdentifier;
-(void)presentBannerWithSubtitleIfPossible:(NSString *)subtitle forBundle:(NSString *)identifier;
-(void)acquireAssertionIfNecessary:(FBScene *)scene aggressive:(BOOL)aggressive;
-(void)cleanAssertionsForBundle:(NSString *)identifier;
//-(BOOL)invalidateAssertionForBundle:(NSString *)identifier;
//-(void)setTaskState:(RBSTaskState)rbsState forBundle:(NSString *)identifier;
-(NSString *)formattedExpiration:(double)seconds;
-(void)throttleBundles:(NSArray <NSString *> *)bundleIdentifiers percentages:(NSArray <NSNumber *> *)percentages; //nil percentages for restore all
-(void)throttleBundle:(NSString *)bundleIdentifier percentage:(int)percentage;
@end
