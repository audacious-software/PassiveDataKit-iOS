//
//  PDKBaseGenerator.m
//  PassiveDataKit
//
//  Created by Chris Karr on 6/18/17.
//  Copyright © 2017 Audacious Software. All rights reserved.
//

#import "PDKBaseGenerator.h"

#define GENERATOR_ID @"pdk-base-generator"

@implementation PDKBaseGenerator

- (NSString *) fullGeneratorName {
    return [NSString stringWithFormat:@"%@: %@", [self generatorId], [[PassiveDataKit sharedInstance] userAgent]];
}

- (NSString *) generatorId {
    return GENERATOR_ID;
}

- (void) updateOptions:(NSDictionary *) options {
    NSLog(@"Implement %@ in subclass... (%@)", NSStringFromSelector(_cmd), [self generatorId]);
}

- (UIView *) visualizationForSize:(CGSize) size {
    NSLog(@"Implement %@ in subclass... (%@)", NSStringFromSelector(_cmd), [self generatorId]);

    return nil;
}

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options {
    NSLog(@"Implement %@ in subclass... (%@)", NSStringFromSelector(_cmd), [self generatorId]);
}

- (void) removeListener:(id<PDKDataListener>) listener { //!OCLINT
    NSLog(@"Implement %@ in subclass... (%@)", NSStringFromSelector(_cmd), [self generatorId]);
}

- (void) setCachedDataRetentionPeriod:(NSTimeInterval) period { //!OCLINT
    NSLog(@"Implement %@ in subclass... (%@)", NSStringFromSelector(_cmd), [self generatorId]);
}

- (void) flushCachedData {
    NSLog(@"Implement %@ in subclass... (%@)", NSStringFromSelector(_cmd), [self generatorId]);
}

@end
