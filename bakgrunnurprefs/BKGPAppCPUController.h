#import "CommonHeaders.h"

@interface BKGPAppCPUController : PSListController
@property (nonatomic,retain) PSSpecifier *cpuUsageSelectionSpecifier;
@property (nonatomic,retain) PSTextFieldSpecifier *cpuUsageSpecifier;
@property (nonatomic,retain) NSString *identifier;
@property (nonatomic,retain) NSString *appName;
@end


