// Real settings synchronization, block expiry, and daemon methods with in-memory
// storage and inert OS adapters. No firewall, preferences, or system clock writes.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "SCBlockClock.h"
#import "SCBlockUtilities.h"
#import "SCSettings.h"
#import "SCDaemonBlockMethods.h"
#import "SCDaemon.h"
#import "BlockManager.h"
#import "HostFileBlockerSet.h"
#import "LaunchctlHelper.h"

@interface SCSettings (TestAccess)
- (NSDictionary *)defaultSettingsDict;
@property NSInteger lastSynchronizedVersion;
@end
@interface MemorySettings : SCSettings
@property NSMutableDictionary *memory;
@property NSUInteger writes;
@end
@implementation MemorySettings
- (instancetype)init {
    if ((self = [super init])) {
        self.readOnly = NO;
        self.memory = [[self defaultSettingsDict] mutableCopy];
        self.lastSynchronizedVersion = 0;
    }
    return self;
}
- (NSDictionary *)settingsDict { return self.memory; }
- (void)reloadSettings {}
- (void)setValue:(id)value forKey:(NSString *)key { [super setValue:value forKey:key stopPropagation:YES]; }
- (void)writeSettingsWithCompletion:(void (^)(NSError *))completion {
    self.writes++;
    self.lastSynchronizedVersion = [self.memory[@"SettingsVersionNumber"] integerValue];
    if (completion) completion(nil);
}
@end

// Deliberately incomplete adapters: invoking an unexpected side effect fails.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wprotocol"
@implementation SCSentry
+ (void)addBreadcrumb:(NSString *)message category:(NSString *)category {}
+ (void)captureError:(NSError *)error {}
+ (void)captureMessage:(NSString *)message {}
@end
@implementation SCMiscUtilities
+ (BOOL)systemThirdPartyCrashReportingEnabled { return NO; }
+ (NSArray *)allUserHomeDirectoryURLs:(NSError **)error { return @[]; }
@end
@implementation SCMigrationUtilities
+ (BOOL)legacyLockFileExists { return NO; }
+ (BOOL)legacySettingsFoundForUser:(uid_t)uid { return NO; }
@end
static NSUInteger removals;
static BOOL filterActive = YES;
static BOOL repairSucceeds = YES;
static NSArray *reinstalledBlocklist;
static NSArray *appendedBlocklist;
static BOOL appendAllowsLocal;
static BOOL appendCommonSubdomains;
@implementation SCHelperToolUtilities
+ (void)installBlockRulesFromSettings {
    reinstalledBlocklist = [[SCSettings sharedSettings] valueForKey:@"ActiveBlocklist"];
    if (repairSucceeds) filterActive = YES;
}
+ (void)clearCachesIfRequested {}
+ (void)sendConfigurationChangedNotification {}
+ (void)removeBlock { removals++; [SCBlockUtilities removeBlockFromSettings]; }
@end
@implementation SCDaemon
+ (instancetype)sharedDaemon { static SCDaemon *daemon; if (!daemon) daemon = [self new]; return daemon; }
- (void)resetInactivityTimer {}
- (void)startCheckupTimer {}
- (void)stopCheckupTimer {}
@end
@implementation PacketFilter
- (BOOL)containsSelfControlBlock { return YES; }
- (BOOL)selfControlRulesAreActive { return filterActive; }
- (int)stopBlock:(BOOL)force { return 0; }
@end
@implementation HostFileBlocker
- (BOOL)containsSelfControlBlock { return YES; }
@end
@implementation HostFileBlockerSet
- (HostFileBlocker *)defaultBlocker { return [HostFileBlocker new]; }
- (void)removeSelfControlBlock {}
- (BOOL)writeNewFileContents { return YES; }
- (void)revertFileContentsToDisk {}
- (BOOL)restoreBackupHostsFile { return YES; }
- (BOOL)deleteBackupHostsFile { return YES; }
@end
@implementation BlockManager
- (instancetype)initAsAllowlist:(BOOL)allowlist allowLocal:(BOOL)local includeCommonSubdomains:(BOOL)common includeLinkedDomains:(BOOL)linked {
    if ((self = [super init])) { appendAllowsLocal = local; appendCommonSubdomains = common; }
    return self;
}
- (void)enterAppendMode {}
- (void)addBlockEntriesFromStrings:(NSArray *)entries { appendedBlocklist = entries; }
- (void)finishAppending {}
@end
@implementation LaunchctlHelper
@end
#pragma clang diagnostic pop

static MemorySettings *settings;
static double elapsedSample = 100;
static NSString *boot = @"boot-A";
static NSDate *wallDate;
static id memorySettings(id object, SEL selector) { return settings; }
static double fakeElapsed(id object, SEL selector) { return elapsedSample; }
static id fakeBoot(id object, SEL selector) { return boot; }
static id fakeDate(id object, SEL selector) { return wallDate; }
static NSUInteger assertions;
static void check(BOOL condition, NSString *message) {
    assertions++;
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

int main(void) {
    @autoreleasepool {
        settings = [MemorySettings new];
        method_setImplementation(class_getClassMethod(SCSettings.class, @selector(sharedSettings)), (IMP)memorySettings);
        method_setImplementation(class_getClassMethod(SCBlockClock.class, @selector(continuousSeconds)), (IMP)fakeElapsed);
        method_setImplementation(class_getClassMethod(SCBlockClock.class, @selector(bootSessionIdentifier)), (IMP)fakeBoot);
        wallDate = [NSDate date];
        NSDate *originalDate = wallDate;
        method_setImplementation(class_getClassMethod(NSDate.class, @selector(date)), (IMP)fakeDate);

        __block NSUInteger replies = 0;
        [SCDaemonBlockMethods startBlockWithControllingUID:501 blocklist:@[@"example.com"] isAllowlist:NO
                                                endDate:[originalDate dateByAddingTimeInterval:3600]
                                          blockSettings:@{} authorization:[NSData data]
                                                  reply:^(NSError *error) { check(error == nil, @"Start succeeds"); replies++; }];
        check(replies == 1 && [settings boolForKey:@"BlockUsesContinuousClock"], @"Start creates elapsed-time state");
        check(fabs([SCBlockUtilities currentBlockRemainingSeconds] - 3600) < 1, @"Start preserves selected duration");

        // Exercise actual daemon expiry and persistence while wall time jumps.
        for (NSNumber *shift in @[@315360000, @(-315360000), @3600, @(-3600)]) {
            wallDate = [originalDate dateByAddingTimeInterval:shift.doubleValue];
            // Move the old calendar deadline too, to explicitly model it in the past.
            [settings setValue:[NSDate distantPast] forKey:@"BlockEndDate"];
            [SCDaemonBlockMethods checkupBlock];
            check(removals == 0 && ![SCBlockUtilities currentBlockIsExpired], @"Clock jump never removes active rules");
        }
        [settings setValue:[originalDate dateByAddingTimeInterval:3600] forKey:@"BlockEndDate"];
        elapsedSample = 1000;
        [SCDaemonBlockMethods checkupBlock];
        check(fabs([SCBlockUtilities currentBlockRemainingSeconds] - 2700) < 1, @"Daemon checkpoints actual elapsed time");
        NSUInteger writesBefore = settings.writes;
        [settings setValue:[NSDate distantPast] forKey:@"LastSettingsUpdate"];
        [settings synchronizeSettings];
        check(settings.writes == writesBefore + 1, @"Older calendar date cannot suppress a dirty write");
        [settings synchronizeSettings];
        check(settings.writes == writesBefore + 1, @"Unchanged revision is not rewritten");

        [settings setValue:@NO forKey:@"AllowLocalNetworks"];
        [settings setValue:@YES forKey:@"EvaluateCommonSubdomains"];
        replies = 0;
        [SCDaemonBlockMethods updateBlocklist:@[@"new.example.com", @"new.example.com"] authorization:[NSData data]
                                       reply:^(NSError *error) { check(error == nil, @"Append succeeds"); replies++; }];
        check(replies == 1 && [[settings valueForKey:@"ActiveBlocklist"] isEqual:@[@"example.com", @"new.example.com"]], @"Omitted old sites stay in persisted list; duplicates disappear");
        check([appendedBlocklist isEqual:@[@"new.example.com"]], @"Only new sites go to append adapter");
        check(!appendAllowsLocal && appendCommonSubdomains, @"Append uses correct local-network and subdomain settings");
        [SCDaemonBlockMethods updateBlocklist:@[] authorization:[NSData data] reply:^(NSError *error) { check(error == nil, @"Empty update cannot remove sites"); }];
        check([[settings valueForKey:@"ActiveBlocklist"] count] == 2, @"Empty update preserves full active list");

        filterActive = NO;
        repairSucceeds = NO;
        [SCDaemonBlockMethods checkBlockIntegrity];
        check(![SCBlockUtilities currentProtectionIsHealthy], @"Failed firewall repair reports attention despite active countdown");
        check([reinstalledBlocklist isEqual:@[@"example.com", @"new.example.com"]], @"Repair uses preserved complete blocklist");
        repairSucceeds = YES;
        [SCDaemonBlockMethods checkBlockIntegrity];
        check([SCBlockUtilities currentProtectionIsHealthy], @"Successful repair publishes healthy daemon status");

        NSDate *end = [settings valueForKey:@"BlockEndDate"];
        for (NSNumber *delta in @[@(-1), @2592001]) {
            replies = 0;
            [SCDaemonBlockMethods updateBlockEndDate:[end dateByAddingTimeInterval:delta.doubleValue]
                                     authorization:[NSData data] reply:^(NSError *error) {
                check(error != nil, @"Invalid extension rejected"); replies++;
            }];
            check(replies == 1 && [[settings valueForKey:@"BlockEndDate"] isEqual:end], @"Invalid extension returns once without mutation");
        }
        replies = 0;
        [SCDaemonBlockMethods updateBlockEndDate:[end dateByAddingTimeInterval:600] authorization:[NSData data]
                                         reply:^(NSError *error) { check(error == nil, @"Valid extension succeeds"); replies++; }];
        check(replies == 1 && fabs([SCBlockUtilities currentBlockRemainingSeconds] - 3300) < 1, @"Extension adds real duration despite changed calendar");

        boot = @"boot-B";
        elapsedSample = 2000; // Larger than last boot's sample must not grant credit.
        [SCDaemonBlockMethods checkupBlock];
        check(removals == 0 && fabs([SCBlockUtilities currentBlockRemainingSeconds] - 3300) < 1, @"Reboot resumes saved remainder");
        elapsedSample = 5300;
        [SCDaemonBlockMethods checkupBlock];
        check(removals == 1 && ![SCBlockUtilities modernBlockIsRunning], @"Actual elapsed expiry removes rules");
        check(![settings boolForKey:@"BlockUsesContinuousClock"], @"Removal clears elapsed-time mode");

        [settings setValue:@YES forKey:@"BlockUsesContinuousClock"];
        [settings setValue:nil forKey:@"BlockClockState"];
        [settings setValue:[NSDate distantPast] forKey:@"BlockEndDate"];
        check(![SCBlockUtilities currentBlockIsExpired], @"Missing protected state never falls back to calendar expiry");
        printf("PASS: %lu integration assertions\n", (unsigned long)assertions);
    }
    return 0;
}
