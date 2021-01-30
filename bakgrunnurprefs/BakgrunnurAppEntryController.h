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

@interface BakgrunnurAppEntryController : PSListController
@property (nonatomic,retain) PSTextFieldSpecifier *expirationSpecifier;
//@property (nonatomic,retain) PSSpecifier *cpuUsageSelectionSpecifier;
//@property (nonatomic,retain) PSTextFieldSpecifier *cpuUsageSpecifier;
@property (nonatomic,retain) PSTextFieldSpecifier *timeSpanSpecSpecifier;
//@property (nonatomic,retain) PSSpecifier *systemCallsSelectionSpecifier;
//@property (nonatomic,retain) PSTextFieldSpecifier *systemCallsSpecifier;
@property (nonatomic,assign) BOOL isAdvanced;
@property (nonatomic,retain) PSSpecifier *cpuControllerSpecifier;
@property (nonatomic,retain) PSSpecifier *systemCallsControllerSpecifier;
@property (nonatomic,retain) PSSpecifier *networkControllerSpecifier;
@end


