#import "CommonHeaders.h"

@interface BKGPAppEntryController : PSListController{
    NSMutableArray *_staticSpecifiers;
    NSMutableArray *_expandableSpecifiers;
	NSMutableArray *_cpuThrottleWarningSpecifiers;
    PSTextFieldSpecifier *_expirationSpecifier;
    PSTextFieldSpecifier *_timeSpanSpecifier;
	PSTextFieldSpecifier *_cpuThrottlePercentageSpecifier;
    PSSpecifier *_cpuControllerSpecifier;
    PSSpecifier *_systemCallsControllerSpecifier;
    PSSpecifier *_networkControllerSpecifier;
    PSSpecifier *_enabledEntrySpecifier;
	PSSpecifier *_cpuThrottleWarningGroupSpecifier;
    BOOL _isAdvanced;
    BOOL _expanded;
    BOOL _manuallyExpanded;
	BOOL _cpuThrottleWarningShown;
}
-(void)updateParentViewController;
@end


