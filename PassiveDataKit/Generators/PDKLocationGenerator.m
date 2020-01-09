//
//  PDKLocationGenerator.m
//  PassiveDataKit
//
//  Created by Chris Karr on 5/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

#include <math.h>
#include <sqlite3.h>

#import "DTMHeatMap.h"
#import "DTMHeatmapRenderer.h"

#import "PDKLocationGenerator.h"
#import "PDKLocationAnnotation.h"
#import "PDKLocationGeneratorViewController.h"

#define DATABASE_VERSION @"PDKLocationGenerator.DATABASE_VERSION"
#define CURRENT_DATABASE_VERSION @(1)

NSString * const PDKCapabilityRationale = @"PDKCapabilityRationale"; //!OCLINT
NSString * const PDKLocationAlwaysOn = @"PDKLocationAlwaysOn"; //!OCLINT
NSString * const PDKLocationRequestedAccuracy = @"PDKLocationRequestedAccuracy"; //!OCLINT
NSString * const PDKLocationRequestedDistance = @"PDKLocationRequestedDistance"; //!OCLINT
NSString * const PDKLocationInstance = @"PDKLocationInstance"; //!OCLINT
NSString * const PDKLocationAccessDenied = @"PDKLocationAccessDenied"; //!OCLINT
NSString * const PDKLocationRequestPermission = @"PDKLocationRequestPermission"; //!OCLINT
NSString * const PDKLocationSignificantChangesOnly = @"PDKLocationSignificantChangesOnly";

NSString * const PDKLocationAccuracyMode = @"PDKLocationAccuracyMode"; //!OCLINT
NSString * const PDKLocationAccuracyModeBest = @"PDKLocationAccuracyModeBest"; //!OCLINT
NSString * const PDKLocationAccuracyModeRandomized = @"PDKLocationAccuracyModeRandomized"; //!OCLINT
NSString * const PDKLocationAccuracyModeUserProvided = @"PDKLocationAccuracyModeUserProvided"; //!OCLINT
NSString * const PDKLocationAccuracyModeDisabled = @"PDKLocationAccuracyModeDisabled"; //!OCLINT
NSString * const PDKLocationAccuracyModeUserProvidedDistance = @"PDKLocationAccuracyModeUserProvidedDistance"; //!OCLINT
NSString * const PDKLocationAccuracyModeUserProvidedLatitude = @"PDKLocationAccuracyModeUserProvidedLatitude"; //!OCLINT
NSString * const PDKLocationAccuracyModeUserProvidedLongitude = @"PDKLocationAccuracyModeUserProvidedLongitude"; //!OCLINT

NSString * const PDKLocationLatitude = @"latitude"; //!OCLINT
NSString * const PDKLocationLongitude = @"longitude"; //!OCLINT
NSString * const PDKLocationAltitude = @"altitude"; //!OCLINT
NSString * const PDKLocationAccuracy = @"accuracy"; //!OCLINT
NSString * const PDKLocationAltitudeAccuracy = @"altitude-accuracy"; //!OCLINT
NSString * const PDKLocationFloor = @"floor"; //!OCLINT
NSString * const PDKLocationSpeed = @"speed"; //!OCLINT
NSString * const PDKLocationBearing = @"bearing"; //!OCLINT
NSString * const PDKAuthorizationStatus = @"auth_status"; //!OCLINT

#define GENERATOR_ID @"pdk-location"

@interface PDKLocationGenerator ()

@property NSMutableArray * listeners;
@property CLLocationManager * locationManager;
@property NSDictionary * lastOptions;
@property NSString * mode;

@property (nonatomic, copy) void (^accessDeniedBlock)(void);
@property (nonatomic, copy) void (^accessGrantedBlock)(void);

@property sqlite3 * database;

@property CLLocationCoordinate2D latestLocation;

@property BOOL requestPermissions;

@end

@implementation PDKLocationGenerator

static PDKLocationGenerator * sharedObject = nil;

+ (PDKLocationGenerator *) sharedInstance {
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
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];

    if (self = [super init]) {
        self.listeners = [NSMutableArray array];
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        
        self.mode = [defaults valueForKey:PDKLocationAccuracyMode];
        
        if (self.mode == nil) {
            self.mode = PDKLocationAccuracyModeBest;
        }
        
        [defaults addObserver:self forKeyPath:PDKLocationAccuracyMode options:NSKeyValueObservingOptionNew context:NULL];
        
        self.latestLocation = CLLocationCoordinate2DMake(0, 0);

        self.database = [self openDatabase];
        
        self.requestPermissions = YES;
        
        self.accessGrantedBlock = nil;
        self.accessDeniedBlock = nil;
    }
    
    return self;
}

- (void) refresh:(CLLocation *) location {
    if (location == nil) {
        [self.locationManager requestLocation];
    } else {
        [self locationManager:self.locationManager didUpdateLocations:@[location]];
    }
}

- (NSString *) databasePath {
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString * documentsPath = paths[0];
    
    NSString * dbPath = [documentsPath stringByAppendingPathComponent:@"pdk-location.sqlite3"];
    
    return dbPath;
}

- (sqlite3 *) openDatabase {
    NSString * dbPath = [self databasePath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:dbPath] == NO)
    {
        sqlite3 * database = NULL;
        
        const char * path = [dbPath UTF8String];
        
        int retVal = sqlite3_open_v2(path, &database, SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE|SQLITE_OPEN_FILEPROTECTION_NONE, NULL);
        
        if (retVal == SQLITE_OK) {
            char * error;
            
            const char * createStatement = "CREATE TABLE IF NOT EXISTS location_data (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp REAL, latitude REAL, longitude REAL, altitude REAL, horizontal_accuracy REAL, vertical_accuracy REAL, floor REAL, speed REAL, course REAL)";
            
            if (sqlite3_exec(database, createStatement, NULL, NULL, &error) != SQLITE_OK) { //!OCLINT

            }
            
            sqlite3_close(database);
        }
    }
    
    const char * dbpath = [dbPath UTF8String];
    
    sqlite3 * database = NULL;
    
    if (sqlite3_open(dbpath, &database) == SQLITE_OK) {
        NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
        
        NSNumber * dbVersion = [defaults valueForKey:DATABASE_VERSION];
        
        if (dbVersion == nil) {
            dbVersion = @(0);
        }
        
//        BOOL updated = NO;
//        char * error = NULL;
        
        switch (dbVersion.integerValue) { //!OCLINT
            default:
                break;
        }
        
//        if (updated) {
//            [defaults setValue:CURRENT_DATABASE_VERSION forKey:DATABASE_VERSION];
//        }
        
        return database;
    }
    
    return NULL;
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context {
    if ([PDKLocationAccuracyMode isEqualToString:keyPath]) {
        self.mode = change[NSKeyValueChangeNewKey];

        [self.locationManager stopUpdatingLocation];

        if ([PDKLocationAccuracyModeBest isEqualToString:self.mode]) {
            [self.locationManager startUpdatingLocation];
        } else if ([PDKLocationAccuracyModeRandomized isEqualToString:self.mode]) {
            [self.locationManager startUpdatingLocation];
        } else if ([PDKLocationAccuracyModeUserProvided isEqualToString:self.mode]) {
            [self locationManager:self.locationManager didUpdateLocations:@[]];
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

- (void) updateOptions:(NSDictionary *) options {
    if (options == nil) {
        options = @{}; //!OCLINT
    }

    self.lastOptions = options;

//    NSLog(@"TODO: Update options and refresh generator!");
}

- (void) requestRequiredPermissions:(void (^)(void))callback {
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];

    if (callback != nil) {
        self.accessGrantedBlock = [callback copy];
    }
    
    NSNumber * alwaysOn = [self.lastOptions valueForKey:PDKLocationAlwaysOn];

    if (status == kCLAuthorizationStatusRestricted || status == kCLAuthorizationStatusDenied) { //!OCLINT
        if (self.accessDeniedBlock != nil) {
            self.accessDeniedBlock();
        }
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
    } else if (alwaysOn != nil && alwaysOn.boolValue && status == kCLAuthorizationStatusAuthorizedAlways) {
        self.locationManager.allowsBackgroundLocationUpdates = YES;
        self.locationManager.pausesLocationUpdatesAutomatically = NO;
        
        if (self.accessGrantedBlock != nil) {
            self.accessGrantedBlock();
        }
    } else { //!OCLINT
        self.locationManager.allowsBackgroundLocationUpdates = NO;
        self.locationManager.pausesLocationUpdatesAutomatically = YES;
     
        if (self.accessGrantedBlock != nil) {
            self.accessGrantedBlock();
        }
    }
}

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options {
    if (options == nil) {
        options = @{}; //!OCLINT
    }
    
    NSNumber * requestPermissions = options[PDKRequestPermissions];
    
    if (requestPermissions != nil) {
        self.requestPermissions = requestPermissions.boolValue;
    }
    
    self.lastOptions = options;

    self.accessDeniedBlock = [options valueForKey:PDKLocationAccessDenied];
    
    if (self.listeners.count == 0) {
        // Turn on sensors with options...
        
        if (self.requestPermissions) {
            [self requestRequiredPermissions:nil];
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

- (void)locationManagerDidPauseLocationUpdates:(CLLocationManager *)manager {
    [[PassiveDataKit sharedInstance] logEvent:@"debug_location_updates_paused" properties:nil];
}

- (void)locationManagerDidResumeLocationUpdates:(CLLocationManager *)manager {
    [[PassiveDataKit sharedInstance] logEvent:@"debug_location_updates_resumed" properties:nil];
}

- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    if ([PDKLocationAccuracyModeBest isEqualToString:self.mode] || [PDKLocationAccuracyModeRandomized isEqualToString:self.mode]) {
        for (CLLocation * location in locations) {
            CLLocation * thisLocation = location;

            NSDate * now = thisLocation.timestamp;

            if (self.latestLocation.latitude != thisLocation.coordinate.latitude || self.latestLocation.longitude != thisLocation.coordinate.longitude) {
                self.latestLocation = CLLocationCoordinate2DMake(thisLocation.coordinate.latitude, thisLocation.coordinate.longitude);
                
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
                
                sqlite3_stmt * stmt;
                
                NSString * insert = @"INSERT INTO location_data (timestamp, latitude, longitude, altitude, horizontal_accuracy, vertical_accuracy, floor, speed, course) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);";
                
                int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL);
                
                if (retVal == SQLITE_OK) {
                    if (sqlite3_bind_double(stmt, 1, now.timeIntervalSince1970) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 2, thisLocation.coordinate.latitude) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 3, thisLocation.coordinate.longitude) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 4, thisLocation.altitude) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 5, thisLocation.horizontalAccuracy) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 6, thisLocation.verticalAccuracy) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 7, thisLocation.floor.level) == SQLITE_OK) {
                        
                        if (thisLocation.speed >= 0) {
                            sqlite3_bind_double(stmt, 8, thisLocation.speed);
                            sqlite3_bind_double(stmt, 9, thisLocation.course);
                        } else {
                            sqlite3_bind_double(stmt, 8, 0.0);
                            sqlite3_bind_double(stmt, 9, 0.0);
                        }
                        
                        int retVal = sqlite3_step(stmt);
                        
                        if (SQLITE_DONE != retVal) {
                            NSLog(@"Error while inserting data. %d '%s'", retVal, sqlite3_errmsg(self.database));
                        }
                    }
                    
                    sqlite3_finalize(stmt);
                }
                
                NSMutableDictionary * data = [NSMutableDictionary dictionary];
                [data setValue:now forKey:PDKGeneratedDate];
                [data setValue:[NSNumber numberWithDouble:thisLocation.coordinate.latitude] forKey:PDKLocationLatitude];
                [data setValue:[NSNumber numberWithDouble:thisLocation.coordinate.longitude] forKey:PDKLocationLongitude];
                [data setValue:[NSNumber numberWithDouble:thisLocation.altitude] forKey:PDKLocationAltitude];
                [data setValue:[NSNumber numberWithDouble:thisLocation.horizontalAccuracy] forKey:PDKLocationAccuracy];
                [data setValue:[NSNumber numberWithDouble:thisLocation.verticalAccuracy] forKey:PDKLocationAltitudeAccuracy];
                [data setValue:[NSNumber numberWithInteger:thisLocation.floor.level] forKey:PDKLocationFloor];

                switch ([CLLocationManager authorizationStatus]) {
                    case kCLAuthorizationStatusDenied:
                        [data setValue:@"denied" forKey:PDKAuthorizationStatus];
                        break;
                    case kCLAuthorizationStatusRestricted:
                        [data setValue:@"restricted" forKey:PDKAuthorizationStatus];
                        break;
                    case kCLAuthorizationStatusNotDetermined:
                        [data setValue:@"not_determined" forKey:PDKAuthorizationStatus];
                        break;
                    case kCLAuthorizationStatusAuthorizedAlways:
                        [data setValue:@"always" forKey:PDKAuthorizationStatus];
                        break;
                    case kCLAuthorizationStatusAuthorizedWhenInUse:
                        [data setValue:@"in_use" forKey:PDKAuthorizationStatus];
                        break;
                }
                
                if (thisLocation.speed >= 0) {
                    [data setValue:[NSNumber numberWithDouble:thisLocation.speed] forKey:PDKLocationSpeed];
                    [data setValue:[NSNumber numberWithInteger:thisLocation.course] forKey:PDKLocationBearing];
                }
                
                for (id<PDKDataListener> listener in self.listeners) {
                    [listener receivedData:data forGenerator:PDKLocation];
                }
            }
        }
    } else if ([PDKLocationAccuracyModeUserProvided isEqualToString:self.mode]) {
        NSDate * now = [NSDate date];

        CLLocationDegrees latitude = [defaults doubleForKey:PDKLocationAccuracyModeUserProvidedLatitude];
        CLLocationDegrees longitude = [defaults doubleForKey:PDKLocationAccuracyModeUserProvidedLongitude];

        CLLocation * location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];

        sqlite3_stmt * stmt;
        
        NSString * insert = @"INSERT INTO location_data (timestamp, latitude, longitude, altitude, horizontal_accuracy, vertical_accuracy, floor, speed, course) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);";
        
        int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL);
        
        if (retVal == SQLITE_OK) {
            sqlite3_bind_double(stmt, 1, now.timeIntervalSince1970);
            sqlite3_bind_double(stmt, 2, location.coordinate.latitude);
            sqlite3_bind_double(stmt, 3, location.coordinate.longitude);
            sqlite3_bind_double(stmt, 4, 0);
            sqlite3_bind_double(stmt, 5, 0);
            sqlite3_bind_double(stmt, 6, 0);
            sqlite3_bind_double(stmt, 7, 0);
            sqlite3_bind_double(stmt, 8, 0);
            sqlite3_bind_double(stmt, 9, 0);

            int retVal = sqlite3_step(stmt);
            
            if (SQLITE_DONE != retVal) {
                NSLog(@"Error while inserting data. %d '%s'", retVal, sqlite3_errmsg(self.database));
            }
            
            sqlite3_finalize(stmt);
        }

        NSMutableDictionary * data = [NSMutableDictionary dictionary];
        
        [data setValue:[NSNumber numberWithDouble:location.coordinate.latitude] forKey:PDKLocationLatitude];
        [data setValue:[NSNumber numberWithDouble:location.coordinate.longitude] forKey:PDKLocationLongitude];

        for (id<PDKDataListener> listener in self.listeners) {
            [listener receivedData:data forGenerator:PDKLocation];
        }
    } else if ([PDKLocationAccuracyModeDisabled isEqualToString:self.mode]) { //!OCLINT
        // Do nothing...
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    // TODO: Log error...
    NSLog(@"TODO: LOG LOCATION FAILURE: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus) status {
    if (status != kCLAuthorizationStatusNotDetermined) {
        [self addListener:nil options:self.lastOptions];
    }
    
    if (self.accessGrantedBlock != nil) {
        self.accessGrantedBlock();
        
        if (status != kCLAuthorizationStatusNotDetermined) {
            self.accessGrantedBlock = nil;
        }
    }
}

+ (NSString *) title {
    return NSLocalizedStringFromTableInBundle(@"name_generator_location", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
}

+ (UIViewController *) detailsController {
    return [[PDKLocationGeneratorViewController alloc] init];
}

- (UIView *) visualizationForSize:(CGSize) size {
    MKMapView * mapView = [[MKMapView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    mapView.showsUserLocation = NO;
    mapView.delegate = self;
    mapView.mapType = MKMapTypeHybrid;

    CLLocationDegrees minLat = 90.0;
    CLLocationDegrees maxLat = -90.0;
    CLLocationDegrees minLon = 180.0;
    CLLocationDegrees maxLon = -180.0;
    
    NSMutableDictionary * data = [NSMutableDictionary dictionary];

    sqlite3_stmt * statement = NULL;
    
    NSString * querySQL = @"SELECT L.latitude, L.longitude FROM location_data L";
    
    int retVal = sqlite3_prepare_v2(self.database, [querySQL UTF8String], -1, &statement, NULL);
    
    if (retVal == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            CLLocationDegrees latitude = sqlite3_column_double(statement, 0);
            CLLocationDegrees longitude = sqlite3_column_double(statement, 1);
            
            if (latitude != 0 && longitude != 0) {
                if (minLat > latitude) {
                    minLat = latitude;
                }

                if (maxLat < latitude) {
                    maxLat = latitude;
                }

                if (minLon > longitude) {
                    minLon = longitude;
                }
                
                if (maxLon < longitude) {
                    maxLon = longitude;
                }

                CLLocation * location = [[CLLocation alloc] initWithLatitude:latitude
                                                                   longitude:longitude];
                
                MKMapPoint point = MKMapPointForCoordinate(location.coordinate);
                
                NSValue * pointValue = [NSValue value:&point
                                         withObjCType:@encode(MKMapPoint)];

                if (data[pointValue] == nil) {
                    data[pointValue] = @(1);
                } else {
                    NSNumber * weight = data[pointValue];
                    
                    data[pointValue] = @(weight.integerValue + 1);
                }
            }
        }
        
        sqlite3_finalize(statement);
    }
    
    DTMHeatmap * heatMap = [[DTMHeatmap alloc] init];
    [heatMap setData:data];

    [mapView addOverlay:heatMap];
    
    if ([data allKeys].count > 1) {
        MKCoordinateSpan span = MKCoordinateSpanMake((maxLat - minLat) * 1.25, (maxLon - minLon) * 1.25);
        
        CLLocationCoordinate2D center = CLLocationCoordinate2DMake((maxLat - span.latitudeDelta / 4), maxLon - span.longitudeDelta / 4);
        
        MKCoordinateRegion region = MKCoordinateRegionMake(center, span);
        
        [mapView setRegion:region animated:YES];
    }
    
    return mapView;
}

#pragma mark - MKMapViewDelegate
- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    return [[DTMHeatmapRenderer alloc] initWithOverlay:overlay];
}

- (NSString *) generatorId {
    return GENERATOR_ID;
}

- (CLLocation *) lastKnownLocation {
    CLLocationDegrees latitude = 40.7128;
    CLLocationDegrees longitude = -74.0059;

    sqlite3_stmt * statement = NULL;
    
    NSString * querySQL = @"SELECT L.latitude, L.longitude FROM location_data L ORDER BY L.timestamp DESC LIMIT 1";
    
    int retVal = sqlite3_prepare_v2(self.database, [querySQL UTF8String], -1, &statement, NULL);
    
    if (retVal == SQLITE_OK)
    {
        if (sqlite3_step(statement) == SQLITE_ROW)
        {
            latitude = sqlite3_column_double(statement, 0);
            longitude = sqlite3_column_double(statement, 1);
        }
        
        sqlite3_finalize(statement);
    }
    
    return [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
}

- (CLLocation *) earliestKnownLocation {
    CLLocationDegrees latitude = 40.7128;
    CLLocationDegrees longitude = -74.0059;
    
    NSTimeInterval timestamp = 0;
    
    sqlite3_stmt * statement = NULL;
    
    NSString * querySQL = @"SELECT L.latitude, L.longitude, L.timestamp FROM location_data L ORDER BY L.timestamp LIMIT 1";
    
    int retVal = sqlite3_prepare_v2(self.database, [querySQL UTF8String], -1, &statement, NULL);
    
    if (retVal == SQLITE_OK)
    {
        if (sqlite3_step(statement) == SQLITE_ROW)
        {
            latitude = sqlite3_column_double(statement, 0);
            longitude = sqlite3_column_double(statement, 1);
            timestamp = sqlite3_column_double(statement, 2);
        }
        
        sqlite3_finalize(statement);
    }
    
    CLLocation * location = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude)
                                                          altitude:0
                                                horizontalAccuracy:0
                                                  verticalAccuracy:0
                                                         timestamp:[NSDate dateWithTimeIntervalSince1970:timestamp]];

    return location;
}

- (NSArray *) locationsSince:(NSDate *) startDate {
    NSMutableArray * locations = [NSMutableArray array];
    
    NSTimeInterval timestamp = [startDate timeIntervalSince1970];
    
    sqlite3_stmt * statement = NULL;
    
    NSString * querySQL = @"SELECT L.latitude, L.longitude, L.timestamp FROM location_data L WHERE L.timestamp > ?";
    
    int retVal = sqlite3_prepare_v2(self.database, [querySQL UTF8String], -1, &statement, NULL);
    
    if (retVal == SQLITE_OK)
    {
        retVal = sqlite3_bind_double(statement, 1, (double) timestamp);
        
        if (retVal == SQLITE_OK)
        {
            while (sqlite3_step(statement) == SQLITE_ROW)
            {
                double latitude = sqlite3_column_double(statement, 0);
                double longitude = sqlite3_column_double(statement, 1);
                double timestamp = sqlite3_column_double(statement, 2);

                CLLocation * loc = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude)
                                                                 altitude:0
                                                       horizontalAccuracy:0
                                                         verticalAccuracy:0
                                                                   course:0
                                                                    speed:0
                                                                timestamp:[NSDate dateWithTimeIntervalSince1970:timestamp]];
                
                [locations addObject:loc];
            }
            
            sqlite3_finalize(statement);
        }
    }

    return locations;
}

- (NSArray *) locationsFrom:(NSDate *) startDate to:(NSDate *) endDate {
    NSMutableArray * locations = [NSMutableArray array];
    
    NSTimeInterval start = [startDate timeIntervalSince1970];
    NSTimeInterval end = [endDate timeIntervalSince1970];

    sqlite3_stmt * statement = NULL;
    
    NSString * querySQL = @"SELECT L.latitude, L.longitude, L.timestamp FROM location_data L WHERE (L.timestamp >= ? AND L.timestamp <= ?)";
    
    int retVal = sqlite3_prepare_v2(self.database, [querySQL UTF8String], -1, &statement, NULL);
    
    if (retVal == SQLITE_OK) {
        retVal = sqlite3_bind_double(statement, 1, (double) start);
        
        if (retVal == SQLITE_OK) {
            retVal = sqlite3_bind_double(statement, 2, (double) end);
            
            if (retVal == SQLITE_OK)
            {
                while (sqlite3_step(statement) == SQLITE_ROW)
                {
                    double latitude = sqlite3_column_double(statement, 0);
                    double longitude = sqlite3_column_double(statement, 1);
                    double timestamp = sqlite3_column_double(statement, 2);
                    
                    CLLocation * loc = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude)
                                                                     altitude:0
                                                           horizontalAccuracy:0
                                                             verticalAccuracy:0
                                                                       course:0
                                                                        speed:0
                                                                    timestamp:[NSDate dateWithTimeIntervalSince1970:timestamp]];
                    
                    [locations addObject:loc];
                }
                
                sqlite3_finalize(statement);
            }
        }
    }
    
    return locations;
}

- (void) startUpdates {
    [self.locationManager startUpdatingLocation];
}

- (void) stopUpdates {
    [self.locationManager stopUpdatingLocation];
}

@end
