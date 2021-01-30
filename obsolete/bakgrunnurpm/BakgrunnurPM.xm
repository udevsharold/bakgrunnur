#import "../common.h"
#import "BKGPowerManager.h"


%hookf(void, xpc_connection_set_event_handler, xpc_connection_t connection, xpc_handler_t handler){
    
    if (connection){
        xpc_handler_t originalHandler = handler;
        handler = ^(xpc_object_t event){
            if (event){
                if (xpc_get_type(event) != XPC_TYPE_ERROR && xpc_get_type(event) == XPC_TYPE_DICTIONARY){
                    xpc_object_t updateSleepingStateObject = xpc_dictionary_get_value(event, "BAKGRUNNUR_updateSleepingState");
                    //xpc_object_t taskEventsForBundleIdentifierObject = xpc_dictionary_get_value(event, "BAKGRUNNUR_taskEventsForPid");
                    
                    if (updateSleepingStateObject){
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[BKGPowerManager sharedInstance] handleUpdateSleepingStateMessage:event];
                        });
                        return;
                    }
                    /*
                    if (taskEventsForBundleIdentifierObject){
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[BKGPowerManager sharedInstance] handleTaskEventsForPid:event];
                        });
                    }
                    if (updateSleepingStateObject || taskEventsForBundleIdentifierObject){
                        return;
                    }
                    */
                }
            }
            if (originalHandler)
                originalHandler(event);
        };
    }
    %orig;
}
