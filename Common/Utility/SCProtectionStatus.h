#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface SCProtectionStatus : NSObject
+ (BOOL)recordIsHealthy:(nullable id)record at:(NSTimeInterval)now bootSession:(nullable NSString *)boot;
+ (BOOL)packetFilterIsEnabled:(NSString *)info rootRules:(NSString *)rootRules anchorRules:(NSString *)anchorRules;
@end
NS_ASSUME_NONNULL_END
