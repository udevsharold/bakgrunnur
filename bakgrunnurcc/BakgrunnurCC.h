#import <ControlCenterUIKit/CCUIToggleModule.h>
#import <ControlCenterUI/CCUIModuleInstance.h>
#import <ControlCenterUI/CCUIModuleInstanceManager.h>
#import "BakgrunnurModuleContentViewController.h"

@interface CCUIModuleInstanceManager (CCSupport)
- (CCUIModuleInstance*)instanceForModuleIdentifier:(NSString*)moduleIdentifier;
@end

@interface BakgrunnurCC : CCUIToggleModule
{
    BOOL _selected;
    BakgrunnurModuleContentViewController* _contentViewController;
}
-(void)updateState;
-(void)updateStateViaPreferences;
-(NSMutableDictionary *)getPrefs;
@end
