#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface SCSiteBundles : NSObject
+ (NSArray<NSString *> *)names;
+ (NSArray<NSString *> *)domainsForName:(NSString *)name;
@end
NS_ASSUME_NONNULL_END
