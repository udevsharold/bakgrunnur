//  Copyright (c) 2021 udevs
//
//  This file is subject to the terms and conditions defined in
//  file 'LICENSE', which is part of this source code package.

#import "BakgrunnurApplicationListSubcontrollerController.h"
#import "../BKGShared.h"

@implementation BakgrunnurApplicationListSubcontrollerController

-(NSArray *)getAllEntries:(NSString *)keyName keyIdentifier:(NSString *)keyIdentifier{
    NSArray *arrayWithEventID = [_prefs[keyName] valueForKey:keyIdentifier];
    return arrayWithEventID;
}

-(void)updateIvars{
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", BAKGRUNNUR_IDENTIFIER];
    _prefs = [NSMutableDictionary dictionary];
    [_prefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    _allEntriesIdentifier = [self getAllEntries:@"enabledIdentifier" keyIdentifier:@"identifier"];
}

- (void)loadPreferences{
    [self updateIvars];
    [super loadPreferences];
}

- (NSString*)previewStringForApplicationWithIdentifier:(NSString *)applicationID{
    return [self previewForApplication:applicationID];
}

- (NSString*)subtitleForApplicationWithIdentifier:(NSString*)applicationID{
    return [self subtitleForApplication:applicationID];
}

-(NSString *)formattedExpiration:(double)seconds{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    
    if (seconds < 60){
        formatter.numberStyle = NSNumberFormatterNoStyle;
        return [NSString stringWithFormat:@"%@ %@", [formatter stringFromNumber:@(seconds)], seconds > 1 ? @"secs" : @"sec"];
    }else if (seconds < 3600){
        formatter.numberStyle = NSNumberFormatterNoStyle;
        return [NSString stringWithFormat:@"%@ %@", [formatter stringFromNumber:@(seconds/60.0)], seconds/60.0 > 1 ? @"mins" : @"min"];
    }else if (fmod(seconds, 60.0) > 0){
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.maximumFractionDigits = 1;
        formatter.roundingMode = NSNumberFormatterRoundUp;
        return [NSString stringWithFormat:@"%@ %@", [formatter stringFromNumber:@(seconds/3600.0)], seconds/3600.0 > 1 ? @"hours" : @"hour"];
    }else{
        formatter.numberStyle = NSNumberFormatterNoStyle;
        return [NSString stringWithFormat:@"%@ %@", [formatter stringFromNumber:@(seconds/3600.0)], seconds/3600.0 > 1 ? @"hours" : @"hour"];
    }
}

- (NSString *)subtitleForApplication:(NSString *)appID{
    NSUInteger identifierIdx = [_allEntriesIdentifier indexOfObject:appID];
    
    BOOL enabled = boolValueForConfigKeyWithPrefsAndIndex(@"enabled", NO, _prefs, identifierIdx);
    if (!enabled) return @"";
    
    double expiration = doubleValueForConfigKeyWithPrefsAndIndex(@"expiration", defaultExpirationTime, _prefs, identifierIdx);
    
    BKGBackgroundType backgroundType = unsignedLongValueForConfigKeyWithPrefsAndIndex(@"retire", BKGBackgroundTypeRetire, _prefs, identifierIdx);
    
    NSString *verboseText = @"";
    NSMutableArray *verboseArray = [NSMutableArray array];
    
    switch (backgroundType) {
        case BKGBackgroundTypeTerminate:{
            [verboseArray addObject:[self formattedExpiration:expiration]];
            break;
        }
        case BKGBackgroundTypeRetire:{
            [verboseArray addObject:[self formattedExpiration:expiration]];
            break;
        }
        case BKGBackgroundTypeImmortal:{
            break;
        }
        case BKGBackgroundTypeAdvanced:{
            BOOL cpuUsageEnabled = boolValueForConfigKeyWithPrefsAndIndex(@"cpuUsageEnabled", NO, _prefs, identifierIdx);
            if (cpuUsageEnabled){
                [verboseArray addObject:@"CPU"];
            }
            
            int systemCallsType = intValueForConfigKeyWithPrefsAndIndex(@"systemCallsType", 0, _prefs, identifierIdx);
            if (systemCallsType > 0){
                [verboseArray addObject:@"System"];
            }
            
            int networkTransmissionType = intValueForConfigKeyWithPrefsAndIndex(@"networkTransmissionType", 0, _prefs, identifierIdx);
            if (networkTransmissionType > 0){
                [verboseArray addObject:@"Network"];
            }
            break;
        }
        default:
            return @"";
    }
    
    BOOL darkWake = boolValueForConfigKeyWithPrefsAndIndex(@"darkWake", NO, _prefs, identifierIdx);
    if (darkWake){
        [verboseArray addObject:@"Wake"];
    }
    
    if (verboseArray.count > 0){
        verboseText = [verboseArray componentsJoinedByString:@" | "];
    }
    return verboseText;
    
}
- (NSString *)previewForApplication:(NSString *)appID{
    NSUInteger identifierIdx = [_allEntriesIdentifier indexOfObject:appID];
    
    BOOL enabled = boolValueForConfigKeyWithPrefsAndIndex(@"enabled", NO, _prefs, identifierIdx);
    if (!enabled) return @"";
    
    BKGBackgroundType backgroundType = unsignedLongValueForConfigKeyWithPrefsAndIndex(@"retire", BKGBackgroundTypeRetire, _prefs, identifierIdx);
    
    switch (backgroundType) {
        case BKGBackgroundTypeTerminate:{
            return @"Terminate";
        }
        case BKGBackgroundTypeRetire:{
            return @"Retire";
        }
        case BKGBackgroundTypeImmortal:{
            return @"Immortal";
        }
        case BKGBackgroundTypeAdvanced:{
            return @"Advanced";
        }
        default:
            return @"";
    }
}
@end
