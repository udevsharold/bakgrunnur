#import "SpringBoard.h"

extern BOOL enabled;
extern NSDictionary *prefs;
extern NSArray *enabledIdentifier;
extern NSArray *allEntriesIdentifier;
extern SBFloatingDockView *floatingDockView;
extern double globalTimeSpan;
extern BOOL quickActionMaster;
extern BOOL quickActionOnce;
extern NSArray *persistenceOnce;

#ifdef __cplusplus
extern "C" {
#endif

NSDictionary* getPrefs();
id valueForKey(NSString *key, id defaultValue);
id valueForKeyWithPrefs(NSString *key, NSDictionary *prefs);
BOOL boolValueForKeyWithPrefs(NSString *key, BOOL defaultValue, NSDictionary *prefs);
BOOL boolValueForKey(NSString *key, BOOL defaultValue);
unsigned long unsignedLongValueForKeyWithPrefs(NSString *key, unsigned long defaultValue, NSDictionary *prefs);
unsigned long unsignedLongValueForKey(NSString *key, unsigned long defaultValue);
unsigned long long unsignedLongLongValueForKeyWithPrefs(NSString *key, unsigned long long defaultValue, NSDictionary *prefs);
unsigned long long unsignedLongLongValueForKey(NSString *key, unsigned long long defaultValue);
long long longLongValueForKeyWithPrefs(NSString *key, long long defaultValue, NSDictionary *prefs);
long long longLongValueForKey(NSString *key, long long defaultValue);
int intValueForKeyWithPrefs(NSString *key, int defaultValue, NSDictionary *prefs);
int intValueForKey(NSString *key, int defaultValue);
double doubleValueForKeyWithPrefs(NSString *key, double defaultValue, NSDictionary *prefs);
double doubleValueForKey(NSString *key, double defaultValue);
float floatValueForKeyWithPrefs(NSString *key, float defaultValue, NSDictionary *prefs);
float floatValueForKey(NSString *key, float defaultValue);
void setValueForKey(NSString *key, id value);
void setValueForKeyWithPrefs(NSString *key, id value, NSDictionary *prefs);
id valueForConfigKey(NSString *identifier, NSString *key, id defaultValue);
id valueForConfigKeyWithPrefs(NSString *identifier, NSString *key, id defaultValue, NSDictionary *prefs);
void setValueForConfigKey(NSString *identifier, NSString *key, id value);
void setValueForConfigKeyWithPrefs(NSString *identifier, NSString *key, id value, NSDictionary *prefs);
void setConfigObject(NSString *identifier, NSDictionary *configObject);
void removeConfig(NSString *identifier);
id valueForConfigKeyWithPrefsAndIndex(NSString *key, id defaultValue, NSDictionary *prefs, NSUInteger index);
BOOL boolValueForConfigKeyWithPrefs(NSString *identifier, NSString *key, BOOL defaultValue, NSDictionary *prefs);
BOOL boolValueForConfigKeyWithPrefsAndIndex(NSString *key, BOOL defaultValue, NSDictionary *prefs, NSUInteger index);
BOOL boolValueForConfigKey(NSString *identifier, NSString *key, BOOL defaultValue);
unsigned long unsignedLongValueForConfigKeyWithPrefs(NSString *identifier, NSString *key, unsigned long defaultValue, NSDictionary *prefs);
unsigned long unsignedLongValueForConfigKeyWithPrefsAndIndex(NSString *key, unsigned long defaultValue, NSDictionary *prefs, NSUInteger index);
unsigned long unsignedLongValueForConfigKey(NSString *identifier, NSString *key, unsigned long defaultValue);
unsigned long long unsignedLongLongValueForConfigKeyWithPrefs(NSString *identifier, NSString *key, unsigned long long defaultValue, NSDictionary *prefs);
unsigned long long unsignedLongLongValueForConfigKeyWithPrefsAndIndex(NSString *key, unsigned long long defaultValue, NSDictionary *prefs, NSUInteger index);
unsigned long long unsignedLongLongValueForConfigKey(NSString *identifier, NSString *key, unsigned long long defaultValue);
int intValueForConfigKeyWithPrefs(NSString *identifier, NSString *key, int defaultValue, NSDictionary *prefs);
int intValueForConfigKeyWithPrefsAndIndex(NSString *key, int defaultValue, NSDictionary *prefs, NSUInteger index);
int intValueForConfigKey(NSString *identifier, NSString *key, int defaultValue);
double doubleValueForConfigKeyWithPrefs(NSString *identifier, NSString *key, double defaultValue, NSDictionary *prefs);
double doubleValueForConfigKeyWithPrefsAndIndex(NSString *key, double defaultValue, NSDictionary *prefs, NSUInteger index);
double doubleValueForConfigKey(NSString *identifier, NSString *key, double defaultValue);
float floatValueForConfigKeyWithPrefs(NSString *identifier, NSString *key, float defaultValue, NSDictionary *prefs);
float floatValueForConfigKeyWithPrefsAndIndex(NSString *key, float defaultValue, NSDictionary *prefs, NSUInteger index);
float floatValueForConfigKey(NSString *identifier, NSString *key, float defaultValue);

#ifdef __cplusplus
}
#endif
