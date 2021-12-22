#import "../common.h"
#import <stdio.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#import <IOKit/pwr_mgt/IOPM.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <xpc/xpc.h>

@interface BKGDaemon : NSObject
@property(nonatomic, strong) xpc_connection_t xpc_listener;
@property(nonatomic, strong) dispatch_queue_t queue;
+(void)load;
+(id)sharedInstance;
-(void)handleTaskEventsForPid:(xpc_object_t)event;
-(void)handleCpuUsageForPid:(xpc_object_t)event;
-(void)handleThreadsCountForPid:(xpc_object_t)event;
-(void)handleUpdateSleepingState:(xpc_object_t)event;
-(void)handleNetstatForPids:(xpc_object_t)event;
@end
