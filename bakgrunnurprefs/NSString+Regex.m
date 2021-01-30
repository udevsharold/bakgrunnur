#import "../common.h"
#import "NSString+Regex.h"

@implementation NSString (Regex)

- (NSString *)stringByReplacingWithPattern:(NSString *)pattern withTemplate:(NSString *)withTemplate error:(NSError **)error {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:error];
    return [regex stringByReplacingMatchesInString:self options:0 range:NSMakeRange(0, self.length) withTemplate:withTemplate];
}

@end
