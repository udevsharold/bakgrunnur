#import <ControlCenterUIKit/CCUIToggleModule.h>
#import <ControlCenterUI/CCUIModuleInstance.h>
#import <ControlCenterUI/CCUIModuleInstanceManager.h>
#import "BKGCCModuleContentViewController.h"

@interface CCUIModuleInstanceManager (CCSupport)
- (CCUIModuleInstance*)instanceForModuleIdentifier:(NSString*)moduleIdentifier;
@end

@interface BKGCCToggleModule : CCUIToggleModule{
    BOOL _selected;
	BOOL _shouldSetValue;
	BKGCCModuleContentViewController* _contentViewController;
}
-(void)updateState;
-(void)updateStateViaPreferences;
@end
