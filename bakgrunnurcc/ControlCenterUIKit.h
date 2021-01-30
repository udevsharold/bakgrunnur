#if defined __cplusplus
extern "C" {
#endif

CGFloat CCUISliderExpandedContentModuleHeight();
CGFloat CCUISliderExpandedContentModuleWidth();

CGFloat CCUIExpandedModuleContinuousCornerRadius();
CGFloat CCUICompactModuleContinuousCornerRadius();

CGFloat CCUIDefaultExpandedContentModuleWidth();

CGFloat CCUIMaximumExpandedContentModuleHeight();

#if defined __cplusplus
};
#endif

@interface CCUIMenuModuleItem : NSObject
@property (nonatomic,copy) NSString * identifier;
@property (nonatomic,copy) NSString * title;
@property (nonatomic,copy) id handler;
@property (assign,getter=isPlaceholder,nonatomic) BOOL placeholder;
@property (nonatomic,copy) NSString * subtitle;
@property (assign,getter=isBusy,nonatomic) BOOL busy;
@property (assign,getter=isSelected,nonatomic) BOOL selected;
-(id)initWithTitle:(id)arg1 identifier:(id)arg2 handler:(id)arg3 ;
@end

/*
@interface CCUIButtonModuleViewController : UIViewController
@property (nonatomic,retain) UIImage * glyphImage;
@property (nonatomic,retain) UIColor * glyphColor;
@property (nonatomic,retain) UIImage * selectedGlyphImage;
@property (nonatomic,retain) UIColor * selectedGlyphColor;
@property (nonatomic,retain) CCUICAPackageDescription * glyphPackageDescription;
@property (nonatomic,copy) NSString * glyphState;
@property (assign,nonatomic) double glyphScale;
@property (assign,getter=isSelected,nonatomic) BOOL selected;
@property (assign,getter=isExpanded,nonatomic) BOOL expanded;
@property (nonatomic,readonly) CCUIButtonModuleView * buttonView;
@property (nonatomic,readonly) BOOL hasGlyph;
@property (nonatomic,readonly) double preferredExpandedContentHeight;
@property (nonatomic,readonly) double preferredExpandedContentWidth;
@property (nonatomic,readonly) double preferredExpandedContinuousCornerRadius;
@property (nonatomic,readonly) BOOL providesOwnPlatter;
@property (nonatomic,readonly) UIViewPropertyAnimator * customAnimator;
@property (nonatomic,readonly) BOOL shouldPerformHoverInteraction;
@end
*/

@interface CCUIMenuModuleViewController (Private)
@property (nonatomic,copy) NSString * title;
@property (nonatomic,readonly) unsigned long long actionsCount;
@property (nonatomic,readonly) unsigned long long menuItemCount;
@property (nonatomic,readonly) double headerHeight;
@property (nonatomic,readonly) UIView * contentView;
@property (nonatomic,readonly) BOOL hasFooterButton;
@property (assign,nonatomic) unsigned long long minimumMenuItems;
@property (assign,nonatomic) double visibleMenuItems;
@property (assign,nonatomic) unsigned long long indentation;
@property (assign,getter=isBusy,nonatomic) BOOL busy;
@property (assign,nonatomic) BOOL shouldProvideOwnPlatter;
@property (assign,nonatomic) BOOL useTrailingCheckmarkLayout;
@property (assign,nonatomic) BOOL useTrailingInset;
@property (assign,nonatomic) BOOL useTallLayout;
//@property (assign,nonatomic) CCUIContentModuleContext * contentModuleContext;
@property (nonatomic,readonly) double preferredExpandedContentHeight;
@property (nonatomic,readonly) double preferredExpandedContentWidth;
@property (nonatomic,readonly) double preferredExpandedContinuousCornerRadius;
@property (nonatomic,readonly) BOOL providesOwnPlatter;
//@property (nonatomic,readonly) UIViewPropertyAnimator * customAnimator;
@property (nonatomic,readonly) BOOL shouldPerformHoverInteraction;
-(void)setMenuItems:(id)arg1 ;
-(void)setGlyphImage:(id)arg1 ;
-(void)addActionWithTitle:(id)arg1 subtitle:(id)arg2 glyph:(id)arg3 handler:(/*^block*/id)arg4 ;
-(void)addActionWithTitle:(id)arg1 glyph:(id)arg2 handler:(/*^block*/id)arg3;
-(void)setFooterButtonTitle:(id)arg1 handler:(/*^block*/id)arg2 ;
@end

