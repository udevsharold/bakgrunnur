#import "../common.h"
//#import <mach/mach.h>
#import "BKGPowerManager.h"

static IOPMAssertionID sleepingAssertionID;
//static IOReturn chargingAssertionSuccess = KERN_FAILURE;

@implementation BKGPowerManager

+(void)load{
    [self sharedInstance];
}

+(id)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t token = 0;
    dispatch_once(&token, ^{
        sharedInstance = [self new];
    });
    return sharedInstance;
}

-(instancetype)init{
    if ((self = [super init])){
    }
    return self;
}

-(void)replyWithBoolResult:(BOOL)value event:(xpc_object_t)event{
    xpc_connection_t remote = NULL;
    remote = xpc_dictionary_get_remote_connection(event);
    xpc_object_t reply = xpc_dictionary_create_reply(event);
    xpc_dictionary_set_bool(reply, "result", value);
    xpc_connection_send_message(remote, reply);
}
/*
-(void)replyWithObject:(xpc_object_t)object event:(xpc_object_t)event{
    xpc_connection_t remote = NULL;
    remote = xpc_dictionary_get_remote_connection(event);
    xpc_connection_send_message(remote, object);
}
*/
-(void)handleUpdateSleepingStateMessage:(xpc_object_t)event{
    [self updateSleepingState:xpc_dictionary_get_bool(event, "BAKGRUNNUR_updateSleepingState")];
    [self replyWithBoolResult:YES event:event];
    //xpc_release(reply);
}
/*
-(void)handleTaskEventsForPid:(xpc_object_t)event{
    xpc_object_t taskEventsObject = [self taskEventsForPid:xpc_dictionary_get_uint64(event, "BAKGRUNNUR_taskEventsForPid")];
    [self replyWithObject:taskEventsObject event:event];
    //xpc_release(reply);
}
*/
/*
 -(void)logAssertionByProcess{
 CFDictionaryRef assertionStates;
 IOReturn status = IOPMCopyAssertionsByProcess(&assertionStates);
 if (status == kIOReturnSuccess){
 NSDictionary* dict = (__bridge_transfer NSDictionary*)assertionStates;
 for (id key in dict) {
 HBLogDebug(@"key: %@, value: %@ \n", key, [dict objectForKey:key]);
 }
 CFRelease(assertionStates);
 }
 }
 */

-(void)disableSleep{
    IOPMAssertionRelease(sleepingAssertionID);
    IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep, kIOPMAssertionLevelOn, CFSTR("Standing by for Bakgrunnur"), &sleepingAssertionID);
    
    //int timeoutSeconds = defaultPreventSleepingTimeout;
    //CFNumberRef cfTimeoutSeconds = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &timeoutSeconds);
    //IOPMAssertionSetProperty(sleepingAssertionID, kIOPMAssertionTimeoutKey, cfTimeoutSeconds);
    //[self logAssertionByProcess];
    HBLogDebug(@"Sleeping disabled");
}

-(void)enableSleep{
    IOPMAssertionRelease(sleepingAssertionID);
    //[self logAssertionByProcess];
    HBLogDebug(@"Sleeping enabled");
    
}

-(void)updateSleepingState:(BOOL)sleep{
    if (sleep){
        [self enableSleep];
    }else{
        [self disableSleep];
    }
}

/*
-(xpc_object_t)taskEventsForPid:(int)pid{
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;
    
    task_info_count = TASK_INFO_MAX;
    
    task_t task;
    task_for_pid(mach_task_self(), pid, &task);
    
    HBLogDebug(@"task %u", task);
    //mach calls
    kr = task_info(task, TASK_EVENTS_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return xpc_dictionary_create(NULL, NULL, 0);
    }
    task_events_info_t    events_info;
    events_info = (task_events_info_t)tinfo;
    
    xpc_object_t dictXPC = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_uint64(dictXPC, "syscalls_mach", events_info->syscalls_mach);
    return dictXPC;
    /*
    return @{@"syscalls_mach":@(events_info->syscalls_mach),
             @"syscalls_unix":@(events_info->syscalls_unix),
             @"syscalls_total":@(events_info->syscalls_mach + events_info->syscalls_unix),
             @"messages_sent":@(events_info->messages_sent),
             @"messages_received":@(events_info->messages_received),
             @"faults":@(events_info->faults),
             @"pageins":@(events_info->pageins),
             @"cow_faults":@(events_info->cow_faults)
    };
     *
}
*/
/*
 -(NSDictionary *)updateState:(NSString *)name withUserInfo:(NSDictionary *)userInfo{
 [self updateState:[userInfo[@"enableCharging"] boolValue]];
 return @{};
 }
 */
/*
 -(void)preferDarkWakeState{
 #define kIOPMAssertionTypeDenySystemSleep                   CFSTR("DenySystemSleep")
 #define kIOPMAssertInternalPreventSleep                     CFSTR("InternalPreventSleep")
 #define kIOPMAssertionTypeDisableInflow                     CFSTR("DisableInflow")
 #define kIOPMInflowDisableAssertion                         kIOPMAssertionTypeDisableInflow
 #define kIOPMAssertionTypeEnableIdleSleep                   CFSTR("EnableIdleSleep")
 //Audio & Graphics will sleep
 //Disk, Network & CPU will not sleep
 IOPMAssertionRelease(darkWakeAssertionID);
 IOReturn status = IOPMAssertionCreateWithName(kIOPMAssertionTypeDenySystemSleep, kIOPMAssertionLevelOn, kIOPMAssertionTypeDenySystemSleep, &darkWakeAssertionID);
 if (status == kIOReturnSuccess){
 HBLogDebug(@"SUCCESS");
 }else{
 HBLogDebug(@"FAILED");
 }
 }
 
 -(void)releaseDarkWakeState{
 IOPMAssertionRelease(darkWakeAssertionID);
 }
 
 -(void)updateDarkWake:(BOOL)preferDarkWake{
 if (preferDarkWake){
 [self preferDarkWakeState];
 }else{
 [self releaseDarkWakeState];
 }
 }
 */

/*
 -(NSDictionary *)assertionInfo{
 CFDictionaryRef assertionStates;
 IOReturn status = IOPMCopyAssertionsStatus(&assertionStates);
 NSDictionary *info = nil;
 if (status == kIOReturnSuccess){
 info = [(__bridge_transfer NSDictionary*)assertionStates copy];
 }
 if (assertionStates != NULL){
 CFRelease(assertionStates);
 }
 return info;
 }
 
 -(BOOL)chargingAssertionHeld{
 return [[self assertionInfo][@"ChargeInhibit"] boolValue];
 }
 
 -(void)releaseChargingAssertionIfHeld{
 if ([self chargingAssertionHeld]) [self enableCharging];
 }
 */

@end
