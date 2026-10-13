// Standalone Foundation tests: no helper installation, sudo, network, or clock changes.
#import <Foundation/Foundation.h>
#import "SCBlockClock.h"
#import "SCProtectionStatus.h"
#import "SCSiteBundles.h"
#import <math.h>
#import <stdlib.h>

static NSUInteger assertions = 0;
static void check(BOOL condition, NSString *message) {
    assertions++;
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        NSDictionary *state = [SCBlockClock stateForDuration:3600 at:100 bootSession:@"boot-A"];
        check([SCBlockClock remainingWithState:state at:100 bootSession:@"boot-A"] == 3600, @"Full starting duration");
        check([SCBlockClock remainingWithState:state at:1000 bootSession:@"boot-A"] == 2700, @"Elapsed time deducted");

        // Calendar data is deliberately not an input to the expiry decision.
        // Simulate dates far forward/backward and timezone/DST adjustments.
        for (NSNumber *jump in @[@315360000, @(-315360000), @3600, @(-3600), @0]) {
            NSMutableDictionary *withWallClock = [state mutableCopy];
            withWallClock[@"BlockEndDate"] = [NSDate dateWithTimeIntervalSince1970:jump.doubleValue];
            check([SCBlockClock remainingWithState:withWallClock at:1000 bootSession:@"boot-A"] == 2700, @"Calendar cannot expire or extend a block");
        }
        check([SCBlockClock remainingWithState:state at:3700 bootSession:@"boot-A"] == 0, @"Exact expiry");
        check([SCBlockClock remainingWithState:state at:100000 bootSession:@"boot-A"] == 0, @"Sleep past expiry");
        check([SCBlockClock remainingWithState:state at:3699.75 bootSession:@"boot-A"] == .25, @"Fractional second is still blocked");

        NSDictionary *checkpoint = [SCBlockClock checkpointState:state at:1000 bootSession:@"boot-A"];
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:checkpoint format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
        NSDictionary *restored = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
        check([SCBlockClock remainingWithState:restored at:1100 bootSession:@"boot-A"] == 2600, @"Daemon restart keeps same-boot elapsed time");

        check([SCBlockClock remainingWithState:restored at:5000 bootSession:@"boot-B"] == 2700, @"Reboot cannot reuse uptime even when larger than old sample");
        NSDictionary *rebooted = [SCBlockClock checkpointState:restored at:5000 bootSession:@"boot-B"];
        check([SCBlockClock remainingWithState:rebooted at:5100 bootSession:@"boot-B"] == 2600, @"Countdown resumes after reboot checkpoint");
        check([SCBlockClock remainingWithState:rebooted at:5000 bootSession:@"boot-C"] == 2700, @"Repeated reboot grants no extra elapsed credit");
        check([SCBlockClock remainingWithState:restored at:999 bootSession:@"boot-A"] == 2700, @"Unexpected monotonic rollback cannot unlock");

        NSDictionary *extended = [SCBlockClock extendState:restored by:600 at:1100 bootSession:@"boot-A"];
        check([SCBlockClock remainingWithState:extended at:1100 bootSession:@"boot-A"] == 3200, @"Extension adds to remaining elapsed duration");
        check([SCBlockClock extendState:state by:-1 at:100 bootSession:@"boot-A"] == nil, @"Reject shortening");
        check([SCBlockClock extendState:state by:30 * 86400 at:100 bootSession:@"boot-A"] != nil, @"Accept the maximum 30-day extension");
        check([SCBlockClock extendState:state by:2592001 at:100 bootSession:@"boot-A"] == nil, @"Reject excessive extension");

        for (id invalid in @[@{}, @[], @"corrupt", @{@"Remaining": @(-1), @"Sample": @0, @"BootSession": @"boot-A"},
                             @{@"Remaining": @(NAN), @"Sample": @0, @"BootSession": @"boot-A"},
                             @{@"Remaining": @3600, @"Sample": @"0", @"BootSession": @"boot-A"}]) {
            check(isinf([SCBlockClock remainingWithState:invalid at:100 bootSession:@"boot-A"]), @"Corrupt state cannot unlock");
            check([SCBlockClock checkpointState:invalid at:100 bootSession:@"boot-A"] == nil, @"Cannot repair corrupt state from calendar time");
        }
        check(isinf([SCBlockClock remainingWithState:nil at:100 bootSession:@"boot-A"]), @"Missing state cannot unlock");
        check(isinf([SCBlockClock remainingWithState:state at:NAN bootSession:@"boot-A"]), @"Invalid clock cannot unlock");
        check([SCBlockClock stateForDuration:INFINITY at:100 bootSession:@"boot-A"] == nil, @"Reject nonfinite duration");
        check([SCBlockClock stateForDuration:3600 at:100 bootSession:nil] == nil, @"Require boot identity");
        check([SCBlockClock extendState:state by:NAN at:100 bootSession:@"boot-A"] == nil, @"Reject nonfinite extension");

        NSDictionary *healthy = @{@"RulesPresent": @YES, @"CheckedAt": @100, @"BootSession": @"boot-A"};
        check([SCProtectionStatus recordIsHealthy:healthy at:130 bootSession:@"boot-A"], @"Fresh protection report accepted");
        check(![SCProtectionStatus recordIsHealthy:healthy at:146 bootSession:@"boot-A"], @"Dead daemon heartbeat reports attention");
        check(![SCProtectionStatus recordIsHealthy:healthy at:90 bootSession:@"boot-A"], @"Future sample does not imply health");
        check(![SCProtectionStatus recordIsHealthy:healthy at:130 bootSession:@"boot-B"], @"Old boot report is invalid");
        check(![SCProtectionStatus recordIsHealthy:@{} at:130 bootSession:@"boot-A"], @"Missing protection report is not healthy");
        check(![SCProtectionStatus recordIsHealthy:healthy at:NAN bootSession:@"boot-A"], @"Invalid status clock is not healthy");
        check([SCProtectionStatus packetFilterIsEnabled:@"Status: Enabled for 0 days\n" rootRules:@"anchor \"org.eyebeam\" all" anchorRules:@"block drop out inet from any to 1.2.3.4"], @"Enabled loaded anchor has block rules");
        check(![SCProtectionStatus packetFilterIsEnabled:@"Status: Disabled" rootRules:@"anchor \"org.eyebeam\" all" anchorRules:@"block drop out"], @"Config files do not hide disabled firewall");
        check(![SCProtectionStatus packetFilterIsEnabled:@"Status: Enabled" rootRules:@"anchor \"other\" all" anchorRules:@"block drop out"], @"Unreferenced anchor is not active");
        check(![SCProtectionStatus packetFilterIsEnabled:@"Status: Enabled" rootRules:@"anchor \"org.eyebeam\" all" anchorRules:@""], @"Empty loaded anchor is not active");
        check(![SCProtectionStatus packetFilterIsEnabled:@"Status: Enabled" rootRules:@"anchor \"org.eyebeam\" all" anchorRules:@"pass out all"], @"Allow-only rules do not count as a block");
        NSArray *youtube = [SCSiteBundles domainsForName:@"YouTube"];
        check([youtube containsObject:@"youtu.be"] && [youtube containsObject:@"youtubei.googleapis.com"] && [youtube containsObject:@"googlevideo.com"], @"YouTube bundle includes short links, API, and video host");
        check(![youtube containsObject:@"google.com"] && ![youtube containsObject:@"googleapis.com"], @"Bundle avoids broad shared infrastructure");
        for (NSString *name in [SCSiteBundles names]) {
            NSArray *domains = [SCSiteBundles domainsForName:name];
            check(domains.count > 0 && [NSSet setWithArray:domains].count == domains.count, @"Every menu bundle is nonempty and deduplicated");
        }
        check([SCSiteBundles domainsForName:@"Unknown"].count == 0, @"Unknown bundle has no domains");

        // Actual OS adapter smoke check. This reads the clocks only.
        NSString *boot = [SCBlockClock bootSessionIdentifier];
        double before = [SCBlockClock continuousSeconds];
        check(boot.length > 0, @"Kernel exposes a boot-session UUID");
        check([[SCBlockClock bootSessionIdentifier] isEqualToString:boot], @"Boot identity is stable");
        check(isfinite(before) && before >= 0 && [SCBlockClock continuousSeconds] >= before, @"Actual continuous clock advances");
        printf("PASS: %lu clock assertions\n", (unsigned long)assertions);
    }
    return 0;
}
