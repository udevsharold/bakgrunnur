#import "../common.h"
#import <AltList/ATLApplicationListSubcontrollerController.h>

@interface BKGPApplicationListSubcontrollerController : ATLApplicationListSubcontrollerController{
    NSMutableDictionary *_prefs;
    NSArray *_allEntriesIdentifier;
}
-(void)updateIvars;
@end
