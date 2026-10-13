#import "SCSiteBundles.h"

@implementation SCSiteBundles
+ (NSArray<NSString *> *)names { return @[@"YouTube", @"Reddit", @"Instagram"]; }
+ (NSArray<NSString *> *)domainsForName:(NSString *)name {
    // Explicit domains only: never add broad shared Google/Meta infrastructure.
    // These are convenient starting lists, not a guarantee against every route.
    NSDictionary *bundles = @{
        @"YouTube": @[@"youtube.com", @"www.youtube.com", @"m.youtube.com", @"youtu.be",
                      @"youtube-nocookie.com", @"www.youtube-nocookie.com", @"googlevideo.com",
                      @"ytimg.com", @"i.ytimg.com", @"s.ytimg.com", @"youtube.googleapis.com",
                      @"youtubei.googleapis.com"],
        @"Reddit": @[@"reddit.com", @"www.reddit.com", @"old.reddit.com", @"new.reddit.com",
                     @"redd.it", @"redditmedia.com", @"redditstatic.com"],
        @"Instagram": @[@"instagram.com", @"www.instagram.com", @"i.instagram.com", @"cdninstagram.com"]
    };
    return bundles[name] ?: @[];
}
@end
