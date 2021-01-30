#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface BakgrunnurRootListController : PSListController
@property(nonatomic, retain) UIBarButtonItem *respringBtn;
@end

@interface PSSpecifier (BakgrunnurRootListController)
-(void)setValues:(id)arg1 titles:(id)arg2;
- (void)setKeyboardType:(UIKeyboardType)type autoCaps:(UITextAutocapitalizationType)autoCaps autoCorrection:(UITextAutocorrectionType)autoCorrection;
@end
