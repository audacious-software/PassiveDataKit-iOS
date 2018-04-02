//
//  PDKPedometerSensor.m
//  PassiveDataKit
//
//  Created by Chris Karr on 6/26/17.
//  Copyright © 2017 Audacious Software. All rights reserved.
//

#import <sqlite3.h>

#import "PDKPedometerGenerator.h"

#define DATABASE_VERSION @"PDKPedometerGenerator.DATABASE_VERSION"
#define CURRENT_DATABASE_VERSION @(1)

#define LAST_UPDATE @"PDKPedometerGenerator.LAST_UPDATE"

NSString * const PDKPedometerStart = @"interval-start"; //!OCLINT
NSString * const PDKPedometerEnd = @"interval-end"; //!OCLINT
NSString * const PDKPedometerStepCount = @"step-count"; //!OCLINT
NSString * const PDKPedometerDistance = @"distance"; //!OCLINT
NSString * const PDKPedometerAveragePace = @"average-pace"; //!OCLINT
NSString * const PDKPedometerCurrentPace = @"current-pace"; //!OCLINT
NSString * const PDKPedometerCurrentCadence = @"current-cadence"; //!OCLINT
NSString * const PDKPedometerFloorsAscended = @"floors-ascended"; //!OCLINT
NSString * const PDKPedometerFloorsDescended = @"floors-descended"; //!OCLINT
NSString * const PDKPedometerFromBackground = @"from-background"; //!OCLINT

NSString * const PDKPedometerAlert = @"pdk-pedometer-alert"; //!OCLINT

@interface PDKPedometerGenerator()

@property NSMutableArray * listeners;
@property NSDictionary * lastOptions;
@property CMPedometer * pedometer;

@property sqlite3 * database;

@property NSDate * lastUpdate;

@end

#define GENERATOR_ID @"pdk-pedometer"

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
        
        self.database = [self openDatabase];
    }
    
    return self;
}

- (NSString *) databasePath {
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString * documentsPath = paths[0];
    
    NSString * dbPath = [documentsPath stringByAppendingPathComponent:@"pdk-pedometer.sqlite3"];
    
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
            
            const char * createStatement = "CREATE TABLE IF NOT EXISTS pedometer_data (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp REAL, interval_start REAL, interval_end REAL, step_count REAL, distance REAL, average_pace REAL, current_pace REAL, current_cadence REAL, floors_ascended REAL, floors_descended REAL)";
            
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
        
        BOOL updated = NO;
        char * error = NULL;

        switch (dbVersion.integerValue) {
            case 0:
                if (sqlite3_exec(database, "ALTER TABLE pedometer_data ADD COLUMN today_start REAL", NULL, NULL, &error) != SQLITE_OK) { //!OCLINT

                } else {
                    NSLog(@"DB 0 ERROR: %s", error);
                }
                
                updated = YES;
                
                break;
            default:
                break;
        }
        
        if (updated) {
            [defaults setValue:CURRENT_DATABASE_VERSION forKey:DATABASE_VERSION];
        }
        
        return database;
    }
    
    NSLog(@"UNABLE TO OPEN DATABASE");
    
    return NULL;
}

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options {
    if ([self.listeners containsObject:listener] == NO) {
        [self.listeners addObject:listener];
    }

    if (@available(iOS 10.0, *)) {
        [self.pedometer stopPedometerEventUpdates]; //!OCLINT
    }

    if (self.listeners.count > 0) {
        if ([CMPedometer isStepCountingAvailable]) {
            NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
            
            NSDate * startDate = [defaults valueForKey:LAST_UPDATE];
            NSDate * now = [NSDate date];

            if (startDate == nil) {
                startDate = now;
            } else {
                NSDate * startToday = [[NSCalendar currentCalendar] startOfDayForDate:startDate];
                NSDate * nowToday = [[NSCalendar currentCalendar] startOfDayForDate:now];

                if ([startToday isEqualToDate:nowToday] == NO) {
                    startDate = now;
                }
            }
            
            [[PassiveDataKit sharedInstance] logEvent:@"pedometer_request_updates" properties:nil];
            [self.pedometer startPedometerUpdatesFromDate:startDate withHandler:^(CMPedometerData * _Nullable pedometerData, NSError * _Nullable error) {
                [[PassiveDataKit sharedInstance] logEvent:@"pedometer_receive_update" properties:nil];

                if (error == nil) {
                    [self logPedometerData:pedometerData fromBackground:NO];
                } else {
                    [self displayError:error];
                }
            }];

            [[PassiveDataKit sharedInstance] cancelAlertWithTag:PDKPedometerAlert];
        } else {
            NSString * message = NSLocalizedStringFromTableInBundle(@"error_generator_pedometer_unavailable", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
            
            [[PassiveDataKit sharedInstance] updateAlertWithTag:PDKPedometerAlert message:message level:PDKAlertLevelError action:^{
                id<UIApplicationDelegate> delegate = [UIApplication sharedApplication].delegate;

                NSString * alertTitle = NSLocalizedStringFromTableInBundle(@"title_generator_pedometer_unavailable", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
                
                NSString * alertMessage = NSLocalizedStringFromTableInBundle(@"message_generator_pedometer_unavailable", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);

                UIAlertController * prompt = [UIAlertController alertControllerWithTitle:alertTitle
                                                                                 message:alertMessage
                                                                          preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"button_continue", nil)
                                                                        style:UIAlertActionStyleDefault
                                                                      handler:^(UIAlertAction * action) {
                                                                      }];
                [prompt addAction:defaultAction];
                
                [delegate.window.rootViewController presentViewController:prompt animated:YES completion:nil];
            }];
        }
    }
}

- (void) refresh {
    if (self.lastUpdate == nil) {
        [[PassiveDataKit sharedInstance] logEvent:@"pedometer_last_update_is_nil" properties:nil];

        NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

        NSDate * lastUpdate = [defaults valueForKey:LAST_UPDATE];
        
        if (lastUpdate != nil) {
            NSDate * now = [NSDate date];

            NSDate * lastToday = [[NSCalendar currentCalendar] startOfDayForDate:lastUpdate];
            NSDate * nowToday = [[NSCalendar currentCalendar] startOfDayForDate:now];
            
            if ([lastToday isEqualToDate:nowToday]) {
                [[PassiveDataKit sharedInstance] logEvent:@"pedometer_same_day" properties:nil];
                [self.pedometer queryPedometerDataFromDate:lastUpdate toDate:now withHandler:^(CMPedometerData * _Nullable pedometerData, NSError * _Nullable error) {
                    if (error == nil) {
                        [self logPedometerData:pedometerData fromBackground:YES];
                    } else {
                        [self displayError:error];
                    }
                }];
            } else {
                [[PassiveDataKit sharedInstance] logEvent:@"pedometer_split_day" properties:nil];
                
                [self.pedometer queryPedometerDataFromDate:lastUpdate toDate:nowToday withHandler:^(CMPedometerData * _Nullable pedometerData, NSError * _Nullable error) {
                    if (error == nil) {
                        [[PassiveDataKit sharedInstance] logEvent:@"pedometer_log_1" properties:nil];
                        [self logPedometerData:pedometerData fromBackground:YES];
                    } else {
                        [[PassiveDataKit sharedInstance] logEvent:@"pedometer_error_1" properties:nil];
                        [self displayError:error];
                    }
                }];

                [self.pedometer queryPedometerDataFromDate:nowToday toDate:now withHandler:^(CMPedometerData * _Nullable pedometerData, NSError * _Nullable error) {
                    if (error == nil) {
                        [[PassiveDataKit sharedInstance] logEvent:@"pedometer_log_2" properties:nil];
                        [self logPedometerData:pedometerData fromBackground:YES];
                    } else {
                        [[PassiveDataKit sharedInstance] logEvent:@"pedometer_error_2" properties:nil];
                        [self displayError:error];
                    }
                }];
            }
        }
    } else {
        [[PassiveDataKit sharedInstance] logEvent:@"pedometer_last_update_not_nil" properties:nil];
    }
}

- (void) logPedometerData:(CMPedometerData *) pedometerData fromBackground:(BOOL) fromBackground {
    if ([pedometerData.numberOfSteps integerValue] == 0) {
        [[PassiveDataKit sharedInstance] logEvent:@"pedometer_skip_log_zero_steps" properties:nil];
        return;
    } else if ([pedometerData.startDate isEqualToDate:pedometerData.endDate]) {
        [[PassiveDataKit sharedInstance] logEvent:@"pedometer_skip_log_instant_interval" properties:nil];
        return;
    }
    
    [[PassiveDataKit sharedInstance] logEvent:@"pedometer_log_data" properties:nil];

    NSDate * now = [NSDate date];
    
    NSMutableDictionary * data = [NSMutableDictionary dictionary];
    
    data[PDKPedometerStart] = [NSNumber numberWithFloat:pedometerData.startDate.timeIntervalSince1970];
    data[PDKPedometerEnd] = [NSNumber numberWithFloat:pedometerData.endDate.timeIntervalSince1970];
    data[PDKPedometerStepCount] = pedometerData.numberOfSteps;
    data[PDKPedometerDistance] = pedometerData.distance;
    data[PDKPedometerAveragePace] = pedometerData.averageActivePace; //!OCLINT
    data[PDKPedometerCurrentPace] = pedometerData.currentPace;
    data[PDKPedometerCurrentCadence] = pedometerData.currentCadence;
    
    data[PDKPedometerFloorsAscended] = pedometerData.floorsAscended;
    data[PDKPedometerFloorsDescended] = pedometerData.floorsDescended;
    data[PDKPedometerFromBackground] = [NSNumber numberWithBool:fromBackground];

    sqlite3_stmt * stmt;
    
    NSString * insert = @"INSERT INTO pedometer_data (timestamp, interval_start, interval_end, step_count, distance, average_pace, current_pace, current_cadence, floors_ascended, floors_descended, today_start) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";
    
    NSDate * todayStart = [[NSCalendar currentCalendar] startOfDayForDate:[NSDate date]];
    
    int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL);
    
    if (retVal == SQLITE_OK) {
        if (sqlite3_bind_double(stmt, 1, now.timeIntervalSince1970) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 2, pedometerData.startDate.timeIntervalSince1970) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 3, pedometerData.endDate.timeIntervalSince1970) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 4, pedometerData.numberOfSteps.doubleValue) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 5, pedometerData.distance.doubleValue) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 6, pedometerData.averageActivePace.doubleValue) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 7, pedometerData.currentPace.doubleValue) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 8, pedometerData.currentCadence.doubleValue) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 9, pedometerData.floorsAscended.doubleValue) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 10, pedometerData.floorsDescended.doubleValue) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 11, todayStart.timeIntervalSince1970) == SQLITE_OK) {

            int retVal = sqlite3_step(stmt);
            
            if (SQLITE_DONE == retVal) {
                NSLog(@"INSERT SUCCESSFUL");
            } else {
                NSLog(@"Error while inserting data. %d '%s'", retVal, sqlite3_errmsg(self.database));
            }
        }
        sqlite3_finalize(stmt);
    } else {
        NSLog(@"CANNOT OPEN DATABASE: %d", retVal);
    }

    [[PassiveDataKit sharedInstance] logEvent:@"pedometer_set_last_update_1" properties:nil];

    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:pedometerData.endDate forKey:LAST_UPDATE];
    [defaults synchronize];
    
    [[PassiveDataKit sharedInstance] receivedData:data forGenerator:PDKPedometer];
}

- (void) removeListener:(id<PDKDataListener>)listener {
    [self.listeners removeObject:listener];
    
    if (self.listeners.count == 0) {
//      [self.pedometer stopPedometerEventUpdates];
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

- (NSString *) generatorId {
    return GENERATOR_ID;
}

- (void) historicalStepsBetweenStart:(NSTimeInterval) start end:(NSTimeInterval) end withHandler:(CMPedometerHandler)handler {
    [self.pedometer queryPedometerDataFromDate:[NSDate dateWithTimeIntervalSince1970:start]
                                        toDate:[NSDate dateWithTimeIntervalSince1970:end]
                                   withHandler:handler];
}

- (CGFloat) stepsBetweenStart:(NSTimeInterval) start end:(NSTimeInterval) end {
    CGFloat totalSteps = 0;

    NSArray * queries = @[
                          @"SELECT P.interval_start, P.interval_end, P.step_count FROM pedometer_data P WHERE (P.interval_start >= ? AND P.interval_start <= ? AND P.interval_end > ? AND P.interval_end >= ?) ORDER BY P.interval_start DESC",
                          @"SELECT P.interval_start, P.interval_end, P.step_count FROM pedometer_data P WHERE (P.interval_end >= ? AND P.interval_end <= ? AND P.interval_start <= ? AND P.interval_start < ?) ORDER BY P.interval_start DESC",
                          @"SELECT P.interval_start, P.interval_end, P.step_count FROM pedometer_data P WHERE (P.interval_start >= ? AND P.interval_end <= ? AND P.interval_end > ? AND P.interval_start < ?) ORDER BY P.interval_start DESC",
                          @"SELECT P.interval_start, P.interval_end, P.step_count FROM pedometer_data P WHERE (P.interval_start <= ? AND P.interval_end >= ? AND P.interval_end > ? AND P.interval_start < ?) ORDER BY P.interval_start DESC"
                          ];

    NSTimeInterval lastSeen = 0;
    
    for (NSString * query in queries) {
        sqlite3_stmt * statement = NULL;
        
        if (sqlite3_prepare_v2(self.database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK) {
            if (sqlite3_bind_double(statement, 1, start) == SQLITE_OK && sqlite3_bind_double(statement, 2, end) == SQLITE_OK &&
                sqlite3_bind_double(statement, 3, start) == SQLITE_OK && sqlite3_bind_double(statement, 4, end) == SQLITE_OK) {
                while (sqlite3_step(statement) == SQLITE_ROW)
                {
                    NSTimeInterval intervalStart = sqlite3_column_double(statement, 0);
                    
                    if (intervalStart != lastSeen) {
                        NSTimeInterval intervalEnd = sqlite3_column_double(statement, 1);
                        CGFloat steps = sqlite3_column_double(statement, 2);
                        
                        if (intervalStart >= start && intervalEnd <= end) {
                            totalSteps += steps;
                        } else {
                            CGFloat fraction = 0;
                            
                            if (intervalStart <= start && intervalEnd >= end) {
                                fraction = (end - start) / (intervalEnd - intervalStart);
                            } else if (intervalStart <= start) {
                                fraction = (intervalEnd - start) / (intervalEnd - intervalStart);
                            } else if (intervalEnd >= end) {
                                fraction = (end - intervalStart) / (intervalEnd - intervalStart);
                            }
                            
                            totalSteps += (steps * fraction);
                        }
                        
                        lastSeen = intervalStart;
                    }
                }
            }
            
            sqlite3_finalize(statement);
        }
    }
    
    return totalSteps;
}

@end
