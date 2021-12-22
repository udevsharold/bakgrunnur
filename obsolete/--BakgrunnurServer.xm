#import "common.h"
#import "BakgrunnurServer.h"
#import "Bakgrunnur.h"

@implementation BakgrunnurServer
+ (void)load {
    @autoreleasepool {
        NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
        
        if (args.count != 0) {
            NSString *executablePath = args[0];
            
            if (executablePath) {
                NSString *processName = [executablePath lastPathComponent];
                
                BOOL isSpringBoard = [processName isEqualToString:@"SpringBoard"];
                
                if (isSpringBoard) {
                    [self sharedInstance];
                    HBLogDebug(@"BakgrunnurServer");
                }
            }
        }
    }
}

+ (instancetype)sharedInstance {
    static dispatch_once_t once = 0;
    __strong static id sharedInstance = nil;
    dispatch_once(&once, ^{
        sharedInstance = [self new];
    });
    return sharedInstance;
}

- (instancetype)init {
    if ((self = [super init])) {
        
        _messagingCenter = [CPDistributedMessagingCenter centerNamed:kIPCCenterName];
        rocketbootstrap_distributedmessagingcenter_apply(_messagingCenter);

        [_messagingCenter runServerOnCurrentThread];
        [_messagingCenter registerForMessageName:@"isUILocked" target:self selector:@selector(isUILocked:withUserInfo:)];
        HBLogDebug(@"BakgrunnurServer - INIT");

    }

    return self;
}

-(NSDictionary *)isUILocked:(NSString *)name withUserInfo:(NSDictionary *)userInfo{
    HBLogDebug(@"Received isUILocked");
    return @{@"value":@([[%c(SBLockScreenManager) sharedInstance] isUILocked])};
    //return @{@"value":@([[%c(SBLockStateAggregator) sharedInstance] lockState] == 3 ? YES : NO)};

}
@end
