//
//  PDKLocationGenerator.m
//  PassiveDataKit
//
//  Created by Chris Karr on 5/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

@import MapKit;

#import "PDKLocationGenerator.h"
#import "PDKLocationAnnotation.h"

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
    NSLog(@"LOCATION UPDATE");
    
    for (CLLocation * location in locations) {
        NSMutableDictionary * log = [NSMutableDictionary dictionary];
        [log setValue:[NSDate date] forKey:@"recorded"];
        [log setValue:[NSNumber numberWithDouble:location.coordinate.latitude] forKey:@"latitude"];
        [log setValue:[NSNumber numberWithDouble:location.coordinate.longitude] forKey:@"longitude"];

        [PDKLocationGenerator logForReview:log];

        NSMutableDictionary * data = [NSMutableDictionary dictionary];
        
        [data setValue:location forKey:PDKLocationInstance];
        
        for (id<PDKDataListener> listener in self.listeners) {
            [listener receivedData:data forGenerator:PDKLocation];
        }
    }
}

+ (void) logForReview:(NSDictionary *) payload {
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    
    NSString * key = @"PDKLocationGeneratorReviewPoints";
    
    NSArray * reviewPoints = [defaults valueForKey:key];
    
    NSMutableArray * newPoints = [NSMutableArray array];
    
    if (reviewPoints != nil) {
        for (NSDictionary * point in reviewPoints) {
            if (point[@"recorded"] != nil) {
                [newPoints addObject:point];
            }
        }
    }
    
    NSMutableDictionary * reviewPoint = [NSMutableDictionary dictionaryWithDictionary:payload];
    [reviewPoint setValue:[NSDate date] forKey:@"recorded"];
    
    [newPoints addObject:reviewPoint];
    
    [newPoints sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj2[@"recorded"] compare:obj1[@"recorded"]];
    }];
    
    while (newPoints.count > 50) {
        [newPoints removeObjectAtIndex:(newPoints.count - 1)];
    }
    
    [defaults setValue:newPoints forKey:key];
    [defaults synchronize];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    // TODO: Log error...
    NSLog(@"TODO: LOG LOCATION FAILURE: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    [self addListener:nil options:self.lastOptions];
}

+ (NSString *) title {
    return NSLocalizedStringFromTableInBundle(@"name_generator_location", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
}

+ (UIView *) visualizationForSize:(CGSize) size {
    MKMapView * mapView = [[MKMapView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    mapView.showsUserLocation = NO;

    CLLocationDegrees minLat = 90.0;
    CLLocationDegrees maxLat = -90.0;
    CLLocationDegrees minLon = 180.0;
    CLLocationDegrees maxLon = -180.0;
    
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSArray * points = [defaults valueForKey:@"PDKLocationGeneratorReviewPoints"];
    
    NSInteger count = 0;
    
    for (NSDictionary * point in points) {
        NSDate * recorded = [point valueForKey:@"recorded"];
        NSNumber * latitude = [point valueForKey:@"latitude"];
        NSNumber * longitude = [point valueForKey:@"longitude"];
        
        if (latitude.doubleValue < minLat) {
            minLat = latitude.doubleValue;
        }
        if (longitude.doubleValue < minLon) {
            minLon = longitude.doubleValue;
        }
        if (latitude.doubleValue > maxLat) {
            maxLat = latitude.doubleValue;
        }
        if (longitude.doubleValue > maxLon) {
            maxLon = longitude.doubleValue;
        }

        CLLocation * location = [[CLLocation alloc] initWithLatitude:latitude.doubleValue longitude:longitude.doubleValue];
        
        PDKLocationAnnotation * note = [[PDKLocationAnnotation alloc] initWithLocation:location forDate:recorded];
        
        [mapView addAnnotation:note];
        
        count += 1;
    }
    
    NSLog(@"MAP COUNT %d", (int) count);
    
    if (count > 1) {
        MKCoordinateSpan span = MKCoordinateSpanMake((maxLat - minLat) * 1.25, (maxLon - minLon) * 1.25);
        
        CLLocationCoordinate2D center = CLLocationCoordinate2DMake((maxLat - span.latitudeDelta / 4), maxLon - span.longitudeDelta / 4);
        
        MKCoordinateRegion region = MKCoordinateRegionMake(center, span);
        
        [mapView setRegion:region animated:YES];
    }
    
    return mapView;
}

@end
