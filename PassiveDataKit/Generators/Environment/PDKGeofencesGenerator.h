//
//  PDKGeofencesGenerator.h
//  PassiveDataKit
//
//  Created by Chris Karr on 2/17/19.
//  Copyright © 2019 Audacious Software. All rights reserved.
//

@import Foundation;
@import CoreLocation;

#import "PDKBaseGenerator.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PDKGeofencesURL;

@interface PDKGeofencesGenerator : PDKBaseGenerator<CLLocationManagerDelegate>

+ (PDKGeofencesGenerator *) sharedInstance;

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options;

- (NSArray *) cachedGeofences;
- (void) reloadGeofences:(void (^)(void)) callback;

- (CGFloat) minutesWithin:(NSString *) identifier start:(NSDate *) windowStart end:(NSDate *) windowEnd;

@end

NS_ASSUME_NONNULL_END
