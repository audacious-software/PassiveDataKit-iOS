//
//  PDKPedometerSensor.h
//  PassiveDataKit
//
//  Created by Chris Karr on 6/26/17.
//  Copyright © 2017 Audacious Software. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>

#import "PDKBaseGenerator.h"

extern NSString *const PDKPedometerDailySummaryDataEnabled;

@interface PDKPedometerGenerator : PDKBaseGenerator<UITableViewDelegate, UITableViewDataSource>


+ (PDKPedometerGenerator *) sharedInstance;

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options;

- (void) stepsBetweenStart:(NSTimeInterval) start end:(NSTimeInterval) end callback:(void (^)(NSTimeInterval start, NSTimeInterval end, CGFloat steps)) callback force:(BOOL) force;
- (void) historicalStepsBetweenStart:(NSTimeInterval) start end:(NSTimeInterval) end withHandler:(CMPedometerHandler)handler;

- (BOOL) isAuthorized;

- (void) refresh;

- (void) requestRequiredPermissions:(void (^)(void))callback;

@end
