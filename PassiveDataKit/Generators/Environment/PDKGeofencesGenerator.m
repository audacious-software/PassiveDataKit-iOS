//
//  PDKGeofencesGenerator.m
//  PassiveDataKit
//
//  Created by Chris Karr on 2/17/19.
//  Copyright © 2019 Audacious Software. All rights reserved.
//

#include <sqlite3.h>

@import AFNetworking;

#import "PDKGeofencesGenerator.h"

#define GENERATOR_ID @"pdk-geofences"

#define DATABASE_VERSION @"PDKGeofencesGenerator.DATABASE_VERSION"
#define CURRENT_DATABASE_VERSION @(1)

#define CACHED_GEOFENCES @"PDKGeofencesGenerator.CACHED_GEOFENCES"

#define LOCATION_LAST_UPDATED @"PDKGeofencesGenerator.LOCATION_LAST_UPDATED"
#define LOCATION_LAST_LATITUDE @"PDKGeofencesGenerator.LOCATION_LAST_LATITUDE"
#define LOCATION_LAST_LONGITUDE @"PDKGeofencesGenerator.LOCATION_LAST_LONGITUDE"

#define REFRESH_GEOFENCE_MINIMUM_INTERVAL (60 * 5)
#define FORCE_RELOAD_GEOFENCES @"PDKGeofencesGenerator.FORCE_RELOAD_GEOFENCES"

#define ACTIVE_FENCE_LIMIT 16

#define RETENTION_PERIOD @"PDKGeofencesGenerator.RETENTION_PERIOD"
#define RETENTION_PERIOD_DEFAULT (90 * 24 * 60 * 60)

NSString * const PDKGeofencesURL = @"PDKGeofencesURL"; //!OCLINT

NSString * const PDKGeofenceTransitionInside = @"enter"; //!OCLINT
NSString * const PDKGeofenceTransitionOutside = @"exit"; //!OCLINT
NSString * const PDKGeofenceTransitionUnknown = @"unknown"; //!OCLINT

NSString * const PDKGeofenceIdentifier = @"identifier"; //!OCLINT
NSString * const PDKGeofenceDetails = @"fence_details"; //!OCLINT
NSString * const PDKGeofenceTransition = @"transition"; //!OCLINT

/*
NSString * const PDKSystemStatusRuntime = @"runtime"; //!OCLINT
NSString * const PDKSystemStatusStorageApp = @"storage_app"; //!OCLINT
NSString * const PDKSystemStatusStorageOther = @"storage_other"; //!OCLINT
NSString * const PDKSystemStatusStorageAvailable = @"storage_available"; //!OCLINT
NSString * const PDKSystemStatusStorageTotal = @"storage_total"; //!OCLINT
*/

@interface PDKGeofencesGenerator()

@property CLLocationManager * locationManager;
@property NSMutableArray * listeners;
@property NSDictionary * lastOptions;

@property sqlite3 * database;

@end

static PDKGeofencesGenerator * sharedObject = nil;

@implementation PDKGeofencesGenerator

+ (PDKGeofencesGenerator *) sharedInstance {
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
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.allowsBackgroundLocationUpdates = YES;
        self.locationManager.pausesLocationUpdatesAutomatically = NO;

        if (@available(iOS 11.0, *)) {
            self.locationManager.showsBackgroundLocationIndicator = NO;
        } else {
            // Fallback on earlier versions
        }

        self.database = [self openDatabase];
    }
    
    return self;
}

- (NSString *) databasePath {
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString * documentsPath = paths[0];
    
    NSString * dbPath = [documentsPath stringByAppendingPathComponent:@"pdk-geofences"];
    
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
            
            const char * createStatement = "CREATE TABLE history(_id INTEGER PRIMARY KEY AUTOINCREMENT, fetched INTEGER, transmitted INTEGER, observed INTEGER, transition TEXT, metadata_json TEXT, identifier TEXT);";
            
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

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options {
    if (self.listeners.count == 0) {
        [self.locationManager startMonitoringSignificantLocationChanges];
    }

    if ([self.listeners containsObject:listener] == NO) {
        [self.listeners addObject:listener];
    }
    
    if (options[PDKGeofencesURL] != nil) {
        [self setFencesURL:[NSURL URLWithString:options[PDKGeofencesURL]]];

        [self reloadGeofences:^{
            
        }];
    }
}

- (void) removeListener:(id<PDKDataListener>)listener {
    [self.listeners removeObject:listener];

    if (self.listeners.count == 0) {
        [self.locationManager stopMonitoringSignificantLocationChanges];
    }
}

- (NSString *) generatorId {
    return GENERATOR_ID;
}

+ (NSString *) title {
    return NSLocalizedStringFromTableInBundle(@"name_generator_geofences", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
}

- (void) setFencesURL:(NSURL *) fencesUrl {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    [defaults setValue:fencesUrl.description forKey:PDKGeofencesURL];
    
    [defaults synchronize];
}

- (CLLocation *) lastKnownLocation {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    NSNumber * latitude = [defaults valueForKey:LOCATION_LAST_LATITUDE];
    
    if (latitude == nil) {
        latitude = @(0);
    }
    
    NSNumber * longitude = [defaults valueForKey:LOCATION_LAST_LONGITUDE];

    if (longitude == nil) {
        longitude = @(0);
    }
    
    return [[CLLocation alloc] initWithLatitude:latitude.doubleValue longitude:longitude.doubleValue];
}

- (void) reloadGeofences:(void (^)(void)) callback {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    if ([defaults valueForKey:PDKGeofencesURL] != nil) {
        AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
        
        [manager GET:[defaults valueForKey:PDKGeofencesURL]
          parameters:@{}
            progress:^(NSProgress * _Nonnull downloadProgress) {

            } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                [defaults setValue:responseObject[@"features"] forKey:CACHED_GEOFENCES];
                [defaults setValue:@(YES) forKey:FORCE_RELOAD_GEOFENCES];
                [defaults removeObjectForKey:LOCATION_LAST_UPDATED];
                [defaults synchronize];

                [self.locationManager requestLocation];

                if (callback != nil) {
                    callback();
                }
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                if (callback != nil) {
                    callback();
                }
            }];
    }
}

- (NSArray *) cachedGeofences {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    NSArray * fences = [defaults valueForKey:CACHED_GEOFENCES];
    
    if (fences == nil) {
        fences = @[];
    }
    
    return fences;
}

- (void)locationManagerDidPauseLocationUpdates:(CLLocationManager *)manager {
    [[PassiveDataKit sharedInstance] logEvent:@"debug_geofences_location_updates_paused" properties:nil];
}

- (void)locationManagerDidResumeLocationUpdates:(CLLocationManager *)manager {
    [[PassiveDataKit sharedInstance] logEvent:@"debug_geofences_location_updates_resumed" properties:nil];
}

- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    NSNumber * forceReload = [defaults valueForKey:FORCE_RELOAD_GEOFENCES];
    
    if (forceReload == nil) {
        forceReload = @(NO);
    }
    
    CLLocation * lastLocation = locations.lastObject;
    [defaults setValue:@(lastLocation.coordinate.latitude) forKey:LOCATION_LAST_LATITUDE];
    [defaults setValue:@(lastLocation.coordinate.longitude) forKey:LOCATION_LAST_LONGITUDE];
    [defaults synchronize];
    
    NSDate * now = [NSDate date];

    NSDate * lastUpdate = [defaults valueForKey:LOCATION_LAST_UPDATED];
    
    if (forceReload.boolValue || lastUpdate == nil) {
        lastUpdate = [NSDate dateWithTimeIntervalSince1970:0];
    }
    
    if (now.timeIntervalSince1970 - lastUpdate.timeIntervalSince1970 > REFRESH_GEOFENCE_MINIMUM_INTERVAL) {
        [defaults setValue:now forKey:LOCATION_LAST_UPDATED];
        [defaults synchronize];

        [self loadNearestRegions:lastLocation forceReload:forceReload.boolValue];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    // TODO: Log error...
    NSLog(@"TODO: LOG LOCATION/GEOFENCES FAILURE: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {

}

- (void) loadNearestRegions:(CLLocation *) here forceReload:(BOOL) forceReload {
    NSMutableSet * monitoredIdentifiers = [NSMutableSet set];
    NSMutableDictionary * monitoredRegions = [NSMutableDictionary dictionary];
    
    if (forceReload == NO) {
        for (CLRegion * region in self.locationManager.monitoredRegions) {
            [monitoredIdentifiers addObject:region.identifier];
            
            monitoredRegions[region.identifier] = region;
        }
    }
    
    NSMutableArray * cachedRegions = [NSMutableArray arrayWithArray:[self cachedGeofences]];
    
    [cachedRegions sortUsingComparator:^NSComparisonResult(id  _Nonnull one, id  _Nonnull two) {
        NSArray * oneCoords = one[@"geometry"][@"coordinates"];
        
        CLLocation * oneHere = [[CLLocation alloc] initWithLatitude:[oneCoords[1] doubleValue]
                                                          longitude:[oneCoords[0] doubleValue]];
        
        NSArray * twoCoords = two[@"geometry"][@"coordinates"];
        
        CLLocation * twoHere = [[CLLocation alloc] initWithLatitude:[twoCoords[1] doubleValue]
                                                          longitude:[twoCoords[0] doubleValue]];
        
        CLLocationDistance oneDistance = [oneHere distanceFromLocation:here];
        CLLocationDistance twoDistance = [twoHere distanceFromLocation:here];
        
        return [@(oneDistance) compare:@(twoDistance)];
    }];

    NSMutableSet * newIdentifiers = [NSMutableSet set];
    NSMutableDictionary * newRegions = [NSMutableDictionary dictionary];

    for (NSDictionary * region in cachedRegions) {
        if (newIdentifiers.count < ACTIVE_FENCE_LIMIT) {
            NSString * identifier = [NSString stringWithFormat:@"geofence-%@", region[@"properties"][@"identifier"]];
            
            [newIdentifiers addObject:identifier];
            newRegions[identifier] = region;
        }
    }

    NSMutableArray * addedRegions = [NSMutableArray array];
    
    if ([monitoredIdentifiers isEqualToSet:newIdentifiers] == NO) {
        for (NSString * identifier in monitoredIdentifiers) {
            [self.locationManager stopMonitoringForRegion:monitoredRegions[identifier]];
        }

        for (NSString * identifier in newIdentifiers) {
            NSDictionary * region = newRegions[identifier];
            
            NSArray * coords = region[@"geometry"][@"coordinates"];
            
            CLLocationCoordinate2D coordinate;
            coordinate.latitude = [coords[1] doubleValue];
            coordinate.longitude = [coords[0] doubleValue];
            
            CLLocationDistance radius = [region[@"properties"][@"radius"] doubleValue];
            
            CLCircularRegion * circle = [[CLCircularRegion alloc] initWithCenter:coordinate
                                                                          radius:radius
                                                                      identifier:identifier];
            
            [self.locationManager startMonitoringForRegion:circle];
            
            [addedRegions addObject:circle];
        }
    }
    
    for (CLCircularRegion * circle in addedRegions) {
        [self.locationManager requestStateForRegion:circle];
    }
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    [self recordState:CLRegionStateInside forRegion:region];
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    [self recordState:CLRegionStateOutside forRegion:region];
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
    [self recordState:state forRegion:region];
}

- (void) recordState:(CLRegionState) state forRegion:(CLRegion *) region {
    NSDate * now = [NSDate date];
    
    NSString * stateDesc = PDKGeofenceTransitionUnknown;
    
    switch(state) {
        case CLRegionStateInside:
            stateDesc = PDKGeofenceTransitionInside;
            break;
        case CLRegionStateOutside:
            stateDesc = PDKGeofenceTransitionOutside;
            break;
        case CLRegionStateUnknown:
            stateDesc = PDKGeofenceTransitionUnknown;
            break;
    }
    
    sqlite3_stmt * stmt;
    
    NSString * insert = @"INSERT INTO history (observed, transition, metadata_json, identifier) VALUES (?, ?, ?, ?);";
    
    int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL);
    
    if (retVal == SQLITE_OK) {
        sqlite3_bind_double(stmt, 1, now.timeIntervalSince1970);
        sqlite3_bind_text(stmt, 2, [stateDesc cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT);

        NSString * metadata = nil;
        NSString * originalId = nil;
        NSDictionary * selectedRegion = nil;

        for (NSDictionary * regionDef in [self cachedGeofences]) {
            NSString * identifier = [NSString stringWithFormat:@"geofence-%@", regionDef[@"properties"][@"identifier"]];

            NSError *error;

            if ([identifier isEqualToString:region.identifier]) {
                selectedRegion = regionDef;
                
                NSData * jsonData = [NSJSONSerialization dataWithJSONObject:regionDef
                                                                    options:NSJSONWritingPrettyPrinted
                                                                      error:&error];

                metadata = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                originalId = [regionDef[@"properties"][@"identifier"] description];
            }
        }
        
        if (metadata == nil) {
            metadata = @"";
        }

        if (originalId == nil) {
            originalId = @"";
        }

        if (selectedRegion == nil) {
            selectedRegion = @{};
        }

        sqlite3_bind_text(stmt, 3, [metadata cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 4, [originalId cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT);
        
        retVal = sqlite3_step(stmt);
        
        if (SQLITE_DONE != retVal) {
            NSLog(@"Error while inserting data. %d '%s'", retVal, sqlite3_errmsg(self.database));
        }
        
        sqlite3_finalize(stmt);

        NSMutableDictionary * data = [NSMutableDictionary dictionary];
        
        [data setValue:originalId forKey:PDKGeofenceIdentifier];
        [data setValue:selectedRegion[@"properties"] forKey:PDKGeofenceDetails];
        [data setValue:stateDesc forKey:PDKGeofenceTransition];

        for (id<PDKDataListener> listener in self.listeners) {
            [listener receivedData:data forGenerator:PDKGeofences];
        }
    }
}

- (CGFloat) minutesWithin:(NSString *) identifier start:(NSDate *) windowStart end:(NSDate *) windowEnd {
    CGFloat timeIn = 0;
    CGFloat timeOut = 0;

    @synchronized(self) {
        sqlite3_stmt * statement;
        
        NSString * select = @"SELECT H.transition, H.observed FROM history H WHERE H.identifier = ? ORDER BY H.observed DESC";
        
        const char * query_stmt = [select UTF8String];
        
        if (sqlite3_prepare_v2(self.database, query_stmt, -1, &statement, NULL) == SQLITE_OK) { //!OCLINT
            sqlite3_bind_text(statement, 1, [identifier cStringUsingEncoding:NSUTF8StringEncoding],  -1, SQLITE_TRANSIENT);
            
            NSTimeInterval lastTimestamp = windowEnd.timeIntervalSince1970;
            
            while (sqlite3_step(statement) == SQLITE_ROW) {
                const unsigned char * transitionStr = sqlite3_column_text(statement, 0);
                
                if (transitionStr != NULL) {
                    NSString * transition = [[NSString alloc] initWithUTF8String:(const char *) transitionStr];
                    
                    NSTimeInterval observed = sqlite3_column_double(statement, 1);
                    
                    if (observed < windowStart.timeIntervalSince1970) {
                        observed = windowStart.timeIntervalSince1970;
                    }
                    
                    if ([PDKGeofenceTransitionInside isEqualToString:transition]) {
                        timeIn += (lastTimestamp - observed);
                        
                        lastTimestamp = observed;
                    } else if ([PDKGeofenceTransitionOutside isEqualToString:transition]) {
                        timeOut += (lastTimestamp - observed);
                        
                        lastTimestamp = observed;
                    }
                    
                    if (observed == windowStart.timeIntervalSince1970) {
                        break;
                    }
                }
            }
            
            sqlite3_finalize(statement);
        }
    }

    return timeIn / 60.0;
}

- (void) setCachedDataRetentionPeriod:(NSTimeInterval) period {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    [defaults setValue:@(period) forKey:RETENTION_PERIOD];
    [defaults synchronize];
}

- (void) flushCachedData {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];

    NSNumber * retention = [defaults valueForKey:RETENTION_PERIOD];
    
    if (retention == nil) {
        retention = @(RETENTION_PERIOD_DEFAULT);
    }

    NSString * delete = @"DELETE FROM history WHERE observed < ?";
    
    sqlite3_stmt * stmt;
    
    int retVal = sqlite3_prepare_v2(self.database, [delete UTF8String], -1, &stmt, NULL);
    
    if (retVal == SQLITE_OK) {
        NSTimeInterval start = [NSDate date].timeIntervalSince1970 - retention.doubleValue;
        
        sqlite3_bind_double(stmt, 1, start);
        
        if (SQLITE_DONE != sqlite3_step(stmt)) {
            NSLog(@"Error while clearing data. %d '%s'", retVal, sqlite3_errmsg(self.database));
        }
    }

    sqlite3_finalize(stmt);
}

@end

