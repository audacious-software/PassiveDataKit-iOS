#import "NSArray+Statistics.h"

@implementation NSArray (Statistics)

- (NSNumber *)calculateStat:(NSString *)stat
{
    if ([stat isEqualToString:@"min"])
    {
        return [self min];
    }
    else if ([stat isEqualToString:@"max"])
    {
        return [self max];
    }
    else if ([stat isEqualToString:@"mean"] || [stat isEqualToString:@"average"])
    {
        return [self mean];
    }
    else if ([stat isEqualToString:@"median"])
    {
        return [self median];
    }
    else if ([stat isEqualToString:@"variance"])
    {
        return [self variance];
    }
    else if ([stat isEqualToString:@"stdev"])
    {
        return [self stdev];
    }
    return nil;
}

- (NSNumber *)sum
{
    return [self valueForKeyPath:@"@sum.self"];
}

- (NSNumber *)mean
{
    return [self valueForKeyPath:@"@avg.self"];
}

- (NSNumber *)min
{
    return [self valueForKeyPath:@"@min.self"];
}

- (NSNumber *)max
{
    return [self valueForKeyPath:@"@max.self"];
}

- (NSNumber *)median {
    NSArray *sortedArray = [self sortedArrayUsingSelector:@selector(compare:)];
    NSNumber *median;
    if (sortedArray.count != 1)
    {
        if (sortedArray.count % 2 == 0)
        {
            median = @(([sortedArray[sortedArray.count / 2] integerValue]) + ([sortedArray[sortedArray.count / 2 + 1] integerValue]) / 2);
        }
        else
        {
            median = @([sortedArray[sortedArray.count / 2] integerValue]);
        }
    }
    else
    {
        median = [sortedArray objectAtIndex:1];
    }
    return median;
}

- (NSNumber *)variance
{
    double mean = [[self mean] doubleValue];
    double meanDifferencesSum = 0;
    for (NSNumber *score in self)
    {
        meanDifferencesSum += pow(([score doubleValue] - mean), 2); // This was *highly unoptimized* in the original
    }
    
    NSNumber *variance = @(meanDifferencesSum / self.count);
    
    return variance;
}

- (NSNumber *)stdev
{
    return @(sqrt([[self variance] doubleValue]));
}

@end
