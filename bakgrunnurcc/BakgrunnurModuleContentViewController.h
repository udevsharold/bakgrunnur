#import <ControlCenterUIKit/CCUIButtonModuleViewController.h>
#import <ControlCenterUIKit/CCUIMenuModuleViewController.h>


@class BakgrunnurCC;

@interface BakgrunnurModuleContentViewController : CCUIMenuModuleViewController
@property (nonatomic, weak) BakgrunnurCC* module;
@property (nonatomic, assign) BOOL rejectTap;
@property (nonatomic, assign) BOOL lastSelected;
@end
