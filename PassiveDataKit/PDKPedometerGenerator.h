//
//  PDKPedometerSensor.h
//  PassiveDataKit
//
//  Created by Chris Karr on 6/26/17.
//  Copyright © 2017 Audacious Software. All rights reserved.
//

@import Foundation;
@import CoreMotion;

#import "PDKBaseGenerator.h"

extern NSString *const PDKPedometerDailySummaryDataEnabled;

@interface PDKPedometerGenerator : PDKBaseGenerator


+ (PDKPedometerGenerator *) sharedInstance;

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options;

- (CGFloat) stepsBetweenStart:(NSTimeInterval) start end:(NSTimeInterval) end;
- (void) historicalStepsBetweenStart:(NSTimeInterval) start end:(NSTimeInterval) end withHandler:(CMPedometerHandler)handler;

- (void) refresh;

@end
