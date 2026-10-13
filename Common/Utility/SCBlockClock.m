#import "SCBlockClock.h"
#import <mach/mach_time.h>
#import <sys/sysctl.h>
#import <math.h>

@implementation SCBlockClock

+ (NSTimeInterval)continuousSeconds {
    static mach_timebase_info_data_t timebase;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ mach_timebase_info(&timebase); });
    uint64_t ticks;
    if (@available(macOS 10.12, *)) {
        ticks = mach_continuous_time(); // Includes sleep, unaffected by date changes.
    } else {
        ticks = mach_absolute_time(); // Older systems conservatively exclude sleep.
    }
    return (double)ticks * timebase.numer / timebase.denom / 1e9;
}

+ (NSString *)bootSessionIdentifier {
    // Unlike kern.boottime, this does not move when the calendar clock changes.
    char identifier[128] = {0};
    size_t size = sizeof(identifier);
    if (sysctlbyname("kern.bootsessionuuid", identifier, &size, NULL, 0) != 0) return nil;
    identifier[sizeof(identifier) - 1] = '\0';
    return [NSString stringWithUTF8String:identifier];
}

+ (NSDictionary *)stateForDuration:(NSTimeInterval)duration at:(NSTimeInterval)now bootSession:(NSString *)bootSession {
    if (!isfinite(duration) || duration < 0 || !isfinite(now) || now < 0 || bootSession.length == 0) return nil;
    return @{@"Remaining": @(duration), @"Sample": @(now), @"BootSession": bootSession};
}

+ (NSTimeInterval)remainingWithState:(id)state at:(NSTimeInterval)now bootSession:(NSString *)bootSession {
    // A damaged new-format state must never fall back to the editable end date.
    if (![state isKindOfClass:NSDictionary.class] ||
        ![state[@"Remaining"] isKindOfClass:NSNumber.class] ||
        ![state[@"Sample"] isKindOfClass:NSNumber.class] ||
        ![state[@"BootSession"] isKindOfClass:NSString.class]) return INFINITY;
    double remaining = [state[@"Remaining"] doubleValue];
    double sample = [state[@"Sample"] doubleValue];
    if (!isfinite(remaining) || remaining < 0 || !isfinite(sample) || sample < 0 ||
        [state[@"BootSession"] length] == 0 || !isfinite(now) || now < 0 || bootSession.length == 0) return INFINITY;

    // Monotonic samples cannot be compared across boots. Resume the last saved
    // remainder, excluding the unverifiable interval while the Mac was off.
    if (![state[@"BootSession"] isEqualToString:bootSession] || now < sample) return remaining;
    return MAX(0, remaining - (now - sample));
}

+ (NSDictionary *)checkpointState:(id)state at:(NSTimeInterval)now bootSession:(NSString *)bootSession {
    return [self stateForDuration:[self remainingWithState:state at:now bootSession:bootSession]
                              at:now bootSession:bootSession];
}

+ (NSDictionary *)extendState:(id)state by:(NSTimeInterval)duration at:(NSTimeInterval)now bootSession:(NSString *)bootSession {
    if (!isfinite(duration) || duration < 0 || duration > 30 * 86400) return nil;
    return [self stateForDuration:[self remainingWithState:state at:now bootSession:bootSession] + duration
                              at:now bootSession:bootSession];
}
@end
