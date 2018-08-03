@import Foundation;

// Via https://gist.github.com/yconst/d6040a1a2785e43c4bff

@interface NSArray (Statistics)

- (NSNumber *)calculateStat:(NSString *)stat;

- (NSNumber *)sum;

- (NSNumber *)mean;

- (NSNumber *)min;

- (NSNumber *)max;

- (NSNumber *)median;

- (NSNumber *)variance;

- (NSNumber *)stdev;

@end
