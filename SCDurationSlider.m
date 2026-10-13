//
//  SCTimeSlider.m
//  SelfControl
//
//  Created by Charlie Stigler on 4/17/21.
//

#import "SCDurationSlider.h"
#import "SCTimeIntervalFormatter.h"
// Storage remains in minutes so existing blocks and CLI clients keep their units.
@interface SCDurationValueTransformer : NSValueTransformer
@property BOOL usesDays;
@end
@implementation SCDurationValueTransformer
+ (Class)transformedValueClass { return NSNumber.class; }
+ (BOOL)allowsReverseTransformation { return YES; }
- (id)transformedValue:(id)value {
    double minutes = [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0;
    return @(self.usesDays ? minutes / 1440.0 : minutes);
}
- (id)reverseTransformedValue:(id)value {
    double number = [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0;
    return @(lround(number) * (self.usesDays ? 1440 : 1));
}
@end

#define kValueTransformerName @"BlockDurationSliderTransformer"

@implementation SCDurationSlider

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder: coder]) {
        [self initializeDurationProperties];
    }
    return self;
}
- (instancetype)init {
    if (self = [super init]) {
        [self initializeDurationProperties];
    }
    return self;
}

- (void)initializeDurationProperties {
    // default: 1 day max
    _maxDuration = 1440;

    // register an NSValueTransformer
    [self registerMinutesValueTransformer];
}

- (void)setUsesDays:(BOOL)usesDays {
    _usesDays = usesDays;
    [self setMaxDuration:_maxDuration];
}

- (void)setMaxDuration:(NSInteger)maxDuration {
    _maxDuration = MAX(self.usesDays ? 1440 : 1, maxDuration);
    self.minValue = 1;
    self.maxValue = self.usesDays ? MAX(1, _maxDuration / 1440) : _maxDuration;
    self.numberOfTickMarks = self.usesDays ? (NSInteger)self.maxValue : 0;
    self.allowsTickMarkValuesOnly = self.usesDays;
}

- (void)registerMinutesValueTransformer {
    SCDurationValueTransformer *transformer = [SCDurationValueTransformer new];
    [NSValueTransformer setValueTransformer:transformer forName:kValueTransformerName];
}

- (NSInteger)durationValueMinutes {
    return lround(self.doubleValue) * (self.usesDays ? 1440 : 1);
}

- (void)bindDurationToObject:(id)obj keyPath:(NSString*)keyPath {
    SCDurationValueTransformer *transformer = [SCDurationValueTransformer new];
    transformer.usesDays = self.usesDays;
    [self bind: @"value"
      toObject: obj
   withKeyPath: keyPath
       options: @{
                  NSContinuouslyUpdatesValueBindingOption: @YES,
                  NSValueTransformerBindingOption: transformer
                  }];
}

- (NSString*)durationDescription {
    if (self.usesDays) {
        NSInteger days = self.durationValueMinutes / 1440;
        return [NSString stringWithFormat:days == 1 ? NSLocalizedString(@"%ld day", nil) : NSLocalizedString(@"%ld days", nil), (long)days];
    }
    return [SCDurationSlider timeSliderDisplayStringFromNumberOfMinutes: self.durationValueMinutes];
}

// String conversion utility methods

+ (NSString *)timeSliderDisplayStringFromTimeInterval:(NSTimeInterval)numberOfSeconds {
    static SCTimeIntervalFormatter* formatter = nil;
    if (formatter == nil) {
        formatter = [[SCTimeIntervalFormatter alloc] init];
    }

    NSString* formatted = [formatter stringForObjectValue:@(numberOfSeconds)];
    return formatted;
}

+ (NSString *)timeSliderDisplayStringFromNumberOfMinutes:(NSInteger)numberOfMinutes {
    if (numberOfMinutes < 0) return @"Invalid duration";

    static NSCalendar* gregorian = nil;
    if (gregorian == nil) {
        gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    }

    NSRange secondsRangePerMinute = [gregorian
                                     rangeOfUnit:NSCalendarUnitSecond
                                     inUnit:NSCalendarUnitMinute
                                     forDate:[NSDate date]];
    NSInteger numberOfSecondsPerMinute = (NSInteger)NSMaxRange(secondsRangePerMinute);

    NSTimeInterval numberOfSecondsSelected = (NSTimeInterval)(numberOfSecondsPerMinute * numberOfMinutes);

    NSString* displayString = [SCDurationSlider timeSliderDisplayStringFromTimeInterval:numberOfSecondsSelected];
    return displayString;
}


@end
