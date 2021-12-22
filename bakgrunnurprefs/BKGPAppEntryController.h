#import "CommonHeaders.h"

@interface BKGPAppEntryController : PSListController{
    NSMutableArray *_staticSpecifiers;
    NSMutableArray *_expandableSpecifiers;
    PSTextFieldSpecifier *_expirationSpecifier;
    PSTextFieldSpecifier *_timeSpanSpecifier;
    PSSpecifier *_cpuControllerSpecifier;
    PSSpecifier *_systemCallsControllerSpecifier;
    PSSpecifier *_networkControllerSpecifier;
    PSSpecifier *_enabledEntrySpecifier;
    BOOL _isAdvanced;
    BOOL _expanded;
    BOOL _manuallyExpanded;
}
-(void)updateParentViewController;
@end


