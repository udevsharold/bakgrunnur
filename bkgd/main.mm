#import "../common.h"
#import <stdio.h>
#import <mach/mach.h>
#import "BKGDaemon.h"

static void handleXPCObject(xpc_object_t object) {
    BKGDaemon *daemon = [BKGDaemon sharedInstance];
    if (xpc_dictionary_get_value(object, "taskEventsForPid")){
        [daemon handleTaskEventsForPid:object];
    }else if (xpc_dictionary_get_value(object, "cpuUsageForPid")){
        [daemon handleCpuUsageForPid:object];
    }else if (xpc_dictionary_get_value(object, "threadsCountForPid")){
        [daemon handleThreadsCountForPid:object];
    }else if (xpc_dictionary_get_value(object, "updateSleepingState")){
        [daemon handleUpdateSleepingState:object];
    }else if (xpc_dictionary_get_value(object, "netstatForPids")){
        [daemon handleNetstatForPids:object];
    }
}

static void bkgd_peer_event_handler(xpc_connection_t peer, xpc_object_t event){
    xpc_type_t type = xpc_get_type(event);
    if (type == XPC_TYPE_ERROR) {
        if (event == XPC_ERROR_CONNECTION_INVALID) {
            // The client process on the other end of the connection has either
            // crashed or cancelled the connection. After receiving this error,
            // the connection is in an invalid state, and you do not need to
            // call xpc_connection_cancel(). Just tear down any associated state
            // here.
        } else if (event == XPC_ERROR_TERMINATION_IMMINENT) {
            // Handle per-connection termination cleanup.
        }
    } else {
        assert(type == XPC_TYPE_DICTIONARY);
        handleXPCObject(event);
    }
}

static void bkgd_event_handler(xpc_connection_t peer){
    // By defaults, new connections will target the default dispatch concurrent queue.
    xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
        bkgd_peer_event_handler(peer, event);
    });
    
    // This will tell the connection to begin listening for events. If you
    // have some other initialization that must be done asynchronously, then
    // you can defer this call until after that initialization is done.
    xpc_connection_resume(peer);
}

int main(int argc, char *argv[], char *envp[]) {
    
    [BKGDaemon load];
    
    xpc_connection_t service = xpc_connection_create_mach_service("com.udevs.bkgd", dispatch_get_main_queue(), XPC_CONNECTION_MACH_SERVICE_LISTENER);
    
    if (!service) {
        HBLogDebug(@"ERROR: Failed to create service.");
        exit(EXIT_FAILURE);
    }
    
    xpc_connection_set_event_handler(service, ^(xpc_object_t connection) {
        bkgd_event_handler(connection);
    });
    
    xpc_connection_resume(service);
    dispatch_main();
    
    //In case daemon got killed, reload prefs (update sleeping state)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
    });

    return EXIT_SUCCESS;
}
