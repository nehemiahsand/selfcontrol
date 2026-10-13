//
//  SCBlockUtilities.m
//  SelfControl
//
//  Created by Charlie Stigler on 1/19/21.
//

#import "SCBlockUtilities.h"
#import "HostFileBlocker.h"
#import "PacketFilter.h"
#import "SCBlockClock.h"
#import "SCProtectionStatus.h"
#import <math.h>

@implementation SCBlockUtilities

+ (BOOL)anyBlockIsRunning {
    BOOL blockIsRunning = [SCBlockUtilities modernBlockIsRunning] || [SCBlockUtilities legacyBlockIsRunning];

    return blockIsRunning;
}

+ (BOOL)modernBlockIsRunning {
    SCSettings* settings = [SCSettings sharedSettings];
    
    return [settings boolForKey: @"BlockIsRunning"];
}

+ (BOOL)legacyBlockIsRunning {
    // first see if there's a legacy settings file from v3.x
    // which could be in any user's home folder
    NSError* homeDirErr = nil;
    NSArray<NSURL *>* homeDirectoryURLs = [SCMiscUtilities allUserHomeDirectoryURLs: &homeDirErr];
    if (homeDirectoryURLs != nil) {
        for (NSURL* homeDirURL in homeDirectoryURLs) {
            NSString* relativeSettingsPath = [NSString stringWithFormat: @"/Library/Preferences/%@", SCSettings.settingsFileName];
            NSURL* settingsFileURL = [homeDirURL URLByAppendingPathComponent: relativeSettingsPath isDirectory: NO];
            
            if ([SCMigrationUtilities legacyBlockIsRunningInSettingsFile: settingsFileURL]) {
                return YES;
            }
        }
    }

    // nope? OK, how about a lock file from pre-3.0?
    if ([SCMigrationUtilities legacyLockFileExists]) {
        return YES;
    }
    
    // we don't check defaults anymore, though pre-3.0 blocks did
    // have data stored there. That should be covered by the lockfile anyway
    
    return NO;
}

+ (BOOL)currentBlockIsExpired {
    return [self currentBlockRemainingSeconds] <= 0;
}

+ (NSTimeInterval)currentBlockRemainingSeconds {
    SCSettings* settings = [SCSettings sharedSettings];
    if ([settings boolForKey:@"BlockUsesContinuousClock"]) {
        return [SCBlockClock remainingWithState:[settings valueForKey:@"BlockClockState"]
                                            at:[SCBlockClock continuousSeconds]
                                   bootSession:[SCBlockClock bootSessionIdentifier]];
    }
    // Blocks started by older releases have no elapsed-time anchor. Do not
    // invent one from a possibly already modified clock during an upgrade.
    return [[settings valueForKey:@"BlockEndDate"] timeIntervalSinceNow];
}

+ (void)checkpointBlockClock {
    SCSettings* settings = [SCSettings sharedSettings];
    if (settings.readOnly || ![settings boolForKey:@"BlockUsesContinuousClock"]) return;
    NSDictionary* state = [SCBlockClock checkpointState:[settings valueForKey:@"BlockClockState"]
                                                   at:[SCBlockClock continuousSeconds]
                                          bootSession:[SCBlockClock bootSessionIdentifier]];
    if (state != nil) {
        [settings setValue:state forKey:@"BlockClockState"];
        [settings synchronizeSettings];
    }
}

+ (BOOL)blockRulesFoundOnSystem {
    return [PacketFilter blockFoundInPF] || [HostFileBlocker blockFoundInHostsFile];
}
+ (BOOL)currentProtectionIsHealthy {
    SCSettings *settings = [SCSettings sharedSettings];
    return [self modernBlockIsRunning] && isfinite([self currentBlockRemainingSeconds]) &&
        [SCProtectionStatus recordIsHealthy:[settings valueForKey:@"ProtectionStatus"]
                                        at:[SCBlockClock continuousSeconds]
                               bootSession:[SCBlockClock bootSessionIdentifier]];
}

+ (void) removeBlockFromSettings {
    SCSettings* settings = [SCSettings sharedSettings];
    [settings setValue: @NO forKey: @"BlockIsRunning"];
    [settings setValue: nil forKey: @"BlockEndDate"];
    [settings setValue:@NO forKey:@"BlockUsesContinuousClock"];
    [settings setValue:nil forKey:@"BlockClockState"];
    [settings setValue:nil forKey:@"ProtectionStatus"];
    [settings setValue: nil forKey: @"ActiveBlocklist"];
    [settings setValue: nil forKey: @"ActiveBlockAsWhitelist"];
}

@end
