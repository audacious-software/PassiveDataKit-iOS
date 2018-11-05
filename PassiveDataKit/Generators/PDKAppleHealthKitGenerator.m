//
//  PDKAppleHealthKitGenerator.m
//  PassiveDataKit
//
//  Created by Chris Karr on 6/26/17.
//  Copyright © 2017 Audacious Software. All rights reserved.
//

#include <sqlite3.h>

@import HealthKit;

#import "PDKAppleHealthKitGenerator.h"

#define DATABASE_VERSION @"PDKAppleHealthKitGenerator.DATABASE_VERSION"
#define CURRENT_DATABASE_VERSION @(3)
#define GENERATOR_ID @"pdk-health-kit"

#define PDKAppleHealthFetched @"fetched"
#define PDKAppleHealthDateStart @"interval_start"
#define PDKAppleHealthDateEnd @"interval_end"
#define PDKAppleHealthStepCount @"step_count"
#define PDKAppleHealthDevice @"device"
#define PDKAppleHealthDataType @"data-type"
#define PDKAppleHealthDataTypeStepCount @"step-count"
#define PDKAppleHealthDataTypeStepCountSummary @"step-count-summary"

#define PDKAppleHealthSummaryCountFetchInterval 60

NSString * const PDKAppleHealthStepsEnabled = @"PDKAppleHealthStepsEnabled";

NSString * const PDKAppleHealthKitRequestedTypes = @"PDKAppleHealthKitRequestedTypes"; //!OCLINT

NSString * const PDKHealthKitAlert = @"pdk-health-kit-alert"; //!OCLINT

@interface PDKAppleHealthKitGenerator ()

@property NSMutableArray * listeners;
@property NSDictionary * lastOptions;

@property (nonatomic, copy) void (^accessDeniedBlock)(void);
@property sqlite3 * database;
@property HKHealthStore * healthStore;

@property BOOL requestPermissions;
@property BOOL stepsEnabled;

@property NSMutableDictionary * lastStepSummaryFetches;

@end

static PDKAppleHealthKitGenerator * sharedObject = nil;

@implementation PDKAppleHealthKitGenerator

+ (UIColor *) dataColor {
    return [UIColor colorWithRed:0xA7/255.0 green:0xB1/255.0 blue:0xB6/255.0 alpha:1.0];
}

+ (PDKAppleHealthKitGenerator *) sharedInstance {
    static dispatch_once_t _singletonPredicate;
    
    dispatch_once(&_singletonPredicate, ^{
        sharedObject = [[super allocWithZone:nil] init];
    });
    
    return sharedObject;
}

+ (id) allocWithZone:(NSZone *) zone  { //!OCLINT
    return [PDKAppleHealthKitGenerator sharedInstance];
}

- (id) init {
    if (self = [super init]) {
        self.stepsEnabled = NO;
        
        self.listeners = [NSMutableArray array];

        self.database = [self openDatabase];

        self.healthStore = [[HKHealthStore alloc] init];
        self.requestPermissions = YES;
        
        self.lastStepSummaryFetches = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (NSString *) databasePath {
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString * documentsPath = paths[0];
    
    NSString * dbPath = [documentsPath stringByAppendingPathComponent:@"pdk-apple-health-kit.sqlite3"];
    
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
            
            const char * createStatement = "CREATE TABLE IF NOT EXISTS steps_data (id INTEGER PRIMARY KEY AUTOINCREMENT, fetched REAL, interval_start REAL, interval_end REAL, step_count REAL, device TEXT)";
            
            if (sqlite3_exec(database, createStatement, NULL, NULL, &error) != SQLITE_OK) { //!OCLINT
                // NSLog(@"PDK APPLE MADE STEPS DB");
            }
            
            sqlite3_close(database);
        }
    }
    
    const char * dbpath = [dbPath UTF8String];
    
    sqlite3 * database = NULL;
    
    if (sqlite3_open(dbpath, &database) == SQLITE_OK) {
        NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
        
        NSNumber * dbVersion = [defaults valueForKey:DATABASE_VERSION];

        BOOL updated = NO;

        if (dbVersion == nil) {
            dbVersion = @(0);
            updated = YES;
        }
        
        char * error = NULL;

        switch (dbVersion.integerValue) {
            case 0:
            case 1:
            case 2:
                if (sqlite3_exec(database, "DROP TABLE IF EXISTS summary_steps_data", NULL, NULL, &error) == SQLITE_OK) { //!OCLINT

                }
                
                if (sqlite3_exec(database, "CREATE TABLE IF NOT EXISTS summary_steps_data (id INTEGER PRIMARY KEY AUTOINCREMENT, fetched REAL, interval_start REAL, interval_end REAL, step_count REAL)", NULL, NULL, &error) == SQLITE_OK) { //!OCLINT

                }
                
                updated = YES;
            default:
                break;
        }
        
        if (updated) {
            [defaults setValue:CURRENT_DATABASE_VERSION forKey:DATABASE_VERSION];
            [defaults synchronize];
        }
        
        return database;
    }
    
    return NULL;
}

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options {
    [self updateOptions:options];

    if (self.listeners.count > 0) {
        if (options == nil) {
            options = @{};
        }

        if ([HKHealthStore isHealthDataAvailable]) {
            if ([self isAuthenticated]) {
                [[PassiveDataKit sharedInstance] cancelAlertWithTag:PDKHealthKitAlert];
            } else {
                // TODO: Log AUTH WARNING....
            }
        } else {
            NSString * title = NSLocalizedStringFromTableInBundle(@"title_generator_healthkit_unavailable", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
            NSString * message = NSLocalizedStringFromTableInBundle(@"error_generator_healthkit_unavailable", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
            
            [[PassiveDataKit sharedInstance] updateAlertWithTag:PDKHealthKitAlert title:title message:message level:PDKAlertLevelError action:^{
                id<UIApplicationDelegate> delegate = [UIApplication sharedApplication].delegate;
                
                NSString * alertTitle = NSLocalizedStringFromTableInBundle(@"title_generator_healthkit_unavailable", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
                
                NSString * alertMessage = NSLocalizedStringFromTableInBundle(@"message_generator_healthkit_unavailable", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
                
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

    if ([self.listeners containsObject:listener] == NO) {
        [self.listeners addObject:listener];
    }
}

- (void) updateOptions:(NSDictionary *) options {
    NSNumber * doSteps = options[PDKAppleHealthStepsEnabled];
    
    if (doSteps != nil) {
        self.stepsEnabled = doSteps.boolValue;
    }

    NSNumber * requestPermissions = options[PDKRequestPermissions];
    
    if (requestPermissions != nil) {
        self.requestPermissions = requestPermissions.boolValue;
    }

}

- (void) removeListener:(id<PDKDataListener>)listener {
    [self.listeners removeObject:listener];
    
    if (self.listeners.count == 0) {
        // Remove listeners...
    }
}

- (NSString *) generatorId {
    return GENERATOR_ID;
}

- (BOOL) isAuthenticated {
    BOOL authed = YES;
    
    if (self.stepsEnabled) {
        HKSampleType * stepType = [HKSampleType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
        
        if ([self.healthStore authorizationStatusForType:stepType] != HKAuthorizationStatusSharingAuthorized) {
            authed = NO;
        } else {
        }
    }
    
    return authed;
}

- (void) authenticate:(void (^)(void))successCallback failure:(void (^)(void))failure {
    NSMutableSet * types = [NSMutableSet set];
    
    if (self.stepsEnabled) {
        HKSampleType * stepType = [HKSampleType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];

        [types addObject:stepType];
    }

    if (types.count > 0) {
        [self.healthStore requestAuthorizationToShareTypes:types
                                                 readTypes:types
                                                completion:^(BOOL success, NSError * _Nullable error) {
                                                    if (success) {
                                                        successCallback();
                                                    } else {
                                                        failure();
                                                    }
                                                }];
    }
}

- (NSString *)fullGeneratorName {
    return GENERATOR_ID;
}

- (UIView *)visualizationForSize:(CGSize)size {
    return [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
}

- (void) logStepCount:(CGFloat) stepCount intervalStart:(NSDate *) start end:(NSDate *) end device:(HKDevice *) device {
    NSString * deviceName = [NSString stringWithFormat:@"%@ %@ (%@)", device.manufacturer, device.hardwareVersion, device.softwareVersion];
    
    NSDate * now = [NSDate date];

    NSMutableDictionary * data = [NSMutableDictionary dictionary];
    [data setValue:@([now timeIntervalSince1970] * 1000) forKey:PDKAppleHealthFetched];
    [data setValue:@([start timeIntervalSince1970] * 1000) forKey:PDKAppleHealthDateStart];
    [data setValue:@([end timeIntervalSince1970] * 1000) forKey:PDKAppleHealthDateEnd];
    [data setValue:@(stepCount) forKey:PDKAppleHealthStepCount];
    [data setValue:deviceName forKey:PDKAppleHealthDevice];
    
    data[PDKAppleHealthDataType] = PDKAppleHealthDataTypeStepCount;

    BOOL logNew = YES;

    @synchronized(self) {
        sqlite3_stmt * statement;
        
        NSString * select = @"SELECT COUNT(*) FROM steps_data A WHERE A.interval_start = ? AND A.interval_end = ? AND A.step_count = ? AND A.device = ?";
        
        const char * query_stmt = [select UTF8String];
        
        if (sqlite3_prepare_v2(self.database, query_stmt, -1, &statement, NULL) == SQLITE_OK) { //!OCLINT
            sqlite3_bind_double(statement, 1, [start timeIntervalSince1970]);
            sqlite3_bind_double(statement, 2, [end timeIntervalSince1970]);
            sqlite3_bind_double(statement, 3, stepCount);
            sqlite3_bind_text(statement, 4, [deviceName cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT);
            
            sqlite3_step(statement);

            int matches = sqlite3_column_int(statement, 0);
            
            if (matches > 0) {
                logNew = NO;
            }
 
            sqlite3_finalize(statement);
        }
        
        if (logNew) {
            sqlite3_stmt * insert_stmt;

            NSString * insert = @"INSERT INTO steps_data (fetched, interval_start, interval_end, step_count, device) VALUES (?, ?, ?, ?, ?);";
            
            int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &insert_stmt, NULL);
            
            if (retVal == SQLITE_OK) {
                if (sqlite3_bind_double(insert_stmt, 1, [now timeIntervalSince1970]) == SQLITE_OK &&
                    sqlite3_bind_double(insert_stmt, 2, [start timeIntervalSince1970]) == SQLITE_OK &&
                    sqlite3_bind_double(insert_stmt, 3, [end timeIntervalSince1970]) == SQLITE_OK &&
                    sqlite3_bind_double(insert_stmt, 4, stepCount) == SQLITE_OK &&
                    sqlite3_bind_text(insert_stmt, 5, [deviceName cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT) == SQLITE_OK) {
                    
                    int retVal = sqlite3_step(insert_stmt);

                    if (SQLITE_DONE != retVal) {
                        NSLog(@"Error while inserting data. %d '%s'", retVal, sqlite3_errmsg(self.database));
                    }
                }
                
                sqlite3_finalize(insert_stmt);
            }
            
        }
    }

    if (logNew) {
        for (id<PDKDataListener> listener in self.listeners) {
            [listener receivedData:data forGenerator:PDKAppleHealthKit];
        }
    }
}

- (void) logSummaryStepCount:(CGFloat) stepCount intervalStart:(NSDate *) start end:(NSDate *) end {
    NSDate * now = [NSDate date];
    
    NSMutableDictionary * data = [NSMutableDictionary dictionary];
    [data setValue:@([now timeIntervalSince1970] * 1000) forKey:PDKAppleHealthFetched];
    [data setValue:@([start timeIntervalSince1970] * 1000) forKey:PDKAppleHealthDateStart];
    [data setValue:@([end timeIntervalSince1970] * 1000) forKey:PDKAppleHealthDateEnd];
    [data setValue:@(stepCount) forKey:PDKAppleHealthStepCount];
    
    data[PDKAppleHealthDataType] = PDKAppleHealthDataTypeStepCountSummary;
    
    BOOL logNew = YES;
    
    @synchronized(self) {
        sqlite3_stmt * statement;
        
        NSString * select = @"SELECT COUNT(*) FROM summary_steps_data WHERE interval_start = ? AND interval_end = ? AND step_count = ?;";
        
        int retVal = sqlite3_prepare_v2(self.database, [select UTF8String], -1, &statement, NULL);
        
        if (retVal == SQLITE_OK) { //!OCLINT
            sqlite3_bind_double(statement, 1, [start timeIntervalSince1970]);
            sqlite3_bind_double(statement, 2, [end timeIntervalSince1970]);
            sqlite3_bind_double(statement, 3, stepCount);
            
            sqlite3_step(statement);
            
            int matches = sqlite3_column_int(statement, 0);
            
            if (matches > 0) {
                logNew = NO;
            }
            
            sqlite3_finalize(statement);
        }


        if (logNew) {
            sqlite3_stmt * insert_stmt;
            
            NSString * insert = @"INSERT INTO summary_steps_data (fetched, interval_start, interval_end, step_count) VALUES (?, ?, ?, ?);";
            
            int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &insert_stmt, NULL);
            
            if (retVal == SQLITE_OK) {
                if (sqlite3_bind_double(insert_stmt, 1, [now timeIntervalSince1970]) == SQLITE_OK &&
                    sqlite3_bind_double(insert_stmt, 2, [start timeIntervalSince1970]) == SQLITE_OK &&
                    sqlite3_bind_double(insert_stmt, 3, [end timeIntervalSince1970]) == SQLITE_OK &&
                    sqlite3_bind_double(insert_stmt, 4, stepCount) == SQLITE_OK) {
                    
                    int retVal = sqlite3_step(insert_stmt);
                    
                    if (SQLITE_DONE != retVal) {
                        NSLog(@"Error while inserting data. %d '%s'", retVal, sqlite3_errmsg(self.database));
                    }
                }
                
                sqlite3_finalize(insert_stmt);
            }
        }
    }
    
    if (logNew) {
        for (id<PDKDataListener> listener in self.listeners) {
            [listener receivedData:data forGenerator:PDKAppleHealthKit];
        }
    }
}

- (void)stepsBetweenStart:(NSTimeInterval)start end:(NSTimeInterval)end callback:(void (^)(NSTimeInterval, NSTimeInterval, CGFloat))callback backfill:(BOOL) doBackfill force:(BOOL) force {
    __block CGFloat totalSteps = 0;
    __block CGFloat totalStepSummary = 0;

    NSDate * startDate = [NSDate dateWithTimeIntervalSince1970:start];
    NSDate * endDate = [NSDate dateWithTimeIntervalSince1970:end];
    
    if (force == NO) {
        NSString * allIn = @"(S.interval_start >= ? AND S.interval_end <= ?)"; // start, end.
        NSString * allAround = @"(S.interval_start <= ? AND S.interval_end >= ?)"; // start, end.
        NSString * startIn = @"(S.interval_start >= ? AND S.interval_start <= ?)"; // start, end.
        NSString * endIn = @"(S.interval_end >= ? AND S.interval_end <= ?)"; // start, end.
        
        @synchronized(self) {
            NSString * query = [NSString stringWithFormat:@"SELECT S.interval_start, S.interval_end, S.step_count FROM steps_data S WHERE (%@ OR %@ OR %@ OR %@) ORDER BY S.interval_start DESC", allIn, allAround, startIn, endIn];
            
            NSTimeInterval lastSeen = 0;

            sqlite3_stmt * statement = NULL;
            
            if (sqlite3_prepare_v2(self.database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK) {
                if (sqlite3_bind_double(statement, 1, start) == SQLITE_OK && sqlite3_bind_double(statement, 2, end) == SQLITE_OK &&
                    sqlite3_bind_double(statement, 3, start) == SQLITE_OK && sqlite3_bind_double(statement, 4, end) == SQLITE_OK &&
                    sqlite3_bind_double(statement, 5, start) == SQLITE_OK && sqlite3_bind_double(statement, 6, end) == SQLITE_OK &&
                    sqlite3_bind_double(statement, 7, start) == SQLITE_OK && sqlite3_bind_double(statement, 8, end) == SQLITE_OK) {

                    while (sqlite3_step(statement) == SQLITE_ROW) {
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

            NSString * exactMatch = @"(S.interval_start = ? AND S.interval_end = ?)"; // start, end.

            NSString * summaryQuery = [NSString stringWithFormat:@"SELECT S.step_count FROM summary_steps_data S WHERE %@ ORDER BY S.step_count DESC LIMIT 1", exactMatch];
            
            sqlite3_stmt * summaryStmt = NULL;
            
            if (sqlite3_prepare_v2(self.database, [summaryQuery UTF8String], -1, &summaryStmt, NULL) == SQLITE_OK) {
                if (sqlite3_bind_double(summaryStmt, 1, start) == SQLITE_OK && sqlite3_bind_double(summaryStmt, 2, end) == SQLITE_OK) {
                    if (sqlite3_step(summaryStmt) == SQLITE_ROW) {
                        totalStepSummary = sqlite3_column_double(summaryStmt, 0);
                    }
                }
                
                sqlite3_finalize(summaryStmt);
            }
        }
    }
    
    if (totalStepSummary < totalSteps) {
        totalSteps = totalStepSummary;
    }
    
    if (totalSteps > 0) {
        if (callback != nil) {
            callback(start, end, totalSteps);
        }
    } else {
        HKSampleType * sampleType = [HKSampleType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
        
        NSPredicate * predicate = [HKQuery predicateForSamplesWithStartDate:[NSDate dateWithTimeIntervalSince1970:start]
                                                                    endDate:[NSDate dateWithTimeIntervalSince1970:end]
                                                                    options:HKQueryOptionNone];
        
        void (^handler)(HKSampleQuery *, NSArray<__kindof HKSample *> *, NSError *) = ^void(HKSampleQuery * query, NSArray<__kindof HKSample *> * results, NSError * error) {
            if (error != nil) {
                NSLog(@"APPLE HEALTH ERROR: %@", error);

                callback(start, end, totalSteps);
            } else {
                for (HKQuantitySample *sample in results) {
                    CGFloat stepCount = [sample.quantity doubleValueForUnit:[HKUnit countUnit]];
                    
                    totalSteps += stepCount;
                    
                    [self logStepCount:stepCount intervalStart:sample.startDate end:sample.endDate device:sample.device];
                }
                
                HKQuantityType * quantityType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
                
                NSDateComponents *interval = [[NSDateComponents alloc] init];
                interval.day = 1;
                
                HKStatisticsCollectionQuery * query = [[HKStatisticsCollectionQuery alloc] initWithQuantityType:quantityType
                                                                                        quantitySamplePredicate:nil
                                                                                                        options:HKStatisticsOptionCumulativeSum
                                                                                                     anchorDate:startDate
                                                                                             intervalComponents:interval];
                
                query.initialResultsHandler = ^(HKStatisticsCollectionQuery *query, HKStatisticsCollection *results, NSError *error) {
                    if (error) {
                        NSLog(@"PDK APPLE STEP SUMMARY ERROR: %@", error);
                    } else {
                        HKStatistics * statistics = [results statisticsForDate:startDate];
                        CGFloat stepCountSummary = 0;
                        
                        if (statistics.sumQuantity != nil) {
                            stepCountSummary = [statistics.sumQuantity doubleValueForUnit:[HKUnit countUnit]];
                        }
                        
                        [self logSummaryStepCount:stepCountSummary intervalStart:startDate end:endDate];
                        
                        if (callback != nil) {
                            callback(start, end, stepCountSummary);
                        }
                    }
                };
                
                [self.healthStore executeQuery:query];

                return;
            }
        };
        
        HKSampleQuery * query = [[HKSampleQuery alloc] initWithSampleType:sampleType
                                                                predicate:predicate
                                                                    limit:HKObjectQueryNoLimit
                                                          sortDescriptors:nil
                                                           resultsHandler:handler];
        
        [self.healthStore executeQuery:query];
    }
}

+ (NSString *) title {
    return NSLocalizedStringFromTableInBundle(@"name_generator_health_kit", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
}

@end
