//
//  PDKAccelerometerGenerator.m
//  PassiveDataKit
//
//  Created by Chris Karr on 7/30/19.
//  Copyright © 2019 Audacious Software. All rights reserved.
//

@import CoreMotion;

#include <sqlite3.h>

#import "PDKAccelerometerGenerator.h"

#define GENERATOR_ID @"pdk-accelerometer"

#define DATABASE_VERSION @"PDKAccelerometerGenerator.DATABASE_VERSION"
#define CURRENT_DATABASE_VERSION @(1)

NSString * const PDKAccelerometerSampleRate = @"PDKAccelerometerSampleRate"; //!OCLINT

@interface PDKAccelerometerGenerator()

@property NSMutableArray * listeners;
@property NSDictionary * lastOptions;

@property sqlite3 * database;

@property CMMotionManager * motionManager;
@property BOOL isRunning;

@end

static PDKAccelerometerGenerator * sharedObject = nil;

@implementation PDKAccelerometerGenerator

+ (PDKAccelerometerGenerator *) sharedInstance {
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
        self.motionManager = [[CMMotionManager alloc] init];

        self.database = [self openDatabase];
    }
    
    return self;
}

- (void) refresh {
    // Do nothing...
}

- (NSString *) databasePath {
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString * documentsPath = paths[0];
    
    NSString * dbPath = [documentsPath stringByAppendingPathComponent:@"pdk-accelerometer.sqlite"];
    
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
            
            const char * createStatement = "CREATE TABLE IF NOT EXISTS accelerometer_data (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp REAL, x REAL, y REAL, z REAL, raw_timestamp REAL)";
            
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

- (void) removeListener:(id<PDKDataListener>)listener {
    [self.listeners removeObject:listener];
    
    if (self.listeners.count == 0) {
        [self stopUpdates];
    }
}

- (void) updateOptions:(NSDictionary *) options {
    if (options == nil) {
        options = @{}; //!OCLINT
    }
    
    //    NSLog(@"TODO: Update options and refresh generator!");
}

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options {
    if (options == nil) {
        options = @{}; //!OCLINT
    }
    
    self.lastOptions = options;
    
    if (listener != nil) {
        [self.listeners addObject:listener];
    }
    
    [self startUpdates];
}

+ (NSString *) title {
    return NSLocalizedStringFromTableInBundle(@"name_generator_accelerometer", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
}

/*
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
 
 */

- (NSString *) generatorId {
    return GENERATOR_ID;
}

- (void) startUpdates {
    if (self.isRunning) {
        return;
    }
    
    NSLog(@"STARTING LOCATION UPDATES");
    
    self.isRunning = YES;
    
    NSNumber * sampleRate = self.lastOptions[PDKAccelerometerSampleRate];
    
    if (sampleRate == nil) {
        sampleRate = @(1.0);
    }
    
    self.motionManager.accelerometerUpdateInterval = sampleRate.doubleValue;
    
    [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue]
                                             withHandler:^(CMAccelerometerData * _Nullable data, NSError * _Nullable error) {
                                                 if (data != nil) {
                                                     NSLog(@"GOT ACCELEROMETER: %@, %@, %@", @(data.acceleration.x), @(data.acceleration.y), @(data.acceleration.z));
                                                 }
                                             }];
}

- (void) stopUpdates {
    if (self.isRunning == NO) {
        return;
    }
    
    NSLog(@"STOPPING LOCATION UPDATES");

    self.isRunning = NO;
    
    [self.motionManager stopAccelerometerUpdates];
}

@end
