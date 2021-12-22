#import <stdio.h>
#import <mach/mach.h>
#import "BKGDaemon.h"
#import <NSTask.h>

static IOPMAssertionID sleepingAssertionID;

@implementation BKGDaemon

+(void)load{
    [self sharedInstance];
}

+(id)sharedInstance{
    static dispatch_once_t once = 0;
    __strong static id sharedInstance = nil;
    dispatch_once(&once, ^{
        sharedInstance = [self new];
    });
    return sharedInstance;
}

-(id)init{
    if ((self = [super init])){
        //[self initXPCConnection];
    }
    return self;
}

/*
-(void)initXPCConnection{
    //self.queue = dispatch_queue_create("com.udevs.bkgd.queue", DISPATCH_QUEUE_CONCURRENT);
    self.xpc_listener = xpc_connection_create_mach_service("com.udevs.bkgd", dispatch_get_main_queue(), XPC_CONNECTION_MACH_SERVICE_LISTENER);
    xpc_connection_set_event_handler(self.xpc_listener, ^(xpc_object_t peer) {
        // Connection dispatch
        xpc_type_t peerType = xpc_get_type(peer);
        if (peerType != XPC_TYPE_ERROR){
            xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
                // Message dispatch
                if (xpc_get_type(event) == XPC_TYPE_DICTIONARY){
                    //Message handler
                    if (xpc_dictionary_get_value(event, "taskEventsForPid")){
                        [self handleTaskEventsForPid:event];
                    }
                    
                }
            });
            xpc_connection_resume(peer);
        }else{
            HBLogDebug(@"ERROR: %s", xpc_dictionary_get_string(peer, XPC_ERROR_KEY_DESCRIPTION));
        }
    });
    xpc_connection_resume(self.xpc_listener);
}
*/

-(void)replyWithBoolResult:(BOOL)value event:(xpc_object_t)event{
    xpc_connection_t remote = xpc_dictionary_get_remote_connection(event);
    xpc_object_t reply = xpc_dictionary_create_reply(event);
    xpc_dictionary_set_bool(reply, "result", value);
    xpc_connection_send_message(remote, reply);
}

-(void)replyWithObject:(xpc_object_t)object event:(xpc_object_t)event{
    xpc_connection_t remote = xpc_dictionary_get_remote_connection(event);
    xpc_object_t reply = xpc_dictionary_create_reply(event);
    xpc_dictionary_set_value(reply, "result", object);
    xpc_connection_send_message(remote, reply);
}

-(void)handleTaskEventsForPid:(xpc_object_t)event{
    xpc_object_t taskEventsObject = [self taskEventsForPid:xpc_dictionary_get_int64(event, "taskEventsForPid")];
    [self replyWithObject:taskEventsObject event:event];
}

-(void)handleCpuUsageForPid:(xpc_object_t)event{
    xpc_object_t cpuUsageObject = [self cpuUsageForPid:xpc_dictionary_get_int64(event, "cpuUsageForPid")];
    [self replyWithObject:cpuUsageObject event:event];
}

-(void)handleThreadsCountForPid:(xpc_object_t)event{
    xpc_object_t threadsCountObject = [self threadsCountForPid:xpc_dictionary_get_int64(event, "threadsCountForPid")];
    [self replyWithObject:threadsCountObject event:event];
}

-(void)handleUpdateSleepingState:(xpc_object_t)event{
    [self updateSleepingState:xpc_dictionary_get_bool(event, "updateSleepingState")];
    [self replyWithBoolResult:YES event:event];
}

-(void)handleNetstatForPids:(xpc_object_t)event{
    xpc_object_t pidsObject = xpc_dictionary_get_value(event, "netstatForPids");

    NSArray *pids = @[];
    if (xpc_get_type(pidsObject) == XPC_TYPE_ARRAY){
       pids = [self pidsArrayFromObject:pidsObject];
    }
    xpc_object_t statsObject = [self netstatForPids:pids];
    [self replyWithObject:statsObject event:event];
}

- (NSArray *)pidsArrayFromObject:(xpc_object_t)xpcObject{

    NSAssert(xpc_get_type(xpcObject) == XPC_TYPE_ARRAY, @"xpcObject must be of type XPC_TYPE_ARRAY.");
    
    NSUInteger capacity = xpc_array_get_count(xpcObject);
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:capacity];
    
    if (array) {
        xpc_array_apply(xpcObject, ^_Bool(size_t index, xpc_object_t value) {
            xpc_type_t valueType = xpc_get_type(value);

            if (valueType == XPC_TYPE_ARRAY) {
                NSArray *newArray = [self pidsArrayFromObject:value];
                [array addObject:newArray];
            }
            else if (valueType == XPC_TYPE_BOOL ||
                     valueType == XPC_TYPE_DOUBLE ||
                     valueType == XPC_TYPE_INT64 ||
                     valueType == XPC_TYPE_UINT64) {
                NSNumber *number = [self numberFromObject:value];
                [array addObject:number];
            }
            return YES;
        });
    }
    return array;
}

- (NSNumber *)numberFromObject:(xpc_object_t)xpcObject{
    xpc_type_t objectType = xpc_get_type(xpcObject);
    NSAssert((objectType == XPC_TYPE_BOOL ||
              objectType == XPC_TYPE_DOUBLE ||
              objectType == XPC_TYPE_INT64 ||
              objectType == XPC_TYPE_UINT64),
             @"xpcObject must be one of; bool, double, int64 or uint64.");
    
    NSNumber *newNumber = nil;
    if (objectType == XPC_TYPE_BOOL) {
        newNumber = @(xpc_bool_get_value(xpcObject));
    }
    else if (objectType == XPC_TYPE_DOUBLE) {
        newNumber = @(xpc_double_get_value(xpcObject));
    }
    else if (objectType == XPC_TYPE_INT64) {
        newNumber = @(xpc_int64_get_value(xpcObject));
    }
    else if (objectType == XPC_TYPE_UINT64) {
        newNumber = @(xpc_uint64_get_value(xpcObject));
    }
    
    return newNumber;
}

-(xpc_object_t)taskEventsForPid:(int)pid{
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;
    
    task_info_count = TASK_INFO_MAX;
    
    task_t task;
    task_for_pid(mach_task_self(), pid, &task);
    
    //mach calls
    kr = task_info(task, TASK_EVENTS_INFO, (task_info_t)tinfo, &task_info_count);
    xpc_object_t taskEventsInfoObject = xpc_dictionary_create(NULL, NULL, 0);

    if (kr != KERN_SUCCESS) {
        return taskEventsInfoObject;
    }
    task_events_info_t    events_info;
    events_info = (task_events_info_t)tinfo;
        
    xpc_dictionary_set_int64(taskEventsInfoObject, "syscalls_mach", events_info->syscalls_mach);
    xpc_dictionary_set_int64(taskEventsInfoObject, "syscalls_unix", events_info->syscalls_unix);
    xpc_dictionary_set_int64(taskEventsInfoObject, "syscalls_total", events_info->syscalls_mach + events_info->syscalls_unix);
    xpc_dictionary_set_int64(taskEventsInfoObject, "messages_sent", events_info->messages_sent);
    xpc_dictionary_set_int64(taskEventsInfoObject, "messages_received", events_info->messages_received);
    xpc_dictionary_set_int64(taskEventsInfoObject, "faults", events_info->faults);
    xpc_dictionary_set_int64(taskEventsInfoObject, "pageins", events_info->pageins);
    xpc_dictionary_set_int64(taskEventsInfoObject, "cow_faults", events_info->cow_faults);

    return taskEventsInfoObject;
}

-(xpc_object_t)cpuUsageForPid:(int)pid{
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;
    
    task_info_count = TASK_INFO_MAX;
    
    task_t task;
    task_for_pid(mach_task_self(), pid, &task);
    
    xpc_object_t taskEventsInfoObject = xpc_dictionary_create(NULL, NULL, 0);
    
    kr = task_info(task, TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        xpc_dictionary_set_double(taskEventsInfoObject, "cpu_usage", -1.0);
        return taskEventsInfoObject;
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
        xpc_dictionary_set_double(taskEventsInfoObject, "cpu_usage", -1.0);
        return taskEventsInfoObject;
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
            xpc_dictionary_set_double(taskEventsInfoObject, "cpu_usage", -1.0);
            return taskEventsInfoObject;
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
    
    xpc_dictionary_set_double(taskEventsInfoObject, "cpu_usage", tot_cpu);
    return taskEventsInfoObject;
}

-(xpc_object_t)threadsCountForPid:(int)pid{
    thread_array_t threadList;
    mach_msg_type_number_t threadCount;
    task_t task;
        
    kern_return_t kernReturn = task_for_pid(mach_task_self(), pid, &task);
    
    xpc_object_t taskEventsInfoObject = xpc_dictionary_create(NULL, NULL, 0);
    
    if (kernReturn != KERN_SUCCESS) {
        xpc_dictionary_set_int64(taskEventsInfoObject, "threads_count", -1.0);
        return taskEventsInfoObject;
    }
    
    kernReturn = task_threads(task, &threadList, &threadCount);
    if (kernReturn != KERN_SUCCESS) {
        xpc_dictionary_set_int64(taskEventsInfoObject, "threads_count", -1.0);
        return taskEventsInfoObject;
    }
    vm_deallocate (mach_task_self(), (vm_address_t)threadList, threadCount * sizeof(thread_act_t));
    
    xpc_dictionary_set_int64(taskEventsInfoObject, "threads_count", threadCount);

    return taskEventsInfoObject;
}

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

-(NSDictionary *)runCommand:(NSString *)cmd{
    if ([cmd length] != 0){
        NSMutableArray *taskArgs = [[NSMutableArray alloc] init];
        taskArgs = [NSMutableArray arrayWithObjects:@"-c", cmd, nil];
        NSTask * task = [[NSTask alloc] init];
        [task setLaunchPath:@"/bin/bash"];
        [task setArguments:taskArgs];
        NSPipe* outputPipe = [NSPipe pipe];
        task.standardOutput = outputPipe;
        
        NSMutableData *data = [NSMutableData data];
        
        NSFileHandle *stdoutHandle = [outputPipe fileHandleForReading];
        [stdoutHandle waitForDataInBackgroundAndNotify];
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleDataAvailableNotification object:stdoutHandle queue:nil usingBlock:^(NSNotification *note){
            // This block is called when output from the task is available.
            NSData *dataRead = [stdoutHandle availableData];
            if ([dataRead length] > 0){
                [data appendData:dataRead];
                [stdoutHandle waitForDataInBackgroundAndNotify];
            }
        }];
        
        [task launch];
        //NSData *data = [[outputPipe fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];
        NSDictionary *result = @{@"exitCode":@([task terminationStatus]), @"stdout":data?:[@"" dataUsingEncoding:NSUTF8StringEncoding]};
        if (observer) [[NSNotificationCenter defaultCenter] removeObserver:observer];
        return result;
    }
    return @{@"exitCode":@0, @"stdout":[@"" dataUsingEncoding:NSUTF8StringEncoding]};
}

-(xpc_object_t)netstatForPids:(NSArray *)pids{
    
    NSDictionary *result = [self runCommand:@"netstat -bvn -p tcp"];
    NSString *stdouString = [[NSString alloc] initWithData:result[@"stdout"] encoding:NSUTF8StringEncoding];
    
    __block xpc_object_t connections = xpc_dictionary_create(NULL, NULL, 0);
    //__block NSMutableArray *connections = [@[] mutableCopy];
    __block NSMutableArray *keys = [@[] mutableCopy];
    __block int lineIdx = 0;
    __block BOOL exitDueToParsingError = NO;
    [stdouString enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        if (lineIdx > 1){
            
            NSArray *connection = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            connection = [connection filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != ''"]];
            
            if ([keys count] != [connection count] || [keys indexOfObject:@"pid"] == NSNotFound){
                exitDueToParsingError = YES;
                *stop = YES;
                return;
            }
            
            NSNumberFormatter *numberFormatter = [NSNumberFormatter new];
            NSNumber *pid = [numberFormatter numberFromString:connection[[keys indexOfObject:@"pid"]]];
            
            if ([pids containsObject:pid]){
                xpc_object_t formattedConnection = xpc_dictionary_create(NULL, NULL, 0);
                //NSMutableDictionary *formattedConnection  = [@{} mutableCopy];
                //for (int i = 0; i < [keys count]; i++){
                //formattedConnection[keys[i]] = connection[i];
                xpc_object_t activeConnectionsObject = xpc_array_create(NULL, 0);

                xpc_object_t prevActiveConnectionObject = xpc_dictionary_get_value(connections, [connection[[keys indexOfObject:@"pid"]] UTF8String]);
                if (prevActiveConnectionObject){
                    activeConnectionsObject = prevActiveConnectionObject;
                }
                
                if ([keys indexOfObject:@"rxbytes"] != NSNotFound){
                    xpc_dictionary_set_uint64(formattedConnection, "rxbytes", [[numberFormatter numberFromString:connection[[keys indexOfObject:@"rxbytes"]]] unsignedLongLongValue]);
                }
                if ([keys indexOfObject:@"txbytes"] != NSNotFound){
                    xpc_dictionary_set_uint64(formattedConnection, "txbytes", [[numberFormatter numberFromString:connection[[keys indexOfObject:@"txbytes"]]] unsignedLongLongValue]);
                }
                if ([keys indexOfObject:@"rhiwat"] != NSNotFound){
                    xpc_dictionary_set_uint64(formattedConnection, "rhiwat", [[numberFormatter numberFromString:connection[[keys indexOfObject:@"rhiwat"]]] unsignedLongLongValue]);
                }
                if ([keys indexOfObject:@"shiwat"] != NSNotFound){
                    xpc_dictionary_set_uint64(formattedConnection, "shiwat", [[numberFormatter numberFromString:connection[[keys indexOfObject:@"shiwat"]]] unsignedLongLongValue]);
                }
                if ([keys indexOfObject:@"Send-Q"] != NSNotFound){
                    xpc_dictionary_set_uint64(formattedConnection, "send_q", [[numberFormatter numberFromString:connection[[keys indexOfObject:@"Send-Q"]]] unsignedLongLongValue]);
                }
                if ([keys indexOfObject:@"Recv-Q"] != NSNotFound){
                    xpc_dictionary_set_uint64(formattedConnection, "recv_q", [[numberFormatter numberFromString:connection[[keys indexOfObject:@"Recv-Q"]]] unsignedLongLongValue]);
                }
                if ([keys indexOfObject:@"epid"] != NSNotFound){
                    xpc_dictionary_set_uint64(formattedConnection, "epid", [[numberFormatter numberFromString:connection[[keys indexOfObject:@"epid"]]] unsignedLongLongValue]);
                }
                if ([keys indexOfObject:@"Proto"] != NSNotFound){
                    xpc_dictionary_set_string(formattedConnection, "proto", [connection[[keys indexOfObject:@"Proto"]] UTF8String]);
                }
                if ([keys indexOfObject:@"Foreign-Address"] != NSNotFound){
                    xpc_dictionary_set_string(formattedConnection, "foreign_addr", [connection[[keys indexOfObject:@"Foreign-Address"]] UTF8String]);
                }
                if ([keys indexOfObject:@"Local-Address"] != NSNotFound){
                    xpc_dictionary_set_string(formattedConnection, "local_addr", [connection[[keys indexOfObject:@"Local-Address"]] UTF8String]);
                }
                if ([keys indexOfObject:@"(state)"] != NSNotFound){
                    xpc_dictionary_set_string(formattedConnection, "state", [connection[[keys indexOfObject:@"(state)"]] UTF8String]);
                }
                
                xpc_array_set_value(activeConnectionsObject, ((size_t)(-1)), formattedConnection);
                
                if ([keys indexOfObject:@"pid"] != NSNotFound){
                xpc_dictionary_set_value(connections, [connection[[keys indexOfObject:@"pid"]] UTF8String], activeConnectionsObject);
                }
                //}
                //[connections addObject:formattedConnection];
            }
            
        }else if (lineIdx == 1){
            line = [line stringByReplacingOccurrencesOfString:@"Local Address" withString:@"Local-Address"];
            line = [line stringByReplacingOccurrencesOfString:@"Foreign Address" withString:@"Foreign-Address"];
            keys = [[line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] mutableCopy];
            keys = [[keys filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != ''"]] mutableCopy];
        }
        lineIdx++;
    }];
    
    if (exitDueToParsingError){
        return connections;
    }
    //HBLogDebug(@"connections: %@", xpc_dictionary_get_value(connections, [[[pids firstObject] stringValue] UTF8String]));

    return connections;
}

@end

