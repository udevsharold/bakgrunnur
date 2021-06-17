#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface BakgrunnurAppCPUController : PSListController
@property (nonatomic,retain) PSSpecifier *cpuUsageSelectionSpecifier;
@property (nonatomic,retain) PSTextFieldSpecifier *cpuUsageSpecifier;
@property (nonatomic,retain) NSString *identifier;
@property (nonatomic,retain) NSString *appName;
@end


