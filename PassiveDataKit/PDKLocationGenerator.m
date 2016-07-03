//
//  PDKLocationGenerator.m
//  PassiveDataKit
//
//  Created by Chris Karr on 5/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

#include <math.h>

@import MapKit;

#import "PDKLocationGenerator.h"
#import "PDKLocationAnnotation.h"
#import "PDKLocationGeneratorViewController.h"

@interface PDKLocationGenerator ()

@property NSMutableArray * listeners;
@property CLLocationManager * locationManager;
@property NSDictionary * lastOptions;
@property NSString * mode;

@end

NSString * const PDKLocationAccuracyMode = @"PDKLocationAccuracyMode"; //!OCLINT
NSString * const PDKLocationAccuracyModeBest = @"PDKLocationAccuracyModeBest"; //!OCLINT
NSString * const PDKLocationAccuracyModeRandomized = @"PDKLocationAccuracyModeRandomized"; //!OCLINT
NSString * const PDKLocationAccuracyModeUserProvided = @"PDKLocationAccuracyModeUserProvided"; //!OCLINT
NSString * const PDKLocationAccuracyModeDisabled = @"PDKLocationAccuracyModeDisabled"; //!OCLINT
NSString * const PDKLocationAccuracyModeUserProvidedDistance = @"PDKLocationAccuracyModeUserProvidedDistance"; //!OCLINT
NSString * const PDKLocationAccuracyModeUserProvidedLatitude = @"PDKLocationAccuracyModeUserProvidedLatitude"; //!OCLINT
NSString * const PDKLocationAccuracyModeUserProvidedLongitude = @"PDKLocationAccuracyModeUserProvidedLongitude"; //!OCLINT

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
        
        self.mode = [[NSUserDefaults standardUserDefaults] valueForKey:PDKLocationAccuracyMode];
        
        if (self.mode == nil) {
            self.mode = PDKLocationAccuracyModeBest;
        }
        
        [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PDKLocationAccuracyMode options:NSKeyValueObservingOptionNew context:NULL];
    }
    
    return self;
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context {
    if ([PDKLocationAccuracyMode isEqualToString:keyPath]) {
        self.mode = change[NSKeyValueChangeNewKey];
        
        if ([PDKLocationAccuracyModeBest isEqualToString:self.mode]) {
            [self.locationManager startUpdatingLocation];
        } else if ([PDKLocationAccuracyModeRandomized isEqualToString:self.mode]) {
            [self.locationManager startUpdatingLocation];
        } else if ([PDKLocationAccuracyModeUserProvided isEqualToString:self.mode]) {
            [self.locationManager stopUpdatingLocation];
            [self locationManager:self.locationManager didUpdateLocations:@[]];
        } else if ([PDKLocationAccuracyModeDisabled isEqualToString:self.mode]) {
            [self.locationManager stopUpdatingLocation];
        }
    }
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
        
        if ([PDKLocationAccuracyModeBest isEqualToString:self.mode] || [PDKLocationAccuracyModeRandomized isEqualToString:self.mode]){
            [self.locationManager startUpdatingLocation];
        }
    }
    
    if (listener != nil) {
        [self.listeners addObject:listener];
    }
    
    if (self.locationManager.location != nil) {
        [self locationManager:self.locationManager didUpdateLocations:@[self.locationManager.location]];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    
    if ([PDKLocationAccuracyModeBest isEqualToString:self.mode] || [PDKLocationAccuracyModeRandomized isEqualToString:self.mode]) {
        for (CLLocation * location in locations) {
            CLLocation * thisLocation = location;
            
            if ([PDKLocationAccuracyModeRandomized isEqualToString:self.mode]) {
                // http://gis.stackexchange.com/a/68275/10230
                
                CGFloat radius = [defaults doubleForKey:PDKLocationAccuracyModeUserProvidedDistance];

                // Convert radius from meters to degrees
                CGFloat radiusInDegrees = radius / 111000;
                
                CGFloat u = ((CGFloat) rand() / (CGFloat) RAND_MAX); //!OCLINT
                CGFloat v = ((CGFloat) rand() / (CGFloat) RAND_MAX); //!OCLINT

                CGFloat w = radiusInDegrees * sqrt(u); //!OCLINT
                CGFloat t = 2 * M_PI * v; //!OCLINT
                CGFloat x = w * cos(t); //!OCLINT
                CGFloat y = w * sin(t); //!OCLINT
                
                // Adjust the x-coordinate for the shrinking of the east-west distances
                CGFloat new_x = x / cos(location.coordinate.latitude);
                
                CGFloat foundLongitude = new_x + location.coordinate.longitude;
                CGFloat foundLatitude = y + location.coordinate.latitude;
                
                thisLocation = [[CLLocation alloc] initWithLatitude:foundLatitude longitude:foundLongitude];
            }

            NSMutableDictionary * log = [NSMutableDictionary dictionary];
            [log setValue:[NSDate date] forKey:@"recorded"];
            [log setValue:[NSNumber numberWithDouble:thisLocation.coordinate.latitude] forKey:@"latitude"];
            [log setValue:[NSNumber numberWithDouble:thisLocation.coordinate.longitude] forKey:@"longitude"];
            
            [PDKLocationGenerator logForReview:log];
            
            NSMutableDictionary * data = [NSMutableDictionary dictionary];
            
            [data setValue:location forKey:PDKLocationInstance];
            
            for (id<PDKDataListener> listener in self.listeners) {
                [listener receivedData:data forGenerator:PDKLocation];
            }
        }
    } else if ([PDKLocationAccuracyModeUserProvided isEqualToString:self.mode]) {
        CLLocationDegrees latitude = [defaults doubleForKey:PDKLocationAccuracyModeUserProvidedLatitude];
        CLLocationDegrees longitude = [defaults doubleForKey:PDKLocationAccuracyModeUserProvidedLongitude];

        CLLocation * location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
        
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
    } else if ([PDKLocationAccuracyModeDisabled isEqualToString:self.mode]) { //!OCLINT
        // Do nothing...
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

+ (UIViewController *) detailsController {
    return [[PDKLocationGeneratorViewController alloc] init];
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
    
    if (count > 1) {
        MKCoordinateSpan span = MKCoordinateSpanMake((maxLat - minLat) * 1.25, (maxLon - minLon) * 1.25);
        
        CLLocationCoordinate2D center = CLLocationCoordinate2DMake((maxLat - span.latitudeDelta / 4), maxLon - span.longitudeDelta / 4);
        
        MKCoordinateRegion region = MKCoordinateRegionMake(center, span);
        
        [mapView setRegion:region animated:YES];
    }
    
    return mapView;
}

@end
