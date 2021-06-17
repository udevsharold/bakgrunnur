#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface PSSpecifier (BakgrunnurAppEntryController)
-(void)setValues:(id)arg1 titles:(id)arg2;
- (void)setKeyboardType:(UIKeyboardType)type autoCaps:(UITextAutocapitalizationType)autoCaps autoCorrection:(UITextAutocorrectionType)autoCorrection;
@end


@interface PSTextFieldSpecifier : PSSpecifier {

    SEL bestGuess;
    NSString* _placeholder;

}
+(id)preferenceSpecifierNamed:(id)arg1 target:(id)arg2 set:(SEL)arg3 get:(SEL)arg4 detail:(Class)arg5 cell:(long long)arg6 edit:(Class)arg7 ;
+(id)specifierWithSpecifier:(id)arg1 ;
-(void)setPlaceholder:(id)arg1 ;
-(id)placeholder;
-(BOOL)isEqualToSpecifier:(id)arg1 ;
@end

@interface BakgrunnurAppEntryController : PSListController{
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


