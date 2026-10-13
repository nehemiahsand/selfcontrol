#import "SCProtectionStatus.h"
#import <math.h>

@implementation SCProtectionStatus
+ (BOOL)recordIsHealthy:(id)record at:(NSTimeInterval)now bootSession:(NSString *)boot {
    if (![record isKindOfClass:NSDictionary.class] ||
        ![record[@"RulesPresent"] isKindOfClass:NSNumber.class] ||
        ![record[@"CheckedAt"] isKindOfClass:NSNumber.class] ||
        ![record[@"BootSession"] isKindOfClass:NSString.class] || boot.length == 0) return NO;
    NSTimeInterval checkedAt = [record[@"CheckedAt"] doubleValue];
    return [record[@"RulesPresent"] boolValue] && [record[@"BootSession"] isEqualToString:boot] &&
        isfinite(now) && isfinite(checkedAt) && checkedAt >= 0 && now >= checkedAt && now - checkedAt <= 45;
}
+ (BOOL)packetFilterIsEnabled:(NSString *)info rootRules:(NSString *)rootRules anchorRules:(NSString *)anchorRules {
    BOOL enabled = NO;
    for (NSString *line in [info componentsSeparatedByString:@"\n"]) {
        if ([line hasPrefix:@"Status: Enabled"]) enabled = YES;
    }
    BOOL anchorReferenced = [rootRules containsString:@"anchor \"org.eyebeam\""];
    BOOL hasBlockRule = NO;
    for (NSString *line in [anchorRules componentsSeparatedByString:@"\n"]) {
        if ([[line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] hasPrefix:@"block "]) hasBlockRule = YES;
    }
    return enabled && anchorReferenced && hasBlockRule;
}
@end
