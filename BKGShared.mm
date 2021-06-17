#import "common.h"
#import "BKGShared.h"

NSDictionary* getPrefs(){
    NSMutableDictionary *prefs = [NSMutableDictionary dictionary];
    [prefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:PREFS_PATH]];
    return [prefs copy];
}

id valueForKey(NSString *key, id defaultValue){
    NSMutableDictionary *prefs = [NSMutableDictionary dictionary];
    [prefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:PREFS_PATH]];
    return prefs[key] ?: defaultValue;
}

id valueForKeyWithPrefs(NSString *key, NSDictionary *prefs){
    if (!prefs){
        return (valueForKey(key, nil));
    }
    return prefs[key] ?: nil;
}

BOOL boolValueForKeyWithPrefs(NSString *key, BOOL defaultValue, NSDictionary *prefs){
    id value = valueForKeyWithPrefs(key, prefs);
    return value ? [value boolValue] : defaultValue;
}

BOOL boolValueForKey(NSString *key, BOOL defaultValue){
    return boolValueForKeyWithPrefs(key, defaultValue, nil);
}

unsigned long unsignedLongValueForKeyWithPrefs(NSString *key, unsigned long defaultValue, NSDictionary *prefs){
    id value = valueForKeyWithPrefs(key, prefs);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value unsignedLongValue] : defaultValue;
}

unsigned long unsignedLongValueForKey(NSString *key, unsigned long defaultValue){
    return unsignedLongValueForKeyWithPrefs(key, defaultValue, nil);
}

unsigned long long unsignedLongLongValueForKeyWithPrefs(NSString *key, unsigned long long defaultValue, NSDictionary *prefs){
    id value = valueForKeyWithPrefs(key, prefs);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value unsignedLongLongValue] : defaultValue;
}

unsigned long long unsignedLongLongValueForKey(NSString *key, unsigned long long defaultValue){
    return unsignedLongLongValueForKeyWithPrefs(key, defaultValue, nil);
}

long long longLongValueForKeyWithPrefs(NSString *key, long long defaultValue, NSDictionary *prefs){
    id value = valueForKeyWithPrefs(key, prefs);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value longLongValue] : defaultValue;
}

long long longLongValueForKey(NSString *key, long long defaultValue){
    return longLongValueForKeyWithPrefs(key, defaultValue, nil);
}

int intValueForKeyWithPrefs(NSString *key, int defaultValue, NSDictionary *prefs){
    id value = valueForKeyWithPrefs(key, prefs);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value intValue] : defaultValue;
}

int intValueForKey(NSString *key, int defaultValue){
    return intValueForKeyWithPrefs(key, defaultValue, nil);
}

double doubleValueForKeyWithPrefs(NSString *key, double defaultValue, NSDictionary *prefs){
    id value = valueForKeyWithPrefs(key, prefs);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value doubleValue] : defaultValue;
}

double doubleValueForKey(NSString *key, double defaultValue){
    return doubleValueForKeyWithPrefs(key, defaultValue, nil);
}

float floatValueForKeyWithPrefs(NSString *key, float defaultValue, NSDictionary *prefs){
    id value = valueForKeyWithPrefs(key, prefs);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value floatValue] : defaultValue;
}

float floatValueForKey(NSString *key, float defaultValue){
    return floatValueForKeyWithPrefs(key, defaultValue, nil);
}

void setValueForKeyWithPrefs(NSString *key, id value, NSDictionary *prefs){
    NSMutableDictionary *newPrefs;
    
    if (!prefs){
        newPrefs = [NSMutableDictionary dictionary];
        [newPrefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:PREFS_PATH]];
    }else{
        newPrefs = [prefs mutableCopy];
    }
    
    [newPrefs setObject:value forKey:key];
    [newPrefs writeToFile:PREFS_PATH atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
}

void setValueForKey(NSString *key, id value){
    setValueForKeyWithPrefs(key, value, nil);
}

id valueForConfigKeyWithPrefs(NSString *identifier, NSString *key, id defaultValue, NSDictionary *prefs){
    id configs;
    if (!prefs){
        configs = valueForKey(@"enabledIdentifier", nil);
    }else{
        configs = prefs[@"enabledIdentifier"];
    }
    if (configs){
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @"identifier", identifier];
        NSDictionary *config = [configs filteredArrayUsingPredicate:predicate].firstObject;
        return config[key] ?: defaultValue;
    }
    return defaultValue;
}

id valueForConfigKey(NSString *identifier, NSString *key, id defaultValue){
    return valueForConfigKeyWithPrefs(identifier, key, defaultValue, nil);
}

void setValueForConfigKeyWithPrefs(NSString *identifier, NSString *key, id value, NSDictionary *prefs){
    NSMutableArray *configs;
    if (!prefs){
        configs = [valueForKey(@"enabledIdentifier", nil) mutableCopy];
    }else{
        configs = [prefs[@"enabledIdentifier"] mutableCopy];
    }
    
    if (configs){
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @"identifier", identifier];
        NSMutableDictionary *config = [[configs filteredArrayUsingPredicate:predicate].firstObject mutableCopy];
        if (config){
            NSUInteger idx = [configs indexOfObject:config];
            config[key] = value;
            [configs replaceObjectAtIndex:idx withObject:config];
        }else{
            config = [NSMutableDictionary dictionary];
            [configs addObject:@{
                @"identifier":identifier,
                key:value
            }];
        }
    }else{
        configs = [NSMutableArray array];
        [configs addObject:@{
            @"identifier":identifier,
            key:value
        }];
    }
    setValueForKeyWithPrefs(@"enabledIdentifier", configs, prefs);
}

void setValueForConfigKey(NSString *identifier, NSString *key, id value){
    setValueForConfigKeyWithPrefs(identifier, key, value, nil);
}

void setConfigObject(NSString *identifier, NSDictionary *configObject){
    NSMutableArray *configs;
    configs = [valueForKey(@"enabledIdentifier", nil) mutableCopy];
    
    if (configs){
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @"identifier", identifier];
        NSMutableDictionary *config = [[configs filteredArrayUsingPredicate:predicate].firstObject mutableCopy];
        if (config){
            NSUInteger idx = [configs indexOfObject:config];
            [config addEntriesFromDictionary:configObject];
            [configs replaceObjectAtIndex:idx withObject:config];
        }else{
            config = [NSMutableDictionary dictionary];
            config[@"identifier"] = identifier;
            [config addEntriesFromDictionary:configObject];
            [configs addObject:config];
        }
    }else{
        configs = [NSMutableArray array];
        NSMutableDictionary *config = [NSMutableDictionary dictionary];
        config[@"identifier"] = identifier;
        [config addEntriesFromDictionary:configObject];
        [configs addObject:config];
    }
    setValueForKey(@"enabledIdentifier", configs);
}

id valueForConfigKeyWithPrefsAndIndex(NSString *key, id defaultValue, NSDictionary *prefs, NSUInteger index){
    if (!prefs){
        prefs = getPrefs();
    }
    return index != NSNotFound ? prefs[@"enabledIdentifier"][index][key] : defaultValue;
}

BOOL boolValueForConfigKeyWithPrefs(NSString *identifier, NSString *key, BOOL defaultValue, NSDictionary *prefs){
    id value = valueForConfigKeyWithPrefs(identifier, key, @(defaultValue), prefs);
    return value ? [value boolValue] : defaultValue;
}

BOOL boolValueForConfigKeyWithPrefsAndIndex(NSString *key, BOOL defaultValue, NSDictionary *prefs, NSUInteger index){
    id value = valueForConfigKeyWithPrefsAndIndex(key, @(defaultValue), prefs, index);
    return value ? [value boolValue] : defaultValue;
}

BOOL boolValueForConfigKey(NSString *identifier, NSString *key, BOOL defaultValue){
    return boolValueForConfigKeyWithPrefs(identifier, key, defaultValue, nil);
}

unsigned long unsignedLongValueForConfigKeyWithPrefs(NSString *identifier, NSString *key, unsigned long defaultValue, NSDictionary *prefs){
    id value = valueForConfigKeyWithPrefs(identifier, key, @(defaultValue), prefs);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value unsignedLongValue] : defaultValue;
}

unsigned long unsignedLongValueForConfigKeyWithPrefsAndIndex(NSString *key, unsigned long defaultValue, NSDictionary *prefs, NSUInteger index){
    id value = valueForConfigKeyWithPrefsAndIndex(key, @(defaultValue), prefs, index);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value unsignedLongValue] : defaultValue;}


unsigned long unsignedLongValueForConfigKey(NSString *identifier, NSString *key, unsigned long defaultValue){
    return unsignedLongValueForConfigKeyWithPrefs(identifier, key, defaultValue, nil);
}

unsigned long long unsignedLongLongValueForConfigKeyWithPrefs(NSString *identifier, NSString *key, unsigned long long defaultValue, NSDictionary *prefs){
    id value = valueForConfigKeyWithPrefs(identifier, key, @(defaultValue), prefs);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value unsignedLongLongValue] : defaultValue;
}

unsigned long long unsignedLongLongValueForConfigKeyWithPrefsAndIndex(NSString *key, unsigned long long defaultValue, NSDictionary *prefs, NSUInteger index){
    id value = valueForConfigKeyWithPrefsAndIndex(key, @(defaultValue), prefs, index);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value unsignedLongLongValue] : defaultValue;
}

unsigned long long unsignedLongLongValueForConfigKey(NSString *identifier, NSString *key, unsigned long long defaultValue){
    return unsignedLongValueForConfigKeyWithPrefs(identifier, key, defaultValue, nil);
}

int intValueForConfigKeyWithPrefs(NSString *identifier, NSString *key, int defaultValue, NSDictionary *prefs){
    id value = valueForConfigKeyWithPrefs(identifier, key, @(defaultValue), prefs);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value intValue] : defaultValue;
}

int intValueForConfigKeyWithPrefsAndIndex(NSString *key, int defaultValue, NSDictionary *prefs, NSUInteger index){
    id value = valueForConfigKeyWithPrefsAndIndex(key, @(defaultValue), prefs, index);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value intValue] : defaultValue;
}

int intValueForConfigKey(NSString *identifier, NSString *key, int defaultValue){
    return intValueForConfigKeyWithPrefs(identifier, key, defaultValue, nil);
}

double doubleValueForConfigKeyWithPrefs(NSString *identifier, NSString *key, double defaultValue, NSDictionary *prefs){
    id value = valueForConfigKeyWithPrefs(identifier, key, @(defaultValue), prefs);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value doubleValue] : defaultValue;
}

double doubleValueForConfigKeyWithPrefsAndIndex(NSString *key, double defaultValue, NSDictionary *prefs, NSUInteger index){
    id value = valueForConfigKeyWithPrefsAndIndex(key, @(defaultValue), prefs, index);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value doubleValue] : defaultValue;
}

double doubleValueForConfigKey(NSString *identifier, NSString *key, double defaultValue){
    return doubleValueForConfigKeyWithPrefs(identifier, key, defaultValue, nil);
}

float floatValueForConfigKeyWithPrefs(NSString *identifier, NSString *key, float defaultValue, NSDictionary *prefs){
    id value = valueForConfigKeyWithPrefs(identifier, key, @(defaultValue), prefs);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value floatValue] : defaultValue;
}

float floatValueForConfigKeyWithPrefsAndIndex(NSString *key, float defaultValue, NSDictionary *prefs, NSUInteger index){
    id value = valueForConfigKeyWithPrefsAndIndex(key, @(defaultValue), prefs, index);
    BOOL respondsToLength = [value respondsToSelector:@selector(length)];
    return ((value && !respondsToLength) || (value && respondsToLength && [value length] > 0)) ? [value floatValue] : defaultValue;
}

float floatValueForConfigKey(NSString *identifier, NSString *key, float defaultValue){
    return floatValueForConfigKeyWithPrefs(identifier, key, defaultValue, nil);
}
