#import <RocketBootstrap/rocketbootstrap.h>

@interface BakgrunnurServer : NSObject{
    CPDistributedMessagingCenter * _messagingCenter;
}
+ (instancetype)sharedInstance;
-(NSDictionary *)terminateProcess:(NSString *)name withUserInfo:(NSDictionary *)userInfo;
@end

