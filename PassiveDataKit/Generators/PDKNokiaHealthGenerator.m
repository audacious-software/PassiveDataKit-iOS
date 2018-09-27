//
//  PDKNokiaHealthGenerator.m
//  PassiveDataKit
//
//  Created by Chris Karr on 8/23/18.
//  Copyright © 2018 Audacious Software. All rights reserved.
//

#include <sqlite3.h>

@import AFNetworking;

#import <AppAuth/AppAuth.h>

#import "PDKNokiaHealthGenerator.h"

#define DATABASE_VERSION @"PDKNokiaHealthGenerator.DATABASE_VERSION"
#define CURRENT_DATABASE_VERSION @(1)
#define GENERATOR_ID @"pdk-nokia-health"

NSString * const PDKNokiaHealthClientID = @"PDKNokiaHealthClientID"; //!OCLINT
NSString * const PDKNokiaHealthCallbackURL = @"PDKNokiaHealthCallbackURL"; //!OCLINT
NSString * const PDKNokiaHealthClientSecret = @"PDKNokiaHealthClientSecret"; //!OCLINT
NSString * const PDKNokiaHealthLoginMandatory = @"PDKNokiaHealthLoginMandatory"; //!OCLINT

NSString * const PDKNokiaHealthAuthState = @"PDKNokiaHealthAuthState"; //!OCLINT

NSString * const PDKNokiaHealthScopes = @"PDKNokiaHealthScopes"; //!OCLINT

NSString * const PDKNokiaHealthScopeUserInfo = @"user.info"; //!OCLINT
NSString * const PDKNokiaHealthScopeUserMetrics = @"user.metrics"; //!OCLINT
NSString * const PDKNokiaHealthScopeUserActivity = @"user.activity"; //!OCLINT

NSString * const PDKNokiaHealthActivityMeasuresEnabled = @"PDKNokiaHealthActivityMeasuresEnabled";
NSString * const PDKNokiaHealthIntradayActivityMeasuresEnabled = @"PDKNokiaHealthIntradayActivityMeasuresEnabled";
NSString * const PDKNokiaHealthSleepMeasuresEnabled = @"PDKNokiaHealthSleepMeasuresEnabled";
NSString * const PDKNokiaHealthSleepSummaryEnabled = @"PDKNokiaHealthSleepSummaryEnabled";
NSString * const PDKNokiaHealthBodyMeasuresEnabled = @"PDKNokiaHealthBodyMeasuresEnabled";

NSString * const PDKNokiaHealthDataStream = @"datastream";

NSString * const PDKNokiaHealthFetched = @"fetched";
NSString * const PDKNokiaHealthObserved = @"observed";

NSString * const PDKNokiaHealthDataStreamActivityMeasures = @"activity-measures";
NSString * const PDKNokiaHealthDateStart = @"date_start";
NSString * const PDKNokiaHealthTimezone = @"timezone";
NSString * const PDKNokiaHealthSteps = @"steps";
NSString * const PDKNokiaHealthDistance = @"distance";
NSString * const PDKNokiaHealthActiveCalories = @"active_calories";
NSString * const PDKNokiaHealthTotalCalories = @"total_calories";
NSString * const PDKNokiaHealthElevation = @"elevation";
NSString * const PDKNokiaHealthSoftActivityDuration = @"soft_activity_duration";
NSString * const PDKNokiaHealthModerateActivityDuration = @"moderate_activity_duration";
NSString * const PDKNokiaHealthIntenseActivityDuration = @"intense_activity_duration";

NSString * const PDKNokiaHealthDataStreamIntradayActivityMeasures = @"intraday-activity";
NSString * const PDKNokiaHealthIntradayActivityStart = @"activity_start";
NSString * const PDKNokiaHealthIntradayActivityDuration = @"activity_duration";
NSString * const PDKNokiaHealthIntradayCalories = @"calories";
NSString * const PDKNokiaHealthIntradayDistance = @"distance";
NSString * const PDKNokiaHealthIntradaySteps = @"steps";
NSString * const PDKNokiaHealthIntradayElevationClimbed = @"elevation_climbed";
NSString * const PDKNokiaHealthIntradaySwimStrokes = @"swim_strokes";
NSString * const PDKNokiaHealthIntradayPoolLaps = @"pool_laps";

NSString * const PDKNokiaHealthDataStreamBodyMeasures = @"body";
NSString * const PDKNokiaHealthMeasureDate = @"measure_date";
NSString * const PDKNokiaHealthMeasureStatus = @"measure_status";
NSString * const PDKNokiaHealthMeasureCategory = @"measure_category";
NSString * const PDKNokiaHealthMeasureType = @"measure_type";
NSString * const PDKNokiaHealthMeasureValue = @"measure_value";

NSString * const PDKNokiaHealthMeasureStatusUnknown = @"unknown";
NSString * const PDKNokiaHealthMeasureStatusUserDevice = @"user-device";
NSString * const PDKNokiaHealthMeasureStatusSharedDevice = @"shared-device";
NSString * const PDKNokiaHealthMeasureStatusManualEntry = @"manual-entry";
NSString * const PDKNokiaHealthMeasureStatusManualEntryCreation = @"manual-entry-creation";
NSString * const PDKNokiaHealthMeasureStatusAutoDevice = @"auto-device";
NSString * const PDKNokiaHealthMeasureStatusMeasureConfirmed = @"measure-confirmed";

NSString * const PDKNokiaHealthMeasureCategoryUnknown = @"unknown";
NSString * const PDKNokiaHealthMeasureCategoryRealMeasurements = @"real-measurements";
NSString * const PDKNokiaHealthMeasureCategoryUserObjectives = @"user-objectives";

NSString * const PDKNokiaHealthMeasureTypeUnknown = @"unknown";
NSString * const PDKNokiaHealthMeasureTypeWeight = @"weight";
NSString * const PDKNokiaHealthMeasureTypeHeight = @"height";
NSString * const PDKNokiaHealthMeasureTypeFatFreeMass = @"fat-free-mass";
NSString * const PDKNokiaHealthMeasureTypeFatRatio = @"fat-ratio";
NSString * const PDKNokiaHealthMeasureTypeFatMassWeight = @"fat-mass-weight";
NSString * const PDKNokiaHealthMeasureTypeDiastolicBloodPressure = @"diastolic-blood-pressure";
NSString * const PDKNokiaHealthMeasureTypeSystolicBloodPressure = @"systolic-blood-pressure";
NSString * const PDKNokiaHealthMeasureTypeHeartPulse = @"heart-pulse";
NSString * const PDKNokiaHealthMeasureTypeTemperature = @"temperature";
NSString * const PDKNokiaHealthMeasureTypeOxygenSaturation = @"oxygen-saturation";
NSString * const PDKNokiaHealthMeasureTypeBodyTemperature = @"body-temperature";
NSString * const PDKNokiaHealthMeasureTypeSkinTemperature = @"skin-temperature";
NSString * const PDKNokiaHealthMeasureTypeMuscleMass = @"muscle-mass";
NSString * const PDKNokiaHealthMeasureTypeHydration = @"hydration";
NSString * const PDKNokiaHealthMeasureTypeBoneMass = @"bone-mass";
NSString * const PDKNokiaHealthMeasureTypePulseWaveVelocity = @"pulse-wave-velocity";

NSString * const PDKNokiaHealthAlert = @"pdk-nokia-health-alert"; //!OCLINT
NSString * const PDKNokiaHealthAlertMisconfigured = @"pdk-nokia-health-misconfigured-alert"; //!OCLINT

@interface PDKNokiaHealthGenerator()

@property NSMutableArray * listeners;

@property id<OIDExternalUserAgentSession> currentExternalUserAgentFlow;
@property NSDictionary * options;

@property sqlite3 * database;

@property NSMutableArray * pendingRequests;
@property BOOL isExecuting;

@property NSTimeInterval waitUntil;

@property NSMutableSet * requestedURLs;

@end

static PDKNokiaHealthGenerator * sharedObject = nil;

@implementation PDKNokiaHealthGenerator

+ (PDKNokiaHealthGenerator *) sharedInstance {
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
        
        self.options = @{};
        
        self.database = [self openDatabase];
        
        self.pendingRequests = [NSMutableArray array];
        self.isExecuting = NO;
        
        self.waitUntil = 0;
        
        self.requestedURLs = [NSMutableSet set];
    }
    
    return self;
}

- (void) updateOptions:(NSDictionary *) options {
    if (options == nil) {
        options = @{}; //!OCLINT
    }
    
    self.options = options;
    
    [self refresh];
}

+ (NSString *) title {
    return NSLocalizedStringFromTableInBundle(@"name_generator_nokia_health", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
}

- (void) refresh {
    BOOL authed = YES;
    
    if (self.options[PDKNokiaHealthClientID] == nil || self.options[PDKNokiaHealthCallbackURL] == nil || self.options[PDKNokiaHealthClientSecret] == nil) {
        NSString * title = NSLocalizedStringFromTableInBundle(@"title_generator_nokia_health_app_misconfigured", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
        NSString * message = NSLocalizedStringFromTableInBundle(@"message_generator_nokia_health_app_misconfigured", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
        
        [[PassiveDataKit sharedInstance] updateAlertWithTag:PDKNokiaHealthAlertMisconfigured title:title message:message level:PDKAlertLevelError action:^{}];
    } else {
        [[PassiveDataKit sharedInstance] cancelAlertWithTag:PDKNokiaHealthAlertMisconfigured];
    }
    
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    NSData * authStateData = [defaults valueForKey:PDKNokiaHealthAuthState];
    
    if (authed && authStateData == nil) {
        authed = NO;
    }

    NSNumber * isMandatory = self.options[PDKNokiaHealthLoginMandatory];
    
    if (isMandatory == nil) {
        isMandatory = @(YES);
    }

    if (isMandatory.boolValue && authed == NO) {
        NSString * title = NSLocalizedStringFromTableInBundle(@"title_generator_nokia_health_needs_auth", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
        NSString * message = NSLocalizedStringFromTableInBundle(@"message_generator_nokia_health_needs_auth", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
        
        [[PassiveDataKit sharedInstance] updateAlertWithTag:PDKNokiaHealthAlert title:title message:message level:PDKAlertLevelError action:^{
            [[PDKNokiaHealthGenerator sharedInstance] loginToService:^{
                
            } failure:^{

            }];
        }];
    } else {
        [[PassiveDataKit sharedInstance] cancelAlertWithTag:PDKNokiaHealthAlert];
    }

    if (authed) {
        void (^toExecute)(NSString *) = ^void(NSString * accessToken) {
            [self.requestedURLs removeAllObjects];

            NSNumber * activitiesEnabled = self.options[PDKNokiaHealthActivityMeasuresEnabled];
            
            if (activitiesEnabled == nil) {
                activitiesEnabled = @(YES);
            }
            
            if (activitiesEnabled.boolValue) {
                [self fetchActivityMeasuresWithAccessToken:accessToken date:[NSDate date] callback:^{
                    [self.requestedURLs removeAllObjects];
                }];
            }
            
            NSNumber * intradayActivitiesEnabled = self.options[PDKNokiaHealthIntradayActivityMeasuresEnabled];
            
            if (intradayActivitiesEnabled == nil) {
                intradayActivitiesEnabled = @(YES);
            }
            
            if (intradayActivitiesEnabled.boolValue) {
                [self fetchIntradayActivityMeasuresWithAccessToken:accessToken date:[NSDate date] callback:^{
                    [self.requestedURLs removeAllObjects];
                }];
            }
            
            NSNumber * sleepMeasuresEnabled = self.options[PDKNokiaHealthSleepMeasuresEnabled];
            
            if (sleepMeasuresEnabled == nil) {
                sleepMeasuresEnabled = @(YES);
            }
            
            if (sleepMeasuresEnabled.boolValue) {
                [self fetchSleepMeasuresWithAccessToken:accessToken];
            }
            
            NSNumber * sleepSummaryEnabled = self.options[PDKNokiaHealthSleepSummaryEnabled];
            
            if (sleepSummaryEnabled == nil) {
                sleepSummaryEnabled = @(YES);
            }
            
            if (sleepSummaryEnabled.boolValue) {
                [self fetchSleepSummaryWithAccessToken:accessToken];
            }
            
            NSNumber * bodyEnabled = self.options[PDKNokiaHealthBodyMeasuresEnabled];
            
            if (bodyEnabled == nil) {
                bodyEnabled = @(YES);
            }
            
            if (bodyEnabled.boolValue) {
                [self fetchBodyMeasuresWithAccessToken:accessToken];
            }
            
            [[PassiveDataKit sharedInstance] cancelAlertWithTag:PDKNokiaHealthAlert];
        };
        
        [self executeRequest:toExecute error:^(NSDictionary * error) {
            NSLog(@"ERROR WHILE REFRESHING: %@", error);
        }];
    }
}

- (void) fetchActivityMeasuresWithAccessToken:(NSString *) accessToken date:(NSDate *) date callback:(void (^)(void)) callback {
    __weak __typeof(self) weakSelf = self;
    
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    
    NSCalendar * calendar = [NSCalendar currentCalendar];
    
    NSDate * today = [calendar startOfDayForDate:date];
    
    NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";

    NSString * urlString = [NSString stringWithFormat:@"https://api.health.nokia.com/v2/measure?action=getactivity&access_token=%@&startdateymd=%@&enddateymd=%@", accessToken, [formatter stringFromDate:today], [formatter stringFromDate:today]];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                    
                                                } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                    
                                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                    if (error != nil) {
                                                        [self processError:error responseObject:responseObject];
                                                    } else {
                                                        if ([responseObject[@"status"] integerValue] == 0) {
                                                            [weakSelf logActivityMeasures:responseObject];
                                                            
                                                            if (callback != nil) {
                                                                callback();
                                                            }
                                                        } else {
                                                            [self processError:nil responseObject:responseObject];
                                                            
                                                            if (callback != nil) {
                                                                callback();
                                                            }
                                                        }
                                                    }
                                                }];
    [task resume];
}

- (void) logActivityMeasures:(id) responseObject {
    NSNumber * status = [responseObject valueForKey:@"status"];
    
    NSNumber * now = @([[NSDate date] timeIntervalSince1970] * 1000);
    
    if (status != nil) {
        if (status.integerValue == 0) {
            NSCalendar * calendar = [NSCalendar currentCalendar];
            
            NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"yyyy-MM-dd";
            
            NSDictionary * body = [responseObject valueForKey:@"body"];
            
            NSArray * activities = body[@"activities"];
            
            for (NSDictionary * activity in activities) {
                NSDate * dateStart = [calendar startOfDayForDate:[formatter dateFromString:activity[@"date"]]];
                NSNumber * steps = activity[@"steps"];
                
                BOOL logNew = YES;
                
                sqlite3_stmt * statement = NULL;
                
                NSString * querySQL = @"SELECT A._id FROM activity_measure_history A WHERE A.date_start = ? AND A.steps = ?";
                
                const char * query_stmt = [querySQL UTF8String];
                
                @synchronized(self) {
                    if (sqlite3_prepare_v2(self.database, query_stmt, -1, &statement, NULL) == SQLITE_OK) { //!OCLINT
                        sqlite3_bind_int64(statement, 1, (long) (dateStart.timeIntervalSince1970 * 1000));
                        sqlite3_bind_int64(statement, 2, steps.longValue);
                        
                        if (sqlite3_step(statement) == SQLITE_ROW) {
                            logNew = NO;
                        }
                        
                        sqlite3_finalize(statement);
                    } else {
                        NSLog(@"ERROR Activity QUERYING");
                    }
                }
                
                if (logNew) {
                    NSMutableDictionary * data = [NSMutableDictionary dictionary];
                    
                    data[PDKNokiaHealthFetched] = now;
                    data[PDKNokiaHealthObserved] = now;
                    
                    data[PDKNokiaHealthDateStart] = @(dateStart.timeIntervalSince1970 * 1000);
                    data[PDKNokiaHealthTimezone] = activity[@"timezone"];
                    data[PDKNokiaHealthSteps] = activity[@"steps"];
                    data[PDKNokiaHealthDistance] = activity[@"distance"];
                    data[PDKNokiaHealthActiveCalories] = activity[@"calories"];
                    data[PDKNokiaHealthTotalCalories] = activity[@"totalcalories"];
                    data[PDKNokiaHealthElevation] = activity[@"elevation"];
                    data[PDKNokiaHealthSoftActivityDuration] = activity[@"soft"];
                    data[PDKNokiaHealthModerateActivityDuration] = activity[@"moderate"];
                    data[PDKNokiaHealthIntenseActivityDuration] = activity[@"intense"];
                    
                    data[PDKNokiaHealthDataStream] = PDKNokiaHealthDataStreamActivityMeasures;
                    
                    [[PassiveDataKit sharedInstance] receivedData:data forGenerator:PDKNokiaHealth];
                    
                    sqlite3_stmt * stmt;
                    
                    NSString * insert = @"INSERT INTO activity_measure_history (fetched, observed, date_start, timezone, steps, distance, active_calories, total_calories, elevation, soft_activity_duration, moderate_activity_duration, intense_activity_duration) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";
                    
                    @synchronized(self) {
                        int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL);
                        
                        if (retVal == SQLITE_OK) {
                            if (sqlite3_bind_double(stmt, 1, [data[PDKNokiaHealthFetched] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 2, [data[PDKNokiaHealthObserved] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 3, [data[PDKNokiaHealthDateStart] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_text(stmt, 4, [data[PDKNokiaHealthTimezone] cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 5, [data[PDKNokiaHealthSteps] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 6, [data[PDKNokiaHealthDistance] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 7, [data[PDKNokiaHealthActiveCalories] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 8, [data[PDKNokiaHealthTotalCalories] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 9, [data[PDKNokiaHealthElevation] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 10, [data[PDKNokiaHealthSoftActivityDuration] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 11, [data[PDKNokiaHealthModerateActivityDuration] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 12, [data[PDKNokiaHealthIntenseActivityDuration] doubleValue]) == SQLITE_OK) {
                                
                                int retVal = sqlite3_step(stmt);
                                
                                if (SQLITE_DONE != retVal) {
                                    NSLog(@"Error while inserting data. %d '%s'", retVal, sqlite3_errmsg(self.database));
                                }
                            }
                            
                            sqlite3_finalize(stmt);
                        }
                    }
                }
            }
        } else if (status.integerValue == 401) {
            [self logout];
        }
    }
}

- (void) fetchIntradayActivityMeasuresWithAccessToken:(NSString *) accessToken date:(NSDate *) date callback:(void (^)(void)) callback {
    __weak __typeof(self) weakSelf = self;
    
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    
    NSCalendar * calendar = [NSCalendar currentCalendar];
    
    NSDate * today = [calendar startOfDayForDate:date];
    NSDate * tomorrow = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:today options:0];
    
    NSString * urlString = [NSString stringWithFormat:@"https://api.health.nokia.com/v2/measure?action=getintradayactivity&access_token=%@&startdate=%ld&enddate=%ld", accessToken, (long) today.timeIntervalSince1970, (long) tomorrow.timeIntervalSince1970];
    
    if ([self.requestedURLs containsObject:urlString]) {
        if (callback != nil) {
            callback();
        }
        
        return;
    }
    
    [self.requestedURLs addObject:urlString];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                    
                                                } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                    
                                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                    if (error != nil) {
                                                        [self processError:error responseObject:responseObject];

                                                        if (callback != nil) {
                                                            callback();
                                                        }
                                                    } else {
                                                        // NSLog(@"NH RESPONSE OBJ: %@", responseObject);
                                                        
                                                        if ([responseObject[@"status"] integerValue] == 0) {
                                                            [weakSelf logIntradayActivityMeasures:responseObject];
                                                            
                                                            if (callback != nil) {
                                                                callback();
                                                            }
                                                        } else {
                                                            [self processError:nil responseObject:responseObject];

                                                            if (callback != nil) {
                                                                callback();
                                                            }
                                                        }
                                                    }
                                                }];
    [task resume];
}

- (void) logIntradayActivityMeasures:(id) responseObject {
    NSNumber * status = [responseObject valueForKey:@"status"];
    
    NSNumber * now = @([[NSDate date] timeIntervalSince1970] * 1000);
    
    if (status != nil) {
        if (status.integerValue == 0) {
            NSDictionary * body = [responseObject valueForKey:@"body"];
            
            NSDictionary * series = body[@"series"];
            
            for (NSString * timestampKey in series.allKeys) {
                NSDictionary * activity = series[timestampKey];
                
                BOOL logNew = YES;
                
                sqlite3_stmt * statement = NULL;
                
                NSString * querySQL = @"SELECT I._id FROM intraday_activity_history I WHERE I.activity_start >= ? AND I.activity_start < ?";
                
                const char * query_stmt = [querySQL UTF8String];
                
                @synchronized(self) {
                    if (sqlite3_prepare_v2(self.database, query_stmt, -1, &statement, NULL) == SQLITE_OK) { //!OCLINT
                        sqlite3_bind_double(statement, 1, floor(timestampKey.doubleValue) - 1);
                        sqlite3_bind_double(statement, 2, floor(timestampKey.doubleValue) + 1);
                        
                        int retVal = sqlite3_step(statement);
                        
                        if (retVal == SQLITE_ROW) {
                            logNew = NO;
                        }
                        
                        sqlite3_finalize(statement);
                    } else {
                        NSLog(@"ERROR WEIGHT QUERYING");
                    }
                }
                
                if (logNew) {
                    NSMutableDictionary * data = [NSMutableDictionary dictionary];
                    
                    data[PDKNokiaHealthFetched] = now;
                    data[PDKNokiaHealthObserved] = now;
                    
                    data[PDKNokiaHealthIntradayActivityStart] = @(timestampKey.doubleValue);
                    data[PDKNokiaHealthIntradayActivityDuration] = activity[@"duration"];
                    
                    if (activity[@"calories"] != nil) {
                        data[PDKNokiaHealthIntradayCalories] = activity[@"calories"];
                    } else {
                        data[PDKNokiaHealthIntradayCalories] = @(0);
                    }
                    
                    if (activity[@"distance"] != nil) {
                        data[PDKNokiaHealthIntradayDistance] = activity[@"distance"];
                    } else {
                        data[PDKNokiaHealthIntradayDistance] = @(0);
                    }
                    
                    if (activity[@"steps"] != nil) {
                        data[PDKNokiaHealthIntradaySteps] = activity[@"steps"];
                    } else {
                        data[PDKNokiaHealthIntradaySteps] = @(0);
                    }
                    
                    if (activity[@"elevation_climbed"] != nil) {
                        data[PDKNokiaHealthIntradayElevationClimbed] = activity[@"elevation_climbed"];
                    } else {
                        data[PDKNokiaHealthIntradayElevationClimbed] = @(0);
                    }
                    
                    if (activity[@"swim_strokes"] != nil) {
                        data[PDKNokiaHealthIntradaySwimStrokes] = activity[@"swim_strokes"];
                    } else {
                        data[PDKNokiaHealthIntradaySwimStrokes] = @(0);
                    }
                    
                    if (activity[@"pool_laps"] != nil) {
                        data[PDKNokiaHealthIntradayPoolLaps] = activity[@"pool_laps"];
                    } else {
                        data[PDKNokiaHealthIntradayPoolLaps] = @(0);
                    }
                    
                    data[PDKNokiaHealthDataStream] = PDKNokiaHealthDataStreamIntradayActivityMeasures;
                    
                    [[PassiveDataKit sharedInstance] receivedData:data forGenerator:PDKNokiaHealth];

                    @synchronized(self) {
                        sqlite3_stmt * stmt;
                        
                        NSString * insert = @"INSERT INTO intraday_activity_history (fetched, observed, activity_start, activity_duration, calories, distance, elevation_climbed, steps, swim_strokes, pool_laps) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";
                        
                        int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL);
                        
                        if (retVal == SQLITE_OK) {
                            if (sqlite3_bind_double(stmt, 1, [data[PDKNokiaHealthFetched] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 2, [data[PDKNokiaHealthObserved] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 3, [data[PDKNokiaHealthIntradayActivityStart] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 4, [data[PDKNokiaHealthIntradayActivityDuration] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 5, [data[PDKNokiaHealthIntradayCalories] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 6, [data[PDKNokiaHealthIntradayDistance] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 7, [data[PDKNokiaHealthIntradayElevationClimbed] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 8, [data[PDKNokiaHealthIntradaySteps] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 9, [data[PDKNokiaHealthIntradaySwimStrokes] doubleValue]) == SQLITE_OK &&
                                sqlite3_bind_double(stmt, 10, [data[PDKNokiaHealthIntradayPoolLaps] doubleValue]) == SQLITE_OK) {
                                
                                int retVal = sqlite3_step(stmt);
                                
                                if (SQLITE_DONE != retVal) {
                                    NSLog(@"Error while inserting data. %d '%s'", retVal, sqlite3_errmsg(self.database));
                                }
                            }
                            
                            sqlite3_finalize(stmt);
                        }
                    }
                }
            }
        } else if (status.integerValue == 401) {
            [self logout];
        }
    }
}

- (void) fetchSleepMeasuresWithAccessToken:(NSString *) accessToken {
    __weak __typeof(self) weakSelf = self;
    
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];

    NSCalendar * calendar = [NSCalendar currentCalendar];
    
    NSDate * today = [calendar startOfDayForDate:[NSDate date]];
    NSDate * tomorrow = [calendar startOfDayForDate:[NSDate dateWithTimeIntervalSinceNow:(24 * 60 * 60)]];
    
    NSString * urlString = [NSString stringWithFormat:@"https://api.health.nokia.com/v2/sleep?action=get&access_token=%@&startdate=%ld&enddate=%ld", accessToken, (long) today.timeIntervalSince1970, (long) tomorrow.timeIntervalSince1970];

    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];

    NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                    
                                                } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                    
                                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                    if (error != nil) {
                                                        [self processError:error responseObject:responseObject];
                                                    } else {
                                                        if ([responseObject[@"status"] integerValue] == 0) {
                                                            [weakSelf logSleepMeasures:responseObject];
                                                        } else {
                                                            [self processError:nil responseObject:responseObject];
                                                        }
                                                    }
                                                }];
    [task resume];
}

- (void) logSleepMeasures:(id) responseObject {
    NSLog(@"NH SLEEP MEASURES: %@", responseObject);
}

- (void) fetchSleepSummaryWithAccessToken:(NSString *) accessToken {
    __weak __typeof(self) weakSelf = self;
    
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];

    NSCalendar * calendar = [NSCalendar currentCalendar];

    NSDate * today = [calendar startOfDayForDate:[NSDate date]];
    NSDate * tomorrow = [calendar startOfDayForDate:[NSDate dateWithTimeIntervalSinceNow:(24 * 60 * 60)]];
    
    NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";

    NSString * urlString = [NSString stringWithFormat:@"https://api.health.nokia.com/v2/sleep?action=getsummary&access_token=%@&startdateymd=%@&enddateymd=%@", accessToken, [formatter stringFromDate:today], [formatter stringFromDate:tomorrow]];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];

    NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                    
                                                } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                    
                                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                    if (error != nil) {
                                                        [self processError:error responseObject:responseObject];
                                                    } else {
                                                        if ([responseObject[@"status"] integerValue] == 0) {
                                                            [weakSelf logSleepSummary:responseObject];
                                                        } else {
                                                            [self processError:nil responseObject:responseObject];
                                                        }
                                                    }
                                                }];
    [task resume];
}

- (void) logSleepSummary:(id) responseObject {
    NSLog(@"NH SLEEP SUMMARY: %@", responseObject);
    NSLog(@"NH SLEEP TODO w/ TEST DATA: %@", responseObject);
}

- (void) fetchBodyMeasuresWithAccessToken:(NSString *) accessToken {
    __weak __typeof(self) weakSelf = self;
    
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/plain", @"application/json", nil];

    NSCalendar * calendar = [NSCalendar currentCalendar];
    
    NSDate * today = [calendar startOfDayForDate:[NSDate date]];
    NSDate * tomorrow = [calendar startOfDayForDate:[NSDate dateWithTimeIntervalSinceNow:(24 * 60 * 60)]];
    
    NSString * urlString = [NSString stringWithFormat:@"https://api.health.nokia.com/measure?action=getmeas&access_token=%@&startdate=%ld&enddate=%ld", accessToken, (long) today.timeIntervalSince1970, (long) tomorrow.timeIntervalSince1970];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
   
    NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                    
                                                } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                    
                                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                    if (error != nil) {
                                                        [self processError:error responseObject:responseObject];
                                                    } else {
                                                        if ([responseObject[@"status"] integerValue] == 0) {
                                                            [weakSelf logSleepSummary:responseObject];
                                                        } else {
                                                            [self processError:nil responseObject:responseObject];
                                                        }
                                                    }
                                                }];
    [task resume];
}

- (void) logBodyMeasures:(id) responseObject {
    NSNumber * status = [responseObject valueForKey:@"status"];
    
    NSNumber * now = @([[NSDate date] timeIntervalSince1970] * 1000);
    
    if (status != nil) {
        if (status.integerValue == 0) {
            NSDictionary * body = [responseObject valueForKey:@"body"];
            
            NSArray * measureGroups = body[@"measuregrps"];
            
            for (NSDictionary * group in measureGroups) {
                NSMutableDictionary * data = [NSMutableDictionary dictionary];
                
                data[PDKNokiaHealthFetched] = now;
                data[PDKNokiaHealthObserved] = now;
                data[PDKNokiaHealthDataStream] = PDKNokiaHealthDataStreamBodyMeasures;
                
                data[PDKNokiaHealthMeasureDate] = group[@"date"];
                
                NSNumber * attribValue = group[@"attrib"];
                
                data[PDKNokiaHealthMeasureStatus] = PDKNokiaHealthMeasureStatusUnknown;
                
                switch (attribValue.integerValue) {
                    case 0:
                        data[PDKNokiaHealthMeasureStatus] = PDKNokiaHealthMeasureStatusUserDevice;
                        break;
                    case 1:
                        data[PDKNokiaHealthMeasureStatus] = PDKNokiaHealthMeasureStatusSharedDevice;
                        break;
                    case 2:
                        data[PDKNokiaHealthMeasureStatus] = PDKNokiaHealthMeasureStatusManualEntry;
                        break;
                    case 4:
                        data[PDKNokiaHealthMeasureStatus] = PDKNokiaHealthMeasureStatusManualEntryCreation;
                        break;
                    case 5:
                        data[PDKNokiaHealthMeasureStatus] = PDKNokiaHealthMeasureStatusAutoDevice;
                        break;
                    case 7:
                        data[PDKNokiaHealthMeasureStatus] = PDKNokiaHealthMeasureStatusMeasureConfirmed;
                        break;
                };
                
                data[PDKNokiaHealthMeasureCategory] = PDKNokiaHealthMeasureCategoryUnknown;
                
                NSNumber * categoryNumber = group[@"category"];
                
                if (categoryNumber.integerValue == 1) {
                    data[PDKNokiaHealthMeasureCategory] = PDKNokiaHealthMeasureCategoryRealMeasurements;
                } else if (categoryNumber.integerValue == 2) {
                    data[PDKNokiaHealthMeasureCategory] = PDKNokiaHealthMeasureCategoryUserObjectives;
                }
                
                NSArray * measures = group[@"measures"];
                
                for (NSDictionary * measure in measures) {
                    NSMutableDictionary * newData = [NSMutableDictionary dictionaryWithDictionary:data];
                    
                    NSNumber * measureType = measure[@"type"];
                    
                    newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeUnknown;
                    
                    switch (measureType.integerValue) {
                        case 1:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeWeight;
                            break;
                        case 4:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeHeight;
                            break;
                        case 5:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeFatFreeMass;
                            break;
                        case 6:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeFatRatio;
                            break;
                        case 8:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeFatMassWeight;
                            break;
                        case 9:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeDiastolicBloodPressure;
                            break;
                        case 10:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeSystolicBloodPressure;
                            break;
                        case 11:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeHeartPulse;
                            break;
                        case 12:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeTemperature;
                            break;
                        case 54:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeOxygenSaturation;
                            break;
                        case 71:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeBodyTemperature;
                            break;
                        case 73:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeSkinTemperature;
                            break;
                        case 76:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeMuscleMass;
                            break;
                        case 77:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeHydration;
                            break;
                        case 88:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypeBoneMass;
                            break;
                        case 91:
                            newData[PDKNokiaHealthMeasureType] = PDKNokiaHealthMeasureTypePulseWaveVelocity;
                            break;
                    }
                    
                    BOOL logNew = YES;
                    
                    NSNumber * value = measure[@"value"];
                    NSNumber * unit = measure[@"unit"];
                    
                    newData[PDKNokiaHealthMeasureValue] = @(value.doubleValue * pow(10, unit.doubleValue));
                    
                    sqlite3_stmt * statement = NULL;
                    
                    NSString * querySQL = @"SELECT M._id FROM body_measure_history M WHERE M.measure_date = ? AND M.measure_status = ? AND M.measure_category = ? AND M.measure_type = ? AND M.measure_value = ?";
                    
                    const char * query_stmt = [querySQL UTF8String];

                    @synchronized(self) {
                        if (sqlite3_prepare_v2(self.database, query_stmt, -1, &statement, NULL) == SQLITE_OK) { //!OCLINT
                            sqlite3_bind_int64(statement, 1, [data[PDKNokiaHealthMeasureDate] doubleValue]);
                            sqlite3_bind_text(statement, 2, [data[PDKNokiaHealthMeasureStatus] cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT) == SQLITE_OK &&
                            sqlite3_bind_text(statement, 3, [data[PDKNokiaHealthMeasureCategory] cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT) == SQLITE_OK &&
                            sqlite3_bind_text(statement, 4, [data[PDKNokiaHealthMeasureType] cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT) == SQLITE_OK &&
                            sqlite3_bind_double(statement, 5, [data[PDKNokiaHealthMeasureValue] doubleValue]);
                            
                            if (sqlite3_step(statement) == SQLITE_ROW) {
                                logNew = NO;
                            }
                            
                            sqlite3_finalize(statement);
                        } else {
                            NSLog(@"ERROR BODY QUERYING");
                        }
                    }
                    
                    if (logNew) {
                        [[PassiveDataKit sharedInstance] receivedData:newData forGenerator:PDKNokiaHealth];
                        
                        @synchronized(self) {
                            sqlite3_stmt * stmt;
                            
                            NSString * insert = @"INSERT INTO body_measure_history (fetched, observed, measure_date, measure_status, measure_category, measure_type, measure_value) VALUES (?, ?, ?, ?, ?, ?, ?);";
                            
                            int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL);
                            
                            if (retVal == SQLITE_OK) {
                                if (sqlite3_bind_double(stmt, 1, [data[PDKNokiaHealthFetched] doubleValue]) == SQLITE_OK &&
                                    sqlite3_bind_double(stmt, 2, [data[PDKNokiaHealthObserved] doubleValue]) == SQLITE_OK &&
                                    sqlite3_bind_double(stmt, 3, [data[PDKNokiaHealthMeasureDate] doubleValue]) == SQLITE_OK &&
                                    sqlite3_bind_text(stmt, 4, [data[PDKNokiaHealthMeasureStatus] cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT) == SQLITE_OK &&
                                    sqlite3_bind_text(stmt, 5, [data[PDKNokiaHealthMeasureCategory] cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT) == SQLITE_OK &&
                                    sqlite3_bind_text(stmt, 6, [data[PDKNokiaHealthMeasureType] cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT) == SQLITE_OK &&
                                    sqlite3_bind_double(stmt, 7, [data[PDKNokiaHealthMeasureValue] doubleValue])) {
                                    
                                    int retVal = sqlite3_step(stmt);
                                    
                                    if (SQLITE_DONE != retVal) {
                                        NSLog(@"Error while inserting data. %d '%s'", retVal, sqlite3_errmsg(self.database));
                                    }
                                }
                                
                                sqlite3_finalize(stmt);
                            }
                        }
                    }
                }
            }
        } else if (status.integerValue == 401) {
            [self logout];
        }
    }
}

- (BOOL)application:(UIApplication *) app openURL:(NSURL *) url options:(NSDictionary<NSString *, id> *) options {
    if (self.currentExternalUserAgentFlow == nil) {
        return NO;
    }
    
    if (self.options[PDKNokiaHealthCallbackURL] != nil && [url.description rangeOfString:self.options[PDKNokiaHealthCallbackURL]].location == 0) {
        if ([self.currentExternalUserAgentFlow resumeExternalUserAgentFlowWithURL:url]) {
            self.currentExternalUserAgentFlow = nil;
            
            return YES;
        }
    }
    
    return NO;
}

- (NSString *) databasePath {
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString * documentsPath = paths[0];
    
    NSString * dbPath = [documentsPath stringByAppendingPathComponent:@"pdk-nokia-health.sqlite3"];
    
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
            
            const char * createActivityStatement = "CREATE TABLE activity_measure_history(_id INTEGER PRIMARY KEY AUTOINCREMENT, fetched INTEGER, transmitted INTEGER, observed INTEGER, date_start INTEGER, timezone TEXT, steps REAL, distance REAL, active_calories REAL, total_calories REAL, elevation REAL, soft_activity_duration REAL, moderate_activity_duration REAL, intense_activity_duration REAL);";
            
            if (sqlite3_exec(database, createActivityStatement, NULL, NULL, &error) != SQLITE_OK) { //!OCLINT
                
            }

            const char * createIntradayActivityStatement = "CREATE TABLE intraday_activity_history(_id INTEGER PRIMARY KEY AUTOINCREMENT, fetched INTEGER, transmitted INTEGER, observed INTEGER, activity_start REAL, activity_duration REAL, calories REAL, distance REAL, elevation_climbed REAL, steps REAL, swim_strokes REAL, pool_laps REAL);";
            
            if (sqlite3_exec(database, createIntradayActivityStatement, NULL, NULL, &error) != SQLITE_OK) { //!OCLINT
                
            }

            const char * createBodyMeasureStatement = "CREATE TABLE body_measure_history(_id INTEGER PRIMARY KEY AUTOINCREMENT, fetched INTEGER, transmitted INTEGER, observed INTEGER, measure_date INTEGER, measure_status TEXT, measure_category TEXT, measure_type TEXT, measure_value REAL);";
            
            if (sqlite3_exec(database, createBodyMeasureStatement, NULL, NULL, &error) != SQLITE_OK) { //!OCLINT
                
            }
            
            const char * createSleepMeasureStatement = "CREATE TABLE sleep_measure_history(_id INTEGER PRIMARY KEY AUTOINCREMENT, fetched INTEGER, transmitted INTEGER, observed INTEGER, start_date REAL, end_date REAL, state TEXT, measurement_device TEXT);";
            
            if (sqlite3_exec(database, createSleepMeasureStatement, NULL, NULL, &error) != SQLITE_OK) { //!OCLINT
                
            }
            
            const char * createSleepSummaryStatement = "CREATE TABLE sleep_summary_history(_id INTEGER PRIMARY KEY AUTOINCREMENT, fetched INTEGER, transmitted INTEGER, observed INTEGER, start_date REAL, end_date REAL, timezone TEXT, measurement_device TEXT, wake_duration REAL, light_sleep_duration REAL, deep_sleep_duration REAL, rem_sleep_duration REAL, wake_count INTEGER, to_sleep_duration REAL, to_wake_duration REAL);";
            
            if (sqlite3_exec(database, createSleepSummaryStatement, NULL, NULL, &error) != SQLITE_OK) { //!OCLINT
                
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
    
    return database;
}

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options {
    if ([self.listeners containsObject:listener] == NO) {
        [self.listeners addObject:listener];
    }
}

- (void) removeListener:(id<PDKDataListener>)listener {
    [self.listeners removeObject:listener];
}


// + (UIViewController *) detailsController {
//    return [[PDKBatteryGeneratorViewController alloc] init];
// }

/* - (UIView *) visualizationForSize:(CGSize) size {
 sqlite3_stmt * statement = NULL;
 
 NSString * querySQL = @"SELECT B.timestamp FROM battery_data B";
 
 int retVal = sqlite3_prepare_v2(self.database, [querySQL UTF8String], -1, &statement, NULL);
 
 self.batteryDays = [NSMutableArray array];
 
 if (retVal == SQLITE_OK) {
 while (sqlite3_step(statement) == SQLITE_ROW) {
 NSTimeInterval timestamp = (NSTimeInterval) sqlite3_column_double(statement, 0);
 
 NSString * key = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
 
 if ([self.batteryDays containsObject:key] == NO) {
 [self.batteryDays addObject:key];
 }
 }
 
 sqlite3_finalize(statement);
 };
 
 [self.batteryDays sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
 return [obj2 compare:obj1];
 }];
 
 UITableView * tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height) style:UITableViewStylePlain];
 
 tableView.dataSource = self;
 tableView.delegate = self;
 tableView.separatorStyle = UITableViewCellSelectionStyleNone;
 tableView.backgroundColor = [UIColor darkGrayColor];
 tableView.bounces = NO;
 
 return tableView;
 }
 
 - (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
 return self.batteryDays.count;
 }
 
 - (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
 return 88;
 }
 
 - (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
 UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"PDKBatteryDataSourceCell"];
 
 if (cell == nil) {
 cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"PDKBatteryDataSourceCell"];
 
 cell.accessoryType = UITableViewCellAccessoryNone;
 cell.selectionStyle = UITableViewCellSelectionStyleNone;
 
 LineChartView * chartView = [[LineChartView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, [self tableView:tableView heightForRowAtIndexPath:indexPath])];
 chartView.backgroundColor = UIColor.blackColor;
 chartView.legend.enabled = NO;
 chartView.rightAxis.enabled = NO;
 chartView.chartDescription.enabled = NO;
 chartView.dragEnabled = NO;
 chartView.pinchZoomEnabled = NO;
 
 chartView.leftAxis.drawGridLinesEnabled = YES;
 chartView.leftAxis.axisMinimum = 0;
 chartView.leftAxis.axisMaximum = 100;
 chartView.leftAxis.drawLabelsEnabled = NO;
 
 chartView.xAxis.drawGridLinesEnabled = NO;
 chartView.xAxis.labelPosition = XAxisLabelPositionBottom;
 chartView.xAxis.axisMinimum = 0;
 chartView.xAxis.axisMaximum = 24;
 chartView.xAxis.drawGridLinesEnabled = YES;
 chartView.xAxis.labelTextColor = UIColor.lightGrayColor;
 chartView.xAxis.drawLabelsEnabled = NO;
 
 chartView.tag = 1000;
 
 [cell.contentView addSubview:chartView];
 
 UILabel * dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(tableView.frame.size.width - 40, 8, 32, 32)];
 dateLabel.textColor = [UIColor whiteColor];
 dateLabel.font = [UIFont boldSystemFontOfSize:14];
 dateLabel.backgroundColor = [UIColor darkGrayColor];
 dateLabel.textAlignment = NSTextAlignmentCenter;
 dateLabel.layer.cornerRadius = 5;
 dateLabel.layer.masksToBounds = YES;
 dateLabel.layer.opacity = 0.5;
 
 dateLabel.tag = 1001;
 
 [cell.contentView addSubview:dateLabel];
 }
 
 LineChartView * chartView = [cell.contentView viewWithTag:1000];
 
 NSString * key = self.batteryDays[indexPath.row];
 
 NSDate * date = [self.dateFormatter dateFromString:key];
 
 NSDate * startDate = [[NSCalendar currentCalendar] startOfDayForDate:date];
 
 NSTimeInterval start = startDate.timeIntervalSince1970;
 NSTimeInterval end = start + (24 * 60 * 60);
 
 NSString * querySQL = @"SELECT B.timestamp, B.level FROM battery_data B WHERE (B.timestamp >= ? AND B.timestamp < ?)";
 sqlite3_stmt * statement = NULL;
 
 NSMutableArray * levels = [[NSMutableArray alloc] init];
 
 int retVal = sqlite3_prepare_v2(self.database, [querySQL UTF8String], -1, &statement, NULL);
 
 if (retVal == SQLITE_OK) {
 sqlite3_bind_double(statement, 1, (double) start);
 
 retVal = sqlite3_bind_double(statement, 2, (double) end);
 
 if (retVal == SQLITE_OK) {
 while (sqlite3_step(statement) == SQLITE_ROW) {
 NSTimeInterval timestamp = (NSTimeInterval) sqlite3_column_double(statement, 0);
 double level = sqlite3_column_double(statement, 1);
 
 [levels addObject:[[BarChartDataEntry alloc] initWithX:((timestamp - start) / (60 * 60)) y:level]];
 }
 
 sqlite3_finalize(statement);
 };
 }
 
 LineChartDataSet * dataSet = [[LineChartDataSet alloc] initWithValues:levels label:@""];
 dataSet.drawIconsEnabled = NO;
 dataSet.drawValuesEnabled = NO;
 dataSet.drawCirclesEnabled = NO;
 dataSet.fillAlpha = 1.0;
 dataSet.drawFilledEnabled = YES;
 dataSet.lineWidth = 0.0;
 dataSet.fillColor = [UIColor colorWithRed:0.0f green:1.0 blue:0.0 alpha:0.5];
 
 LineChartData * data = [[LineChartData alloc] initWithDataSets:@[dataSet]];
 [data setValueFont:[UIFont systemFontOfSize:10.f]];
 
 chartView.data = data;
 
 NSString * dateString = [self.dateDisplayFormatter stringFromDate:date];
 
 UILabel * dateLabel = [cell.contentView viewWithTag:1001];
 
 CGSize dateSize = [dateString sizeWithAttributes:@{NSFontAttributeName:dateLabel.font}];
 dateSize.width += 10;
 dateSize.height += 10;
 
 CGRect viewFrame = chartView.frame;
 
 dateLabel.text = dateString;
 dateLabel.frame = CGRectMake(floor((viewFrame.size.width - dateSize.width) / 2), floor((viewFrame.size.height - dateSize.height) / 2), dateSize.width, dateSize.height);
 
 return cell;
 }
 
 */


- (BOOL) isAuthenticated {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    NSData * authStateData = [defaults valueForKey:PDKNokiaHealthAuthState];
    
    return authStateData != nil;
}

- (void) loginToService:(void (^)(void))success failure:(void (^)(void))failure {
    NSURL * authorizationEndpoint = [NSURL URLWithString:@"https://account.health.nokia.com/oauth2_user/authorize2"];
    NSURL * tokenEndpoint = [NSURL URLWithString:@"https://account.health.nokia.com/oauth2/token"];
    
    OIDServiceConfiguration * configuration = [[OIDServiceConfiguration alloc] initWithAuthorizationEndpoint:authorizationEndpoint
                                                                                               tokenEndpoint:tokenEndpoint];
    
    NSArray * scopes = self.options[PDKNokiaHealthScopes];
    
    if (scopes == nil || scopes.count == 0) {
        scopes = @[PDKNokiaHealthScopeUserInfo, PDKNokiaHealthScopeUserMetrics, PDKNokiaHealthScopeUserActivity];
    }
    
    NSMutableString * scopeString = [NSMutableString string];
    
    for (NSString * scope in scopes) {
        if (scopeString.length > 0) {
            [scopeString appendString:@","];
        }
        
        [scopeString appendString:scope];
    }
    
    NSDictionary * addParams = @{
                                 @"client_id": self.options[PDKNokiaHealthClientID],
                                 @"client_secret": self.options[PDKNokiaHealthClientSecret]
                                 };
    
    OIDAuthorizationRequest * request = [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                                                                   clientId:self.options[PDKNokiaHealthClientID]
                                                                                               clientSecret:self.options[PDKNokiaHealthClientSecret]
                                                                                                      scope:scopeString
                                                                                                redirectURL:[NSURL URLWithString:self.options[PDKNokiaHealthCallbackURL]]
                                                                                               responseType:OIDResponseTypeCode
                                                                                                      state:@"state-token"
                                                                                                      nonce:nil
                                                                                               codeVerifier:nil
                                                                                              codeChallenge:nil
                                                                                        codeChallengeMethod:nil
                                                                                       additionalParameters:addParams];

    UIWindow * window = [[[UIApplication sharedApplication] delegate] window];
    
    OIDExternalUserAgentIOS *externalUserAgent = [[OIDExternalUserAgentIOS alloc] initWithPresentingViewController:window.rootViewController];
    
    self.currentExternalUserAgentFlow = [OIDAuthorizationService
                                         presentAuthorizationRequest:request
                                         externalUserAgent:externalUserAgent
                                         callback:^(OIDAuthorizationResponse *_Nullable authorizationResponse,
                                                    NSError *_Nullable authorizationError) {
                                             // inspects response and processes further if needed (e.g. authorization
                                             // code exchange)
                                             if (authorizationResponse) {
                                                 if ([request.responseType
                                                      isEqualToString:OIDResponseTypeCode]) {
                                                     // if the request is for the code flow (NB. not hybrid), assumes the
                                                     // code is intended for this client, and performs the authorization
                                                     // code exchange
                                                     OIDTokenRequest *tokenExchangeRequest = [authorizationResponse tokenExchangeRequestWithAdditionalParameters:addParams];
                                                     
                                                     [OIDAuthorizationService performTokenRequest:tokenExchangeRequest
                                                                    originalAuthorizationResponse:authorizationResponse
                                                                                         callback:^(OIDTokenResponse *_Nullable tokenResponse,
                                                                                                    NSError *_Nullable tokenError) {
                                                                                             OIDAuthState *authState = nil;
                                                                                             
                                                                                             if (tokenResponse) {
                                                                                                 authState = [[OIDAuthState alloc]
                                                                                                              initWithAuthorizationResponse:
                                                                                                              authorizationResponse
                                                                                                              tokenResponse:tokenResponse];
                                                                                             }
                                                                                             
                                                                                             if (authState) {
                                                                                                 NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
                                                                                                 
                                                                                                 NSData * authData = [NSKeyedArchiver archivedDataWithRootObject:authState];
                                                                                                 
                                                                                                 [defaults setValue:authData
                                                                                                             forKey:PDKNokiaHealthAuthState];
                                                                                                 [defaults synchronize];
                                                                                                 
                                                                                                 [[PDKNokiaHealthGenerator sharedInstance] refresh];

                                                                                                 if (success != nil) {
                                                                                                     success();
                                                                                                 }
                                                                                             } else {
                                                                                                 NSLog(@"NH Authorization error: %@", [tokenError localizedDescription]);

                                                                                                 if (failure != nil) {
                                                                                                     failure();
                                                                                                 }
                                                                                             }
                                                                                         }];
                                                 }
                                             }
                                         }];
}

- (void) logout {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    [defaults removeObjectForKey:PDKNokiaHealthAuthState];
    [defaults synchronize];
    
    [self.pendingRequests removeAllObjects];
}


- (void) stepsBetweenStart:(NSTimeInterval) start end:(NSTimeInterval) end callback:(void (^)(NSTimeInterval start, NSTimeInterval end, CGFloat steps)) callback backfill:(BOOL) doBackfill {
    
    NSNumber * steps = nil;
    
    sqlite3_stmt * statement = NULL;
    
    NSString * select = @"SELECT A.steps FROM intraday_activity_history A WHERE A.activity_start >= ? AND A.activity_start < ? ORDER BY A.steps DESC";
    
    const char * query_stmt = [select UTF8String];
    
    @synchronized(self) {
        if (sqlite3_prepare_v2(self.database, query_stmt, -1, &statement, NULL) == SQLITE_OK) { //!OCLINT
            sqlite3_bind_double(statement, 1, start);
            sqlite3_bind_double(statement, 2, end);
            
            double stepsSum = 0;
            
            NSUInteger count = 0;

            while (sqlite3_step(statement) == SQLITE_ROW) {
                stepsSum += sqlite3_column_double(statement, 0);
                
                count += 1;
            }
            
            sqlite3_finalize(statement);

            if (count > 0) {
                steps = @(stepsSum);
            }
        }
        
        if (steps == nil) {
            if (sqlite3_prepare_v2(self.database, query_stmt, -1, &statement, NULL) == SQLITE_OK) { //!OCLINT
                NSCalendar * calendar = [NSCalendar currentCalendar];
                
                NSDate * startDate = [calendar startOfDayForDate:[NSDate dateWithTimeIntervalSinceNow:start]];
                NSDate * endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
                
                sqlite3_bind_double(statement, 1, start);
                sqlite3_bind_double(statement, 2, endDate.timeIntervalSince1970);
                
                if (sqlite3_step(statement) == SQLITE_ROW) {
                    steps = @(0);
                }
                
                sqlite3_finalize(statement);
            }
        }
    }

    if (steps == nil && doBackfill == NO) {
        steps = @(0);
    }

    if (steps != nil) {
        callback(start, end, steps.doubleValue);
    } else if (doBackfill){
        void (^toExecute)(NSString *) = ^void(NSString * accessToken) {
            NSDate * date = [NSDate dateWithTimeIntervalSince1970:start];
            
            [self fetchIntradayActivityMeasuresWithAccessToken:accessToken
                                                          date:date
                                                      callback:^{
                                                          [self stepsBetweenStart:start end:end callback:callback backfill:NO];
                                                      }];
        };
        
        [self executeRequest:toExecute error:^(NSDictionary * error) {
            callback(start, end, 0);
        }];
    } else {
        callback(start, end, 0);
    }
}

- (void) processError:(NSError *) error responseObject:(id) responseObject {
    if (error != nil) {
        if (error.userInfo[@"com.alamofire.serialization.response.error.data"] != nil) {
            id errorObj = [NSJSONSerialization JSONObjectWithData:error.userInfo[@"com.alamofire.serialization.response.error.data"]
                                                          options:0
                                                            error:nil];
            
            if ([errorObj isKindOfClass:[NSDictionary class]]) {
                NSArray * errors = [errorObj valueForKey:@"errors"];
                
                for (NSDictionary * error in errors) {
                    if ([@"expired_token" isEqualToString:error[@"errorType"]]) {
                        [self logout];
                    }
                }
            }
        }
    } else if (responseObject != nil) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary * responseDict = (NSDictionary *) responseObject;
            
            NSNumber * status = responseDict[@"status"];
            
            if (status.integerValue == 601) {
                self.waitUntil = [NSDate date].timeIntervalSince1970 + 60 * 60;
            } else if (status.integerValue == 401) {
                [self logout];
            }
        }
        
    } else {
        NSLog(@"NH: UNKNOWN ERROR");
    }
}

- (void) executeRequest:(void(^)(NSString *)) executeBlock error:(void(^)(NSDictionary *)) errorBlock {
    @synchronized(self.pendingRequests) {
        [self.pendingRequests addObject:executeBlock];
    }
    
    if (self.isExecuting) {
        return;
    }
    
    self.isExecuting = YES;
    
    __weak __typeof(self) weakSelf = self;
    
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    NSData * authStateData = [defaults valueForKey:PDKNokiaHealthAuthState];
    
    if (authStateData != nil) {
        OIDAuthState *authState = (OIDAuthState *) [NSKeyedUnarchiver unarchiveObjectWithData:authStateData];
        
        [authState performActionWithFreshTokens:^(NSString * _Nullable accessToken, NSString * _Nullable idToken, NSError * _Nullable error) {
            NSData * authData = [NSKeyedArchiver archivedDataWithRootObject:authState];
            [defaults setValue:authData forKey:PDKNokiaHealthAuthState];
            [defaults synchronize];

            while (weakSelf.pendingRequests.count > 0) {
                void (^toExecute)(NSString *) = nil;
                
                @synchronized(weakSelf.pendingRequests) {
                    toExecute = [weakSelf.pendingRequests objectAtIndex:0];
                    
                    [weakSelf.pendingRequests removeObject:toExecute];
                }
                
                NSTimeInterval now = [NSDate date].timeIntervalSince1970;
                
                if (now < self.waitUntil) {
                    NSDate * wait = [NSDate dateWithTimeIntervalSince1970:self.waitUntil];
                    
                    NSLog(@"NH WAIT UNTIL %@", wait);
                    
                    errorBlock(@{
                                 @"error-type": @"waiting-rate-limit",
                                 @"wait-until":wait
                                 });
                } else {
                    toExecute(accessToken);
                }
            }
            
            weakSelf.isExecuting = NO;
        }];
    }
}

+ (UIColor *) dataColor {
    return [UIColor colorWithRed:0x1C/255.0 green:0x45/255.0 blue:0x98/255.0 alpha:1.0];
}

- (NSString *) generatorId {
    return GENERATOR_ID;
}

@end
