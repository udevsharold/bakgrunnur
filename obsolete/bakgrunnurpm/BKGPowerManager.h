#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#import <IOKit/pwr_mgt/IOPM.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <xpc/xpc.h>

@interface BKGPowerManager : NSObject
+(id)sharedInstance;
-(void)updateSleepingState:(BOOL)sleep;
-(void)handleUpdateSleepingStateMessage:(xpc_object_t)event;
//-(void)handleTaskEventsForPid:(xpc_object_t)event;
//-(NSDictionary *)updateState:(NSString *)name withUserInfo:(NSDictionary *)userInfo;
//-(void)updateDarkWake:(BOOL)preferDarkWake;
//-(void)releaseChargingAssertionIfHeld;
@end
