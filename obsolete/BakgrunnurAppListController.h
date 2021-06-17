#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface PSTableCell (BakgrunnurAppListController)
-(id)title;
-(void)setTitle:(id)arg1 ;
@end

@interface PSSpecifier (BakgrunnurAppListController)
-(void)setValues:(id)arg1 titles:(id)arg2;
- (void)setKeyboardType:(UIKeyboardType)type autoCaps:(UITextAutocapitalizationType)autoCaps autoCorrection:(UITextAutocorrectionType)autoCorrection;
@end

@interface UIButton (BakgrunnurAppListController)
-(void)setTitle:(id)arg1 ;
@end

@interface BakgrunnurAppListController : PSListController  <UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, UISearchBarDelegate>

@end

