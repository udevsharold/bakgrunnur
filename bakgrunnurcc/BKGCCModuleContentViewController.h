#import <ControlCenterUIKit/CCUIButtonModuleViewController.h>
#import <ControlCenterUIKit/CCUIMenuModuleViewController.h>


@class BKGCCToggleModule;

@interface BKGCCModuleContentViewController : CCUIMenuModuleViewController
@property (nonatomic, weak) BKGCCToggleModule* module;
@property (nonatomic, assign) BOOL rejectTap;
@property (nonatomic, assign) BOOL lastSelected;
@end
