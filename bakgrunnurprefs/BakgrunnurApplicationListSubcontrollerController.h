//  Copyright (c) 2021 udevs
//
//  This file is subject to the terms and conditions defined in
//  file 'LICENSE', which is part of this source code package.

#import "../common.h"
#import <AltList/ATLApplicationListSubcontrollerController.h>

@interface BakgrunnurApplicationListSubcontrollerController : ATLApplicationListSubcontrollerController{
    NSMutableDictionary *_prefs;
    NSArray *_allEntriesIdentifier;
}
-(void)updateIvars;
@end
