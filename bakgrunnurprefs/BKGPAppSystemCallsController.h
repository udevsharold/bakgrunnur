#import "CommonHeaders.h"

@interface BKGPAppSystemCallsController : PSListController
@property (nonatomic,retain) PSSpecifier *systemCallsSelectionSpecifier;
@property (nonatomic,retain) PSTextFieldSpecifier *systemCallsSpecifier;
@property (nonatomic,retain) NSString *identifier;
@property (nonatomic,retain) NSString *appName;
@end


