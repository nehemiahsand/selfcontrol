#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Elapsed-time state, independent of NSDate and the user-adjustable clock.
// Explicit samples make reboot, sleep, and clock-change cases testable without
// changing the host's clock or installing firewall rules.
@interface SCBlockClock : NSObject
+ (NSTimeInterval)continuousSeconds;
+ (nullable NSString *)bootSessionIdentifier;
+ (nullable NSDictionary *)stateForDuration:(NSTimeInterval)duration
                                         at:(NSTimeInterval)now
                                bootSession:(nullable NSString *)bootSession;
+ (NSTimeInterval)remainingWithState:(nullable id)state
                                 at:(NSTimeInterval)now
                        bootSession:(nullable NSString *)bootSession;
+ (nullable NSDictionary *)checkpointState:(nullable id)state
                                       at:(NSTimeInterval)now
                              bootSession:(nullable NSString *)bootSession;
+ (nullable NSDictionary *)extendState:(nullable id)state
                                    by:(NSTimeInterval)duration
                                    at:(NSTimeInterval)now
                           bootSession:(nullable NSString *)bootSession;
@end

NS_ASSUME_NONNULL_END
