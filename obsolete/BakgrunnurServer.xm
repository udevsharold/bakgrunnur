#import "common.h"
#import "SpringBoard.h"
#import "BakgrunnurServer.h"

%group RunningBoardProcess
@implementation BakgrunnurServer
+ (void)load {
    [self sharedInstance];
}

+ (instancetype)sharedInstance {
    static dispatch_once_t once = 0;
    __strong static id sharedInstance = nil;
    dispatch_once(&once, ^{
        sharedInstance = [self new];
    });
    return sharedInstance;
}

- (instancetype)init{
    if ((self = [super init])) {
        _messagingCenter = [CPDistributedMessagingCenter centerNamed:kIPCCenterName];
        rocketbootstrap_distributedmessagingcenter_apply(_messagingCenter);
        
        [_messagingCenter runServerOnCurrentThread];
        [_messagingCenter registerForMessageName:@"terminateProcess" target:self selector:@selector(terminateProcess:withUserInfo:)];
    }
    return self;
}

-(NSDictionary *)terminateProcess:(NSString *)name withUserInfo:(NSDictionary *)userInfo{
    HBLogDebug(@"Terminating %@", userInfo[@"identifier"]);
    RBDaemon *daemon = [%c(RBDaemon) _sharedInstance];
    NSMutableOrderedSet *processes = [[[daemon valueForKey:@"_processManager"] valueForKey:@"_processIndex"] valueForKey:@"_processes"];
    [processes enumerateObjectsUsingBlock:^(RBProcess *proc, NSUInteger idx, BOOL *stop) {
        if ([userInfo[@"identifier"] isEqualToString:proc.identity.embeddedApplicationIdentifier]) {
            [proc terminateWithContext:nil];
            HBLogDebug(@"Terminated %@", proc.identity.embeddedApplicationIdentifier);
            *stop = YES;
        }
    }];
    return @{};
}

@end
%end

%ctor{
    @autoreleasepool {
        NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
        
        if (args.count != 0) {
            NSString *executablePath = args[0];
            
            if (executablePath) {
                NSString *processName = [executablePath lastPathComponent];
                
                BOOL isRunningBoard = [processName isEqualToString:@"runningboardd"];
                
                if (isRunningBoard){
                    %init(RunningBoardProcess);
                }
            }
        }
    }
}
