#import <Cocoa/Cocoa.h>
#import "SCDurationSlider.h"

@interface SCDurationTestModel : NSObject
@property NSNumber *minutes;
@end
@implementation SCDurationTestModel
@end
static int assertions;
static void check(BOOL value, NSString *message) {
    assertions++;
    if (!value) { NSLog(@"FAIL: %@", message); exit(1); }
}
int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        SCDurationSlider *slider = [SCDurationSlider new];
        slider.usesDays = YES;
        slider.maxDuration = 43200;
        check(slider.minValue == 1 && slider.maxValue == 30, @"Day range is 1–30");
        check(slider.allowsTickMarkValuesOnly && slider.numberOfTickMarks == 30, @"Only whole days are selectable");
        SCDurationTestModel *model = [SCDurationTestModel new];
        model.minutes = @2880;
        [slider bindDurationToObject:model keyPath:@"minutes"];
        check(slider.integerValue == 2 && slider.durationValueMinutes == 2880, @"Saved minutes display as days");
        NSDictionary *binding = [slider infoForBinding:@"value"];
        NSValueTransformer *transformer = binding[NSOptionsKey][NSValueTransformerBindingOption];
        for (NSNumber *days in @[@1, @2, @15, @30]) {
            NSNumber *minutes = [transformer reverseTransformedValue:days];
            check(minutes.integerValue == days.integerValue * 1440, @"Days persist in minutes");
            check([[transformer transformedValue:minutes] isEqual:days], @"Conversion round trips");
            slider.integerValue = days.integerValue;
            check(slider.durationValueMinutes == minutes.integerValue, @"Actual timer uses selected days");
        }
        slider.integerValue = 1;
        check([slider.durationDescription isEqual:@"1 day"], @"Singular label");
        slider.integerValue = 30;
        check([slider.durationDescription isEqual:@"30 days"], @"Plural label");
        model.minutes = @7200;
        check(slider.integerValue == 5, @"Binding updates from saved preference");
        [slider unbind:@"value"];
        SCDurationSlider *legacy = [SCDurationSlider new];
        legacy.maxDuration = 1440;
        legacy.integerValue = 60;
        check(legacy.durationValueMinutes == 60, @"Minute mode remains compatible");
        NSLog(@"PASS: %d day-slider assertions", assertions);
    }
    return 0;
}
