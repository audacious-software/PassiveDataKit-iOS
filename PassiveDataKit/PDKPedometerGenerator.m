//
//  PDKPedometerSensor.m
//  PassiveDataKit
//
//  Created by Chris Karr on 6/26/17.
//  Copyright © 2017 Audacious Software. All rights reserved.
//

@import CoreMotion;

#import "PDKPedometerGenerator.h"

@interface PDKPedometerGenerator()

@property NSMutableArray * listeners;
@property NSDictionary * lastOptions;
@property CMPedometer * pedometer;

@end

static PDKPedometerGenerator * sharedObject = nil;

@implementation PDKPedometerGenerator

+ (PDKPedometerGenerator *) sharedInstance {
    static dispatch_once_t _singletonPredicate;
    
    dispatch_once(&_singletonPredicate, ^{
        sharedObject = [[super allocWithZone:nil] init];
        
    });
    
    return sharedObject;
}

+ (id) allocWithZone:(NSZone *) zone { //!OCLINT
    return [self sharedInstance];
}

- (id) init {
    if (self = [super init]) {
        self.listeners = [NSMutableArray array];
        self.pedometer = [[CMPedometer alloc] init];
        
        NSLog(@"isStepCountingAvailable: %@", @([CMPedometer isStepCountingAvailable]));
        NSLog(@"isDistanceAvailable: %@", @([CMPedometer isDistanceAvailable]));
        NSLog(@"isFloorCountingAvailable: %@", @([CMPedometer isFloorCountingAvailable]));
        NSLog(@"isPaceAvailable: %@", @([CMPedometer isPaceAvailable]));
        NSLog(@"isCadenceAvailable: %@", @([CMPedometer isCadenceAvailable]));
        NSLog(@"isPedometerEventTrackingAvailable: %@", @([CMPedometer isPedometerEventTrackingAvailable]));
    }
    
    return self;
}

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options {
    if ([self.listeners containsObject:listener] == NO) {
        [self.listeners addObject:listener];
    }
    
    [self.pedometer stopPedometerEventUpdates];

    if (self.listeners.count > 0) {
        [self.pedometer startPedometerEventUpdatesWithHandler:^(CMPedometerEvent * _Nullable pedometerEvent, NSError * _Nullable error) {
            NSLog(@"EVENT RECV: %@", pedometerEvent);
            NSLog(@"EVENT ERROR: %@", error);
            
            if (error != nil) {
                [self displayError:error];
            }
        }];
        
        [self.pedometer startPedometerUpdatesFromDate:[NSDate date] withHandler:^(CMPedometerData * _Nullable pedometerData, NSError * _Nullable error) {
            NSLog(@"DATA RECV: %@", pedometerData);
            NSLog(@"DATA ERROR: %@", error);

            if (error != nil) {
                [self displayError:error];
            }
        }];
    }
}

- (void) removeListener:(id<PDKDataListener>)listener {
    [self.listeners removeObject:listener];
    
    if (self.listeners.count == 0) {
        [self.pedometer stopPedometerEventUpdates];
        [self.pedometer stopPedometerUpdates];
    }
}

- (void) displayError:(NSError *) error {
    if (error == nil) {
        return;
    }
    
    if (error.code == CMErrorDeviceRequiresMovement) {
        NSLog(@"CMErrorDeviceRequiresMovement");
    } else if (error.code == CMErrorInvalidAction) {
        NSLog(@"CMErrorInvalidAction");
    } else if (error.code == CMErrorInvalidParameter) {
        NSLog(@"CMErrorInvalidParameter");
    } else if (error.code == CMErrorMotionActivityNotAuthorized) {
        NSLog(@"CMErrorMotionActivityNotAuthorized");
    } else if (error.code == CMErrorMotionActivityNotAvailable) {
        NSLog(@"CMErrorMotionActivityNotAvailable");
    } else if (error.code == CMErrorMotionActivityNotEntitled) {
        NSLog(@"CMErrorMotionActivityNotEntitled");
    } else if (error.code == CMErrorNotAuthorized) {
        NSLog(@"CMErrorNotAuthorized");
    } else if (error.code == CMErrorNotAvailable) {
        NSLog(@"CMErrorNotAvailable");
    } else if (error.code == CMErrorNotEntitled) {
        NSLog(@"CMErrorNotEntitled");
    } else if (error.code == CMErrorTrueNorthNotAvailable) {
        NSLog(@"CMErrorTrueNorthNotAvailable");
    } else if (error.code == CMErrorUnknown) {
        NSLog(@"CMErrorUnknown");
    }
}


@end
