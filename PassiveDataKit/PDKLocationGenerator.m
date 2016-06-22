//
//  PDKLocationGenerator.m
//  PassiveDataKit
//
//  Created by Chris Karr on 5/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

#import "PDKLocationGenerator.h"

@interface PDKLocationGenerator ()

@property NSMutableArray * listeners;
@property CLLocationManager * locationManager;
@property NSDictionary * lastOptions;

@end

@implementation PDKLocationGenerator

static PDKLocationGenerator * sharedObject = nil;

+ (PDKLocationGenerator *) sharedInstance
{
    static dispatch_once_t _singletonPredicate;
    
    dispatch_once(&_singletonPredicate, ^{
        sharedObject = [[super allocWithZone:nil] init];
        
    });
    
    return sharedObject;
}

+ (id) allocWithZone:(NSZone *) zone //!OCLINT
{
    return [self sharedInstance];
}

- (id) init
{
    if (self = [super init])
    {
        self.listeners = [NSMutableArray array];
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
    }
    
    return self;
}

- (void) removeListener:(id<PDKDataListener>)listener {
    [self.listeners removeObject:listener];
    
    if (self.listeners.count == 0) {
        // Shut down sensors...

        [self.locationManager stopMonitoringSignificantLocationChanges];
        [self.locationManager stopUpdatingLocation];
    }
}


- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options {
    if (options == nil) {
        options = @{}; //!OCLINT
    }
    
    self.lastOptions = options;
    
    if (self.listeners.count == 0) {
        // Turn on sensors with options...
     
        NSNumber * alwaysOn = [options valueForKey:PDKLocationAlwaysOn];

        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        
        if (status == kCLAuthorizationStatusRestricted || status == kCLAuthorizationStatusDenied) { //!OCLINT
            // Do nothing - user shut off location services...
        } else if (status == kCLAuthorizationStatusNotDetermined) {
            if (alwaysOn != nil && alwaysOn.boolValue) {
                [self.locationManager requestAlwaysAuthorization];
            } else {
                [self.locationManager requestWhenInUseAuthorization];
            }
        } else if (alwaysOn != nil && alwaysOn.boolValue && status != kCLAuthorizationStatusAuthorizedAlways) {
            [self.locationManager requestAlwaysAuthorization];
        } else if ((alwaysOn == nil || alwaysOn.boolValue == NO) && status != kCLAuthorizationStatusAuthorizedWhenInUse) {
            [self.locationManager requestWhenInUseAuthorization];
        }
        else { //!OCLINT
            // Already authed -- do nothing...
        }
    }
    
    NSNumber * monitorSignificant = [options valueForKey:PDKLocationSignificantChangesOnly];
    
    if (monitorSignificant != nil && [monitorSignificant boolValue]) {
        [self.locationManager startMonitoringSignificantLocationChanges];
    } else {
        CLLocationDistance distance = 1000;
        
        NSNumber * optionDistance = [options valueForKey:PDKLocationRequestedDistance];
        
        if (optionDistance != nil) {
            distance = [optionDistance doubleValue];
        }
        
        if (self.locationManager.distanceFilter < distance) {
            self.locationManager.distanceFilter = distance;
        }

        CLLocationAccuracy accuracy = 1000;

        NSNumber * optionAccuracy = [options valueForKey:PDKLocationRequestedAccuracy];
        
        if (optionAccuracy != nil) {
            accuracy = [optionAccuracy doubleValue];
        }
        
        if (self.locationManager.desiredAccuracy > accuracy) {
            self.locationManager.desiredAccuracy = accuracy;
        }
        
        [self.locationManager startUpdatingLocation];
    }
    
    if (listener != nil) {
        [self.listeners addObject:listener];
    }
    
    if (self.locationManager.location != nil) {
        [self locationManager:self.locationManager didUpdateLocations:@[self.locationManager.location]];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    for (CLLocation * location in locations) {
        NSMutableDictionary * data = [NSMutableDictionary dictionary];
        
        [data setValue:location forKey:PDKLocationInstance];
        
        for (id<PDKDataListener> listener in self.listeners) {
            [listener receivedData:data forGenerator:PDKLocation];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    // TODO: Log error...
    NSLog(@"TODO: LOG LOCATION FAILURE: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    [self addListener:nil options:self.lastOptions];
}


@end
