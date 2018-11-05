//
//  PDKFitbitGenerator.m
//  PassiveDataKit
//
//  Created by Chris Karr on 8/14/18.
//  Copyright © 2018 Audacious Software. All rights reserved.
//

#include <sqlite3.h>

@import AFNetworking;

#import <AppAuth/AppAuth.h>

#import "PDKFitbitGenerator.h"

#define DATABASE_VERSION @"PDKFitbitGenerator.DATABASE_VERSION"
#define CURRENT_DATABASE_VERSION @(1)
#define GENERATOR_ID @"pdk-fitbit"

#define AFNETWORKING_ERROR_KEY @"com.alamofire.serialization.response.error.data"

NSString * const PDKFitbitClientID = @"PDKFitbitClientID"; //!OCLINT
NSString * const PDKFitbitCallbackURL = @"PDKFitbitCallbackURL"; //!OCLINT
NSString * const PDKFitbitClientSecret = @"PDKFitbitClientSecret"; //!OCLINT
NSString * const PDKFitbitLoginMandatory = @"PDKFitbitLoginMandatory"; //!OCLINT

NSString * const PDKFitbitActivityEnabled = @"PDKFitbitActivityEnabled"; //!OCLINT
NSString * const PDKFitbitHeartRateEnabled = @"PDKFitbitHeartRateEnabled"; //!OCLINT
NSString * const PDKFitbitSleepEnabled = @"PDKFitbitSleepEnabled"; //!OCLINT
NSString * const PDKFitbitWeightEnabled = @"PDKFitbitWeightEnabled"; //!OCLINT

NSString * const PDKFitbitAuthState = @"PDKFitbitAuthState"; //!OCLINT
NSString * const PDKFitbitLastRefreshed = @"PDKFitbitLastRefreshed"; //!OCLINT
NSString * const PDKFitbitAccessToken = @"PDKFitbitAccessToken"; //!OCLINT
NSString * const PDKFitbitRefreshToken = @"PDKFitbitRefreshToken"; //!OCLINT

NSString * const PDKFitbitScopes = @"PDKFitbitScopes"; //!OCLINT

NSString * const PDKFitbitScopeActivity = @"activity"; //!OCLINT
NSString * const PDKFitbitScopeHeartRate = @"heartrate"; //!OCLINT
NSString * const PDKFitbitScopeLocation = @"location"; //!OCLINT
NSString * const PDKFitbitScopeNutrition = @"nutrition"; //!OCLINT
NSString * const PDKFitbitScopeProfile = @"profile"; //!OCLINT
NSString * const PDKFitbitScopeSettings = @"settings"; //!OCLINT
NSString * const PDKFitbitScopeSleep = @"sleep"; //!OCLINT
NSString * const PDKFitbitScopeSocial = @"social"; //!OCLINT
NSString * const PDKFitbitScopeWeight = @"weight"; //!OCLINT

NSString * const PDKFitbitAlertMisconfigured = @"pdk-fitbit-misconfigured-alert"; //!OCLINT
NSString * const PDKFitbitAlert = @"pdk-fitbit-alert"; //!OCLINT

NSString * const PDKFitbitDataType = @"fitbit_type";

NSString * const PDKFitbitFetched = @"fetched"; //!OCLINT
NSString * const PDKFitbitObserved = @"observed"; //!OCLINT

NSString * const PDKFitbitDataTypeActivity = @"activity";
NSString * const PDKFitbitDateStart = @"date_start"; //!OCLINT
NSString * const PDKFitbitSteps = @"steps"; //!OCLINT
NSString * const PDKFitbitDistance = @"distance"; //!OCLINT
NSString * const PDKFitbitFloors = @"floors"; //!OCLINT
NSString * const PDKFitbitElevation = @"elevation"; //!OCLINT
NSString * const PDKFitbitActivityCalories = @"calories_activity"; //!OCLINT
NSString * const PDKFitbitBMRCalories = @"calories_bmr"; //!OCLINT
NSString * const PDKFitbitMarginalCalories = @"calories_marginal"; //!OCLINT
NSString * const PDKFitbitVeryActiveMinutes = @"minutes_very_active"; //!OCLINT
NSString * const PDKFitbitFairlyActiveMinutes = @"minutes_fairly_active"; //!OCLINT
NSString * const PDKFitbitLightlyActiveMinutes = @"minutes_lightly_active"; //!OCLINT
NSString * const PDKFitbitSedentaryMinutes = @"minutes_sedentary"; //!OCLINT

NSString * const PDKFitbitDataTypeSleep = @"sleep";
NSString * const PDKFitbitStartTime = @"start"; //!OCLINT
NSString * const PDKFitbitDuration = @"duration"; //!OCLINT
NSString * const PDKFitbitIsMainSleep = @"is_main_sleep"; //!OCLINT
NSString * const PDKFitbitMinutesAsleep = @"minutes_asleep"; //!OCLINT
NSString * const PDKFitbitMinutesAwake = @"minutes_awake"; //!OCLINT
NSString * const PDKFitbitMinutesAfterWake = @"minutes_after_wake"; //!OCLINT
NSString * const PDKFitbitMinutesToSleep = @"minutes_to_sleep"; //!OCLINT
NSString * const PDKFitbitMinutesInBed = @"minutes_in_bed"; //!OCLINT
NSString * const PDKFitbitSleepType = @"sleep_type"; //!OCLINT
NSString * const PDKFitbitDeepPeriods = @"deep_periods"; //!OCLINT
NSString * const PDKFitbitDeepMinutes = @"deep_minutes"; //!OCLINT
NSString * const PDKFitbitLightPeriods = @"light_periods"; //!OCLINT
NSString * const PDKFitbitLightMinutes = @"light_minutes"; //!OCLINT
NSString * const PDKFitbitREMPeriods = @"rem_periods"; //!OCLINT
NSString * const PDKFitbitREMMinutes = @"rem_minutes"; //!OCLINT
NSString * const PDKFitbitWakePeriods = @"wake_periods"; //!OCLINT
NSString * const PDKFitbitWakeMinutes = @"wake_minutes"; //!OCLINT
NSString * const PDKFitbitAsleepPeriods = @"asleep_periods"; //!OCLINT
NSString * const PDKFitbitAsleepMinutes = @"asleep_minutes"; //!OCLINT
NSString * const PDKFitbitAwakePeriods = @"awake_periods"; //!OCLINT
NSString * const PDKFitbitAwakeMinutes = @"awake_minutes"; //!OCLINT
NSString * const PDKFitbitRestlessPeriods = @"restless_periods"; //!OCLINT
NSString * const PDKFitbitRestlessMinutes = @"restless_minutes"; //!OCLINT

NSString * const PDKFitbitDataTypeHeartRate = @"heart_rate";
NSString * const PDKFitbitHeartRateOutMin = @"out_min";
NSString * const PDKFitbitHeartRateOutMax = @"out_max";
NSString * const PDKFitbitHeartRateOutMinutes = @"out_minutes";
NSString * const PDKFitbitHeartRateOutCalories = @"out_calories";
NSString * const PDKFitbitHeartRateFatBurnMin = @"fat_burn_min";
NSString * const PDKFitbitHeartRateFatBurnMax = @"fat_burn_max";
NSString * const PDKFitbitHeartRateFatBurnMinutes = @"fat_burn_minutes";
NSString * const PDKFitbitHeartRateFatBurnCalories = @"fat_burn_calories";
NSString * const PDKFitbitHeartRateCardioMin = @"cardio_min";
NSString * const PDKFitbitHeartRateCardioMax = @"cardio_max";
NSString * const PDKFitbitHeartRateCardioMinutes = @"cardio_minutes";
NSString * const PDKFitbitHeartRateCardioCalories = @"cardio_calories";
NSString * const PDKFitbitHeartRatePeakMin = @"peak_min";
NSString * const PDKFitbitHeartRatePeakMax = @"peak_max";
NSString * const PDKFitbitHeartRatePeakMinutes = @"peak_minutes";
NSString * const PDKFitbitHeartRatePeakCalories = @"peak_calories";
NSString * const PDKFitbitHeartRateRestingRate = @"resting_rate";

NSString * const PDKFitbitDataTypeWeight = @"weight";
NSString * const PDKFitbitWeightWeight = @"weight";
NSString * const PDKFitbitWeightBMI = @"bmi";
NSString * const PDKFitbitWeightLogID = @"log_id";
NSString * const PDKFitbitWeightSource = @"source";


@interface PDKFitbitGenerator()

@property id<OIDExternalUserAgentSession> currentExternalUserAgentFlow;
@property NSDictionary * options;

@property sqlite3 * database;

@property NSMutableArray * pendingRequests;
@property BOOL isExecuting;

@property NSTimeInterval waitUntil;

@property NSMutableArray * listeners;
@property NSMutableDictionary * lastUrlFetches;

@end

static PDKFitbitGenerator * sharedObject = nil;

@implementation PDKFitbitGenerator

+ (PDKFitbitGenerator *) sharedInstance {
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
        self.options = @{};
        
        self.listeners = [NSMutableArray array];
        
        self.database = [self openDatabase];
        
        self.pendingRequests = [NSMutableArray array];
        self.isExecuting = NO;
        
        self.waitUntil = 0;
        
        self.lastUrlFetches = [NSMutableDictionary dictionary];
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
    return NSLocalizedStringFromTableInBundle(@"name_generator_fitbit", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
}

- (void) refresh {
    BOOL authed = YES;
    
    if (self.options[PDKFitbitClientID] == nil || self.options[PDKFitbitCallbackURL] == nil || self.options[PDKFitbitClientSecret] == nil) {
        NSString * title = NSLocalizedStringFromTableInBundle(@"title_generator_fitbit_app_misconfigured", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);

        NSString * message = NSLocalizedStringFromTableInBundle(@"message_generator_fitbit_app_misconfigured", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);

        [[PassiveDataKit sharedInstance] updateAlertWithTag:PDKFitbitAlertMisconfigured
                                                      title:title
                                                    message:message
                                                      level:PDKAlertLevelError action:^{

        }];
    } else {
        [[PassiveDataKit sharedInstance] cancelAlertWithTag:PDKFitbitAlertMisconfigured];
    }
    
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    NSString * accessToken = [defaults valueForKey:PDKFitbitAccessToken];
    NSString * refreshToken = [defaults valueForKey:PDKFitbitRefreshToken];

    if (authed && (refreshToken == nil || accessToken == nil)) {
        authed = NO;
    }
    
    NSNumber * isMandatory = self.options[PDKFitbitLoginMandatory];
    
    if (isMandatory == nil) {
        isMandatory = @(YES);
    }

    if (isMandatory.boolValue && authed == NO) {
        NSString * title = NSLocalizedStringFromTableInBundle(@"title_generator_fitbit_needs_auth", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
        NSString * message = NSLocalizedStringFromTableInBundle(@"message_generator_fitbit_needs_auth", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);

        [[PassiveDataKit sharedInstance] updateAlertWithTag:PDKFitbitAlert
                                                      title:title
                                                    message:message
                                                      level:PDKAlertLevelError action:^{
            [[PDKFitbitGenerator sharedInstance] loginToService:nil failure:nil];
        }];
    } else {
        [[PassiveDataKit sharedInstance] cancelAlertWithTag:PDKFitbitAlert];
    }
    
    if (authed) {
        [self.lastUrlFetches removeAllObjects];
        
        NSTimeInterval now = [NSDate date].timeIntervalSince1970;
        
        if (now > self.waitUntil) {
            void (^toExecute)(NSString *) = ^void(NSString * accessToken) {
                NSNumber * activitiesEnabled = self.options[PDKFitbitActivityEnabled];
                
                if (activitiesEnabled == nil) {
                    activitiesEnabled = @(YES);
                }
                
                if (activitiesEnabled.boolValue) {
                    [self fetchActivityWithAccessToken:accessToken date:nil callback:^{

                    }];
                }
                
                NSNumber * sleepEnabled = self.options[PDKFitbitSleepEnabled];
                
                if (sleepEnabled == nil) {
                    sleepEnabled = @(YES);
                }
                
                if (sleepEnabled.boolValue) {
                    [self fetchSleepWithAccessToken:accessToken];
                }
                
                NSNumber * heartRateEnabled = self.options[PDKFitbitHeartRateEnabled];
                
                if (heartRateEnabled == nil) {
                    heartRateEnabled = @(YES);
                }
                
                if (heartRateEnabled.boolValue) {
                    [self fetchHeartRateWithAccessToken:accessToken];
                }
                
                NSNumber * weightEnabled = self.options[PDKFitbitWeightEnabled];
                
                if (weightEnabled == nil) {
                    weightEnabled = @(YES);
                }
                
                if (weightEnabled.boolValue) {
                    [self fetchWeightWithAccessToken:accessToken];
                }
                
                [[PassiveDataKit sharedInstance] cancelAlertWithTag:PDKFitbitAlert];
            };
            
            [self executeRequest:toExecute error:^(NSDictionary * error) {
                NSLog(@"FITBIT ENCOUNTERED ERROR: %@", error);
            }];
        }
    }
}

- (void) fetchActivityWithAccessToken:(NSString *) accessToken date:(NSDate *) date callback:(void (^)(void)) callback {
    __weak __typeof(self) weakSelf = self;
    
    NSString * dateString = nil;
    
    if (date == nil) {
        dateString = @"today";
    } else {
        NSDateFormatter * dateParser = [[NSDateFormatter alloc] init];
        dateParser.dateFormat = @"yyyy-MM-dd";
        
        dateString = [dateParser stringFromDate:date];
    }

    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    
    NSString * urlString = [NSString stringWithFormat:@"https://api.fitbit.com/1/user/-/activities/date/%@.json", dateString];
    
    NSNumber * lastFetch = self.lastUrlFetches[urlString];
    
    if (lastFetch == nil) {
        lastFetch = @(0);
    }
    
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    
    if (now - lastFetch.doubleValue < 60) {
        if (callback != nil) {
            callback();
        }
        
        return;
    }

    self.lastUrlFetches[urlString] = @(now);

    if (now < self.waitUntil) {
        if (callback != nil) {
            callback();
        }
        
        return;
    }

    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];
    
    NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                    
                                                } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                    
                                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                    if (error != nil) {
                                                        [self processError:error];
                                                    } else {
                                                        [weakSelf logActivity:responseObject date:date];

                                                        if (callback != nil) {
                                                            callback();
                                                        }
                                                    }
                                                }];
    [task resume];
}

- (void) logActivity:(NSDictionary *) responseObject date:(NSDate *) date {
    NSDictionary * summary = responseObject[@"summary"];
    
    if (summary != nil) {
        NSNumber * now = @([[NSDate date] timeIntervalSince1970] * 1000);
        
        NSMutableDictionary * data = [NSMutableDictionary dictionary];
        [data setValue:now forKey:PDKFitbitFetched];
        [data setValue:now forKey:PDKFitbitObserved];
        
        NSCalendar * calendar = [NSCalendar currentCalendar];
        
        if (date == nil) {
            date = [NSDate date];
        }
        
        NSDate * start = [calendar startOfDayForDate:date];
        
        [data setValue:@([start timeIntervalSince1970] * 1000) forKey:PDKFitbitDateStart];
        [data setValue:summary[@"steps"] forKey:PDKFitbitSteps];
        [data setValue:summary[@"floors"] forKey:PDKFitbitFloors];
        [data setValue:summary[@"elevation"] forKey:PDKFitbitElevation];
        [data setValue:summary[@"activityCalories"] forKey:PDKFitbitActivityCalories];
        [data setValue:summary[@"caloriesBMR"] forKey:PDKFitbitBMRCalories];
        [data setValue:summary[@"marginalCalories"] forKey:PDKFitbitMarginalCalories];
        [data setValue:summary[@"veryActiveMinutes"] forKey:PDKFitbitVeryActiveMinutes];
        [data setValue:summary[@"fairlyActiveMinutes"] forKey:PDKFitbitFairlyActiveMinutes];
        [data setValue:summary[@"lightlyActiveMinutes"] forKey:PDKFitbitLightlyActiveMinutes];
        [data setValue:summary[@"sedentaryMinutes"] forKey:PDKFitbitSedentaryMinutes];
        
        NSArray * distances = summary[@"distances"];
        
        double totalDistance = 0;
        
        for (NSDictionary * distanceObj in distances) {
            NSNumber * distanceValue = distanceObj[@"distance"];
            
            totalDistance += distanceValue.doubleValue;
        }

        [data setValue:@(totalDistance) forKey:PDKFitbitDistance];
        
        data[PDKFitbitDataType] = PDKFitbitDataTypeActivity;
        
        for (id<PDKDataListener> listener in self.listeners) {
            [listener receivedData:data forGenerator:PDKFitbit];
        }

        sqlite3_stmt * stmt;

        @synchronized(self) {
            NSString * insert = @"INSERT INTO activity_history (fetched, observed, date_start, steps, distance, floors, elevation, calories_activity, calories_bmr, calories_marginal, minutes_very_active, minutes_fairly_active, minutes_lightly_active, minutes_sedentary) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";

            int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL);

            if (retVal == SQLITE_OK) {
                if (sqlite3_bind_double(stmt, 1, [data[PDKFitbitFetched] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 2, [data[PDKFitbitObserved] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 3, [data[PDKFitbitDateStart] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 4, [data[PDKFitbitSteps] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 5, [data[PDKFitbitDistance] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 6, [data[PDKFitbitFloors] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 7, [data[PDKFitbitElevation] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 8, [data[PDKFitbitActivityCalories] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 9, [data[PDKFitbitBMRCalories] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 10, [data[PDKFitbitMarginalCalories] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 11, [data[PDKFitbitVeryActiveMinutes] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 12, [data[PDKFitbitLightlyActiveMinutes] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 13, [data[PDKFitbitFairlyActiveMinutes] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 14, [data[PDKFitbitSedentaryMinutes] doubleValue]) == SQLITE_OK) {
                    
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

- (void) fetchSleepWithAccessToken:(NSString *) accessToken {
    __weak __typeof(self) weakSelf = self;

    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.fitbit.com/1.2/user/-/sleep/date/today.json"]];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];
    
    NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                    
                                                } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                    
                                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                    if (error != nil) {
                                                        [self processError:error];
                                                    } else {
                                                        [weakSelf logSleep:responseObject];
                                                    }
                                                }];
    [task resume];
}

- (void) logSleep:(id) responseObject {
    NSArray * sleeps = responseObject[@"sleep"];
    
    if (sleeps != nil) {
        NSNumber * now = @([[NSDate date] timeIntervalSince1970] * 1000);
        
        NSDateFormatter * dateParser = [[NSDateFormatter alloc] init];
        dateParser.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS";
        
        for (NSDictionary * sleep in sleeps) {
            NSMutableDictionary * data = [NSMutableDictionary dictionary];
            
            data[PDKFitbitFetched] = now;
            data[PDKFitbitObserved] = now;
            
            NSDate * sleepDate = [dateParser dateFromString:sleep[@"startTime"]];

            data[PDKFitbitStartTime] = @(sleepDate.timeIntervalSince1970 * 1000);
            data[PDKFitbitDuration] = sleep[@"duration"];
            data[PDKFitbitIsMainSleep] = sleep[@"isMainSleep"];
            data[PDKFitbitMinutesAsleep] = sleep[@"minutesAsleep"];
            data[PDKFitbitMinutesAwake] = sleep[@"minutesAwake"];
            data[PDKFitbitMinutesAfterWake] = sleep[@"minutesAfterWakeup"];
            data[PDKFitbitMinutesToSleep] = sleep[@"minutesToFallAsleep"];
            data[PDKFitbitMinutesInBed] = sleep[@"timeInBed"];
            data[PDKFitbitSleepType] = sleep[@"type"];
            
            if ([@"stages" isEqualToString:sleep[@"type"]]) {
                NSDictionary * summary = sleep[@"levels"][@"summary"];
                
                data[PDKFitbitDeepPeriods] = summary[@"deep"][@"count"];
                data[PDKFitbitDeepMinutes] = summary[@"deep"][@"minutes"];

                data[PDKFitbitLightPeriods] = summary[@"light"][@"count"];
                data[PDKFitbitLightMinutes] = summary[@"light"][@"minutes"];

                data[PDKFitbitREMPeriods] = summary[@"rem"][@"count"];
                data[PDKFitbitREMMinutes] = summary[@"rem"][@"minutes"];

                data[PDKFitbitWakePeriods] = summary[@"wake"][@"count"];
                data[PDKFitbitWakeMinutes] = summary[@"wake"][@"minutes"];

                data[PDKFitbitAsleepPeriods] = @(-1);
                data[PDKFitbitAsleepMinutes] = @(-1);
                
                data[PDKFitbitAwakePeriods] = @(-1);
                data[PDKFitbitAwakeMinutes] = @(-1);
                
                data[PDKFitbitRestlessPeriods] = @(-1);
                data[PDKFitbitRestlessMinutes] = @(-1);
            } else if ([@"classic" isEqualToString:sleep[@"type"]]) {
                NSDictionary * summary = sleep[@"levels"][@"summary"];
                
                data[PDKFitbitAsleepPeriods] = summary[@"asleep"][@"count"];
                data[PDKFitbitAsleepMinutes] = summary[@"asleep"][@"minutes"];

                data[PDKFitbitAwakePeriods] = summary[@"awake"][@"count"];
                data[PDKFitbitAwakeMinutes] = summary[@"awake"][@"minutes"];

                data[PDKFitbitRestlessPeriods] = summary[@"restless"][@"count"];
                data[PDKFitbitRestlessMinutes] = summary[@"restless"][@"minutes"];

                data[PDKFitbitDeepPeriods] = @(-1);
                data[PDKFitbitDeepMinutes] = @(-1);
                
                data[PDKFitbitLightPeriods] = @(-1);
                data[PDKFitbitLightMinutes] = @(-1);
                
                data[PDKFitbitREMPeriods] = @(-1);
                data[PDKFitbitREMMinutes] = @(-1);
                
                data[PDKFitbitWakePeriods] = @(-1);
                data[PDKFitbitWakeMinutes] = @(-1);
            }

            data[PDKFitbitDataType] = PDKFitbitDataTypeSleep;

            for (id<PDKDataListener> listener in self.listeners) {
                [listener receivedData:data forGenerator:PDKFitbit];
            }

            @synchronized(self) {
                sqlite3_stmt * stmt;
                
                NSString * insert = @"INSERT INTO sleep_history (fetched, observed, start, duration, is_main_sleep, minutes_asleep, minutes_awake, minutes_after_wake, minutes_to_sleep, minutes_in_bed, sleep_type, deep_periods, deep_minutes, light_periods, light_minutes, rem_periods, rem_minutes, wake_periods, wake_minutes, asleep_minutes, asleep_periods, restless_minutes, restless_periods, awake_minutes, awake_periods) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";
                
                int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL);
                
                if (retVal == SQLITE_OK) {
                    if (sqlite3_bind_double(stmt, 1, [data[PDKFitbitFetched] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 2, [data[PDKFitbitObserved] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 3, [data[PDKFitbitStartTime] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 4, [data[PDKFitbitDuration] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 5, [data[PDKFitbitIsMainSleep] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 6, [data[PDKFitbitMinutesAsleep] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 7, [data[PDKFitbitMinutesAwake] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 8, [data[PDKFitbitMinutesAfterWake] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 9, [data[PDKFitbitMinutesToSleep] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 10, [data[PDKFitbitMinutesInBed] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_text(stmt, 12, [data[PDKFitbitSleepType] cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 12, [data[PDKFitbitDeepPeriods] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 13, [data[PDKFitbitDeepMinutes] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 14, [data[PDKFitbitLightPeriods] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 15, [data[PDKFitbitLightMinutes] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 16, [data[PDKFitbitREMPeriods] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 17, [data[PDKFitbitREMMinutes] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 18, [data[PDKFitbitWakePeriods] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 19, [data[PDKFitbitWakeMinutes] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 20, [data[PDKFitbitAsleepPeriods] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 21, [data[PDKFitbitAsleepMinutes] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 22, [data[PDKFitbitAwakePeriods] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 23, [data[PDKFitbitAwakeMinutes] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 24, [data[PDKFitbitRestlessPeriods] doubleValue]) == SQLITE_OK &&
                        sqlite3_bind_double(stmt, 25, [data[PDKFitbitRestlessMinutes] doubleValue]) == SQLITE_OK) {
                        
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

- (void) fetchHeartRateWithAccessToken:(NSString *) accessToken {
    __weak __typeof(self) weakSelf = self;

    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.fitbit.com/1/user/-/activities/heart/date/today/1d.json"]];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];
    
    NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                    
                                                } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                    
                                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                    if (error != nil) {
                                                        [self processError:error];
                                                    } else {
                                                        [weakSelf logHeartRate:responseObject];
                                                    }
                                                }];
    [task resume];
}

- (void) logHeartRate:(id) responseObject {
    NSArray * summary = responseObject[@"activities-heart"];
    
    if (summary != nil) {
        NSNumber * now = @([[NSDate date] timeIntervalSince1970] * 1000);
        
        NSMutableDictionary * data = [NSMutableDictionary dictionary];
        [data setValue:now forKey:PDKFitbitFetched];
        [data setValue:now forKey:PDKFitbitObserved];
        
        NSArray * zones = summary[0][@"value"][@"heartRateZones"];
        
        for (NSDictionary * zone in zones) {
            if ([@"Out of Range" isEqualToString:zone[@"name"]]) {
                data[PDKFitbitHeartRateOutMin] = zone[@"min"];
                data[PDKFitbitHeartRateOutMax] = zone[@"max"];
                data[PDKFitbitHeartRateOutMinutes] = zone[@"minutes"];
                data[PDKFitbitHeartRateOutCalories] = zone[@"caloriesOut"];
            } else if ([@"Fat Burn" isEqualToString:zone[@"name"]]) {
                data[PDKFitbitHeartRateFatBurnMin] = zone[@"min"];
                data[PDKFitbitHeartRateFatBurnMax] = zone[@"max"];
                data[PDKFitbitHeartRateFatBurnMinutes] = zone[@"minutes"];
                data[PDKFitbitHeartRateFatBurnCalories] = zone[@"caloriesOut"];
            } else if ([@"Cardio" isEqualToString:zone[@"name"]]) {
                data[PDKFitbitHeartRateCardioMin] = zone[@"min"];
                data[PDKFitbitHeartRateCardioMax] = zone[@"max"];
                data[PDKFitbitHeartRateCardioMinutes] = zone[@"minutes"];
                data[PDKFitbitHeartRateCardioCalories] = zone[@"caloriesOut"];
            } else if ([@"Peak" isEqualToString:zone[@"name"]]) {
                data[PDKFitbitHeartRatePeakMin] = zone[@"min"];
                data[PDKFitbitHeartRatePeakMax] = zone[@"max"];
                data[PDKFitbitHeartRatePeakMinutes] = zone[@"minutes"];
                data[PDKFitbitHeartRatePeakCalories] = zone[@"caloriesOut"];
            }
        }
        
        data[PDKFitbitHeartRateRestingRate] = summary[0][@"value"][@"restingHeartRate"];
        
        data[PDKFitbitDataType] = PDKFitbitDataTypeHeartRate;

        for (id<PDKDataListener> listener in self.listeners) {
            [listener receivedData:data forGenerator:PDKFitbit];
        }
        
        @synchronized(self) {
            sqlite3_stmt * stmt;
            
            NSString * insert = @"INSERT INTO heart_rate_history (fetched, observed, out_min, out_max, out_minutes, out_calories, fat_burn_min, fat_burn_max, fat_burn_minutes, fat_burn_calories, cardio_min, cardio_max, cardio_minutes, cardio_calories, peak_min, peak_max, peak_minutes, peak_calories, resting_rate) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";

            int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL);
            
            if (retVal == SQLITE_OK) {
                if (sqlite3_bind_double(stmt, 1, [data[PDKFitbitFetched] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 2, [data[PDKFitbitObserved] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 3, [data[PDKFitbitHeartRateOutMin] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 4, [data[PDKFitbitHeartRateOutMax] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 5, [data[PDKFitbitHeartRateOutMinutes] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 6, [data[PDKFitbitHeartRateOutCalories] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 7, [data[PDKFitbitHeartRateFatBurnMin] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 8, [data[PDKFitbitHeartRateFatBurnMax] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 9, [data[PDKFitbitHeartRateFatBurnMinutes] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 10, [data[PDKFitbitHeartRateFatBurnCalories] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 11, [data[PDKFitbitHeartRateCardioMin] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 12, [data[PDKFitbitHeartRateCardioMax] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 13, [data[PDKFitbitHeartRateCardioMinutes] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 14, [data[PDKFitbitHeartRateCardioCalories] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 15, [data[PDKFitbitHeartRatePeakMin] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 16, [data[PDKFitbitHeartRatePeakMax] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 17, [data[PDKFitbitHeartRatePeakMinutes] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 18, [data[PDKFitbitHeartRatePeakCalories] doubleValue]) == SQLITE_OK &&
                    sqlite3_bind_double(stmt, 19, [data[PDKFitbitHeartRateRestingRate] doubleValue]) == SQLITE_OK) {
                    
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

- (void) fetchWeightWithAccessToken:(NSString *) accessToken {
    __weak __typeof(self) weakSelf = self;

    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.fitbit.com/1/user/-/body/log/weight/date/today.json"]];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];
    
    NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                    
                                                } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                    
                                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                    if (error != nil) {
                                                        [self processError:error];
                                                    } else {
                                                        [weakSelf logWeight:responseObject];
                                                    }
                                                }];
    [task resume];
}

- (void) logWeight:(id) responseObject {
    NSArray * weights = responseObject[@"weight"];
    
    if (weights != nil) {
        NSNumber * now = @([[NSDate date] timeIntervalSince1970] * 1000);

        NSDateFormatter * dateParser = [[NSDateFormatter alloc] init];
        dateParser.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";

        for (NSDictionary * weight in weights) {
            NSNumber * logId = weight[@"logId"];

            BOOL logNew = YES;

            @synchronized(self) {
                sqlite3_stmt * statement = NULL;
                
                NSString * querySQL = @"SELECT W.log_id FROM weight_history W WHERE W.log_id = ?";
                
                const char * query_stmt = [querySQL UTF8String];
                
                if (sqlite3_prepare_v2(self.database, query_stmt, -1, &statement, NULL) == SQLITE_OK) { //!OCLINT
                    sqlite3_bind_int64(statement, 1, logId.longValue);

                    int retVal = sqlite3_prepare_v2(self.database, [querySQL UTF8String], -1, &statement, NULL);
                    
                    if (retVal == SQLITE_OK) {
                        if (sqlite3_step(statement) == SQLITE_ROW) {
                            logNew = NO;
                        }
                        
                        sqlite3_finalize(statement);
                    }
                } else {
                    NSLog(@"ERROR WEIGHT QUERYING");
                }
            }
                
            if (logNew) {
                NSMutableDictionary * data = [NSMutableDictionary dictionary];

                data[PDKFitbitFetched] = now;
                data[PDKFitbitObserved] = now;

                data[PDKFitbitWeightWeight] = weight[@"weight"];
                data[PDKFitbitWeightBMI] = weight[@"bmi"];
                data[PDKFitbitWeightLogID] = logId;
                data[PDKFitbitWeightSource] = weight[@"source"];

                data[PDKFitbitDataType] = PDKFitbitDataTypeWeight;
                
                for (id<PDKDataListener> listener in self.listeners) {
                    [listener receivedData:data forGenerator:PDKFitbit];
                }
                
                @synchronized(self) {
                    sqlite3_stmt * stmt;
                    
                    NSString * insert = @"INSERT INTO weight_history (fetched, observed, weight, bmi, log_id, source) VALUES (?, ?, ?, ?, ?, ?);";
                    
                    int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL);
                    
                    if (retVal == SQLITE_OK) {
                        if (sqlite3_bind_double(stmt, 1, [data[PDKFitbitFetched] doubleValue]) == SQLITE_OK &&
                            sqlite3_bind_double(stmt, 2, [data[PDKFitbitObserved] doubleValue]) == SQLITE_OK &&
                            sqlite3_bind_double(stmt, 3, [data[PDKFitbitDateStart] doubleValue]) == SQLITE_OK &&
                            sqlite3_bind_double(stmt, 4, [data[PDKFitbitSteps] doubleValue]) == SQLITE_OK &&
                            sqlite3_bind_double(stmt, 5, [data[PDKFitbitDistance] doubleValue]) == SQLITE_OK &&
                            sqlite3_bind_text(stmt, 6, [data[PDKFitbitWeightSource] cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT) == SQLITE_OK) {
                            
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
}

- (BOOL)application:(UIApplication *) app openURL:(NSURL *) url options:(NSDictionary<NSString *, id> *) options {
    if (self.currentExternalUserAgentFlow == nil) {
        return NO;
    }
    
    if (self.options[PDKFitbitCallbackURL] != nil && [url.description rangeOfString:self.options[PDKFitbitCallbackURL]].location == 0) {
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
    
    NSString * dbPath = [documentsPath stringByAppendingPathComponent:@"pdk-fitbit.sqlite3"];
    
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
 
            const char * createActivityStatement = "CREATE TABLE activity_history(_id INTEGER PRIMARY KEY AUTOINCREMENT, fetched INTEGER, transmitted INTEGER, observed INTEGER, date_start INTEGER, steps REAL, distance REAL, floors REAL, elevation REAL, calories_activity REAL, calories_bmr REAL, calories_marginal REAL, minutes_very_active REAL, minutes_fairly_active REAL, minutes_lightly_active REAL, minutes_sedentary REAL);";

            if (sqlite3_exec(database, createActivityStatement, NULL, NULL, &error) != SQLITE_OK) { //!OCLINT
                
            }

            const char * createSleepStatement = "CREATE TABLE sleep_history(_id INTEGER PRIMARY KEY AUTOINCREMENT, fetched INTEGER, transmitted INTEGER, observed INTEGER, start INTEGER, duration REAL, is_main_sleep INTEGER, minutes_asleep REAL, minutes_awake REAL, minutes_after_wake REAL, minutes_to_sleep REAL, minutes_in_bed REAL, sleep_type TEXT, deep_periods REAL, deep_minutes REAL, light_periods REAL, light_minutes REAL, rem_periods REAL, rem_minutes REAL, wake_periods REAL, wake_minutes REAL, asleep_minutes REAL, asleep_periods REAL, restless_minutes REAL, restless_periods REAL, awake_minutes REAL, awake_periods REAL);";
            
            if (sqlite3_exec(database, createSleepStatement, NULL, NULL, &error) != SQLITE_OK) { //!OCLINT
                
            }

            const char * createWeightStatement = "CREATE TABLE weight_history(_id INTEGER PRIMARY KEY AUTOINCREMENT, fetched INTEGER, transmitted INTEGER, observed INTEGER, weight REAL, bmi REAL, log_id INTEGER, source TEXT);";
            
            if (sqlite3_exec(database, createWeightStatement, NULL, NULL, &error) != SQLITE_OK) { //!OCLINT
                
            }

            const char * createHeartRateStatement = "CREATE TABLE heart_rate_history(_id INTEGER PRIMARY KEY AUTOINCREMENT, fetched INTEGER, transmitted INTEGER, observed INTEGER, out_min REAL, out_max REAL, out_minutes REAL, out_calories REAL, fat_burn_min REAL, fat_burn_max REAL, fat_burn_minutes REAL, fat_burn_calories REAL, cardio_min REAL, cardio_max REAL, cardio_minutes REAL, cardio_calories REAL, peak_min REAL, peak_max REAL, peak_minutes REAL, peak_calories REAL, resting_rate REAL);";
            
            if (sqlite3_exec(database, createHeartRateStatement, NULL, NULL, &error) != SQLITE_OK) { //!OCLINT
                
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
        
        //        char * error = NULL;
        
        switch (dbVersion.integerValue) { //!OCLINT
            default:
                break;
        }
        
        if (updated) {
            [defaults setValue:CURRENT_DATABASE_VERSION forKey:DATABASE_VERSION];
        }
        
        return database;
    }
    
    return database;
}

- (BOOL) isAuthenticated {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    NSString * accessToken = [defaults valueForKey:PDKFitbitAccessToken];
    NSString * refreshToken = [defaults valueForKey:PDKFitbitRefreshToken];

    return (accessToken != nil && refreshToken != nil);
}

- (void) loginToService:(void (^)(void))success failure:(void (^)(void))failure {
    NSURL * authorizationEndpoint = [NSURL URLWithString:@"https://www.fitbit.com/oauth2/authorize"];
    NSURL * tokenEndpoint = [NSURL URLWithString:@"https://api.fitbit.com/oauth2/token"];
    
    OIDServiceConfiguration * configuration = [[OIDServiceConfiguration alloc] initWithAuthorizationEndpoint:authorizationEndpoint
                                                                                               tokenEndpoint:tokenEndpoint];
    
    NSArray * scopes = self.options[PDKFitbitScopes];
    
    if (scopes == nil || scopes.count == 0) {
        scopes = @[PDKFitbitScopeActivity, PDKFitbitScopeSleep, PDKFitbitScopeWeight];
    }
    
    NSDictionary * addParams = @{
                                 @"prompt": @"login"
                                 };

    OIDAuthorizationRequest *request = [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                                                     clientId:self.options[PDKFitbitClientID]
                                                                                 clientSecret:self.options[PDKFitbitClientSecret]
                                                                                       scopes:scopes
                                                                                  redirectURL:[NSURL URLWithString:self.options[PDKFitbitCallbackURL]]
                                                                                 responseType:OIDResponseTypeCode
                                                                         additionalParameters:addParams];

    UIWindow * window = [[[UIApplication sharedApplication] delegate] window];
    
    self.currentExternalUserAgentFlow = [OIDAuthState authStateByPresentingAuthorizationRequest:request
                                                                       presentingViewController:window.rootViewController
                                                                                       callback:^(OIDAuthState *_Nullable authState, NSError *_Nullable error) {
                                                                                           if (authState) {
                                                                                               NSDate * now = [NSDate date];
                                                                                               
                                                                                               NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
                                                                                               
                                                                                               NSData * authData = [NSKeyedArchiver archivedDataWithRootObject:authState];
                                                                                               [defaults setValue:authData
                                                                                                           forKey:PDKFitbitAuthState];
                                                                                               [defaults setValue:now
                                                                                                           forKey:PDKFitbitLastRefreshed];

                                                                                               [defaults setValue:authState.lastTokenResponse.accessToken
                                                                                                           forKey:PDKFitbitAccessToken];

                                                                                               [defaults setValue:authState.lastTokenResponse.refreshToken
                                                                                                           forKey:PDKFitbitRefreshToken];

                                                                                               [defaults synchronize];

                                                                                               [[PDKFitbitGenerator sharedInstance] refresh];
                                                                                              
                                                                                               if (success != nil) {
                                                                                                   success();
                                                                                               }
                                                                                           } else {
                                                                                               NSLog(@"Authorization error: %@", [error localizedDescription]);
                                                                                               
                                                                                               if (failure != nil) {
                                                                                                   failure();
                                                                                               }
                                                                                           }
                                                                                       }];

    [[PassiveDataKit sharedInstance] setCurrentUserFlow:self.currentExternalUserAgentFlow];
}

- (void) logout {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    [defaults removeObjectForKey:PDKFitbitAuthState];
    [defaults removeObjectForKey:PDKFitbitAccessToken];
    [defaults removeObjectForKey:PDKFitbitRefreshToken];
    [defaults synchronize];
    
    @synchronized(self.pendingRequests) {
        [self.pendingRequests removeAllObjects];
    }
}

- (void) stepsBetweenStart:(NSTimeInterval) start end:(NSTimeInterval) end callback:(void (^)(NSTimeInterval start, NSTimeInterval end, CGFloat steps)) callback backfill:(BOOL) doBackfill force:(BOOL) forceRefresh {
    
    NSDate * dayStart = [[NSCalendar currentCalendar] startOfDayForDate:[NSDate dateWithTimeIntervalSince1970:start]];

    NSNumber * steps = nil;
    
    if (forceRefresh == NO) {
        sqlite3_stmt * statement = NULL;
        
        if (end == 0) { // Pull full record for day...
            start = 0;
            end = [NSDate date].timeIntervalSince1970;
        }
        
        NSString * select = @"SELECT A.steps FROM activity_history A WHERE A.date_start = ? AND A.observed >= ? AND A.observed < ? ORDER BY A.steps DESC";
        
        const char * query_stmt = [select UTF8String];
        
        @synchronized(self) {
            if (sqlite3_prepare_v2(self.database, query_stmt, -1, &statement, NULL) == SQLITE_OK) { //!OCLINT
                sqlite3_bind_double(statement, 1, dayStart.timeIntervalSince1970 * 1000);
                sqlite3_bind_double(statement, 2, start * 1000);
                sqlite3_bind_double(statement, 3, end * 1000);
                
                if (sqlite3_step(statement) == SQLITE_ROW) {
                    steps = @(sqlite3_column_double(statement, 0));
                }
                
                sqlite3_finalize(statement);
            }
        }
        
        if (steps == nil) {
            CGFloat largestSteps = -1;
            CGFloat smallestSteps = -1;
            
            NSString * select = @"SELECT A.steps FROM activity_history A WHERE A.date_start = ? ORDER BY A.steps DESC";
            
            const char * query_stmt = [select UTF8String];
            
            @synchronized(self) {
                if (sqlite3_prepare_v2(self.database, query_stmt, -1, &statement, NULL) == SQLITE_OK) { //!OCLINT
                    sqlite3_bind_double(statement, 1, dayStart.timeIntervalSince1970 * 1000);
                    
                    while (sqlite3_step(statement) == SQLITE_ROW) {
                        CGFloat stepCount = sqlite3_column_double(statement, 0);
                        
                        if (largestSteps < 0) {
                            largestSteps = stepCount;
                        }
                        
                        if (smallestSteps < 0) {
                            smallestSteps = stepCount;
                        }
                        
                        if (stepCount > largestSteps) {
                            largestSteps = stepCount;
                        }
                        
                        if (stepCount < smallestSteps) {
                            smallestSteps = stepCount;
                        }
                    }
                    
                    sqlite3_finalize(statement);
                }
            }
            
            if (largestSteps < 0) {
                // No data - continue...
                //        } else if (largestSteps != smallestSteps) {
                //            steps = @(0);
            } else {
                steps = @(largestSteps);
            }
        }
    }
        
    if (steps != nil) {
        callback(start, end, steps.doubleValue);
    } else if (doBackfill == YES) {
        NSTimeInterval now = [NSDate date].timeIntervalSince1970;
        
        if (now > self.waitUntil) {
            void (^toExecute)(NSString *) = ^void(NSString * accessToken) {
                NSDate * date = [NSDate dateWithTimeIntervalSince1970:dayStart.timeIntervalSince1970];
                
                [self fetchActivityWithAccessToken:accessToken
                                              date:date
                                          callback:^{
                                              [self stepsBetweenStart:start
                                                                  end:end
                                                             callback:callback
                                                             backfill:NO
                                                                force:NO];
                                          }];
            };
            
            [self executeRequest:toExecute error:^(NSDictionary * error) {
                NSLog(@"ERROR WHILE FETCHING STEPS: %@", error);
                
                callback(start, end, 0);
            }];
        } else {
            callback(start, end, 0);
        }
    } else {
        callback(start, end, 0);
    }
}

- (void) fetchProfile:(void (^)(NSDictionary * profile))callback {
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    
    if (now < self.waitUntil) {
        callback(nil);
    }

    void (^toExecute)(NSString *) = ^void(NSString * accessToken) {
        AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
        
        NSString * urlString = @"https://api.fitbit.com/1/user/-/profile.json";
        
        NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        
        [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];
        
        NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                    uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                        
                                                    } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                        
                                                    } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                        if (error != nil) {
                                                            [self processError:error];
                                                        } else {
                                                            if (callback != nil) {
                                                                callback(responseObject);
                                                            }
                                                        }
                                                    }];
        [task resume];
    };
    
    [self executeRequest:toExecute error:^(NSDictionary * error) {
        NSLog(@"ERROR FETCHING FB PROFILE: %@", error);
        
        callback(nil);
    }];
}

+ (UIColor *) dataColor {
    return [UIColor colorWithRed:0xEB/255.0 green:0x40/255.0 blue:0x70/255.0 alpha:1.0];
}

- (void) resetData {
    NSString * select = @"DELETE FROM activity_history WHERE date_start >= ?";
    
    sqlite3_stmt * statement = NULL;
    const char * query_stmt = [select UTF8String];

    @synchronized(self) {
        if (sqlite3_prepare_v2(self.database, query_stmt, -1, &statement, NULL) == SQLITE_OK) { //!OCLINT
            sqlite3_bind_double(statement, 1, 0);
            
            if (sqlite3_step(statement) == SQLITE_ROW) {

            } else {

            }
            
            sqlite3_finalize(statement);
        }
    }
}

- (void) processError:(NSError *) error {
    NSLog(@"ERROR: %@", error);
    
    if (error.userInfo[@"com.alamofire.serialization.response.error.response"] != nil) {
        NSHTTPURLResponse * response = error.userInfo[@"com.alamofire.serialization.response.error.response"];
        
        NSDictionary * headers = response.allHeaderFields;
        
        NSString * error = headers[@"x-gateway-error"];
        
        if (error != nil) {
            if ([@"ABOVE_RATE_LIMIT" isEqualToString:error]) {
                NSString * retry = headers[@"retry-after"];
                
                if (retry != nil) {
                    NSTimeInterval retryInterval = [retry doubleValue];
                    
                    self.waitUntil = [NSDate dateWithTimeIntervalSinceNow:retryInterval].timeIntervalSince1970;
                }
            }
        }
    }
    
    if (error.userInfo[@"com.alamofire.serialization.response.error.data"] != nil) {
        id errorObj = [NSJSONSerialization JSONObjectWithData:error.userInfo[@"com.alamofire.serialization.response.error.data"]
                                                      options:0
                                                        error:nil];
        
        NSLog(@"ERROR OBJ: %@", errorObj);
        
        if ([errorObj isKindOfClass:[NSDictionary class]]) {
            NSArray * errors = [errorObj valueForKey:@"errors"];
            
            for (NSDictionary * error in errors) {
                NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
                
                if ([@"expired_token" isEqualToString:error[@"errorType"]]) {
                    NSDate * lastRefresh = [defaults valueForKey:PDKFitbitLastRefreshed];

                    [[PassiveDataKit sharedInstance] logEvent:@"fitbit_expired_token"
                                                   properties:@{ @"last_token_refresh": [lastRefresh description] }];
                    
                    [self logout];
                }
            }
        }
    }
}

- (void) executeRequest:(void(^)(NSString *)) executeBlock error:(void(^)(NSDictionary *)) errorBlock {
    if (executeBlock != nil) {
        @synchronized(self.pendingRequests) {
            [self.pendingRequests addObject:executeBlock];
        }
    }
    
    if (self.isExecuting || self.options[PDKFitbitClientID] == nil || self.options[PDKFitbitClientSecret] == nil) {
        return;
    }
    
    self.isExecuting = YES;

    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    NSString * accessToken = [defaults valueForKey:PDKFitbitAccessToken];
    NSString * refreshToken = [defaults valueForKey:PDKFitbitRefreshToken];
    
    if (accessToken != nil && refreshToken != nil) {
        NSDate * now = [NSDate date];
        NSDate * lastRefresh = [defaults valueForKey:PDKFitbitLastRefreshed];
        
        if (lastRefresh == nil) {
            lastRefresh = [NSDate distantPast];
        }

        if (now.timeIntervalSince1970 - lastRefresh.timeIntervalSince1970 > 60 * 60) {
            [defaults setValue:now forKey:PDKFitbitLastRefreshed];
            [defaults synchronize];
            
            AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
            [manager setResponseSerializer:[AFJSONResponseSerializer serializer]];

            [manager.requestSerializer setAuthorizationHeaderFieldWithUsername:self.options[PDKFitbitClientID]
                                                                      password:self.options[PDKFitbitClientSecret]];

            [manager POST:@"https://api.fitbit.com/oauth2/token"
               parameters:@{
                            @"grant_type": @"refresh_token",
                            @"refresh_token": refreshToken
                            }

                 progress:^(NSProgress * _Nonnull uploadProgress) {

                 } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                     [defaults setValue:responseObject[@"access_token"] forKey:PDKFitbitAccessToken];
                     [defaults setValue:responseObject[@"refresh_token"] forKey:PDKFitbitRefreshToken];
                     [defaults setValue:[NSDate date] forKey:PDKFitbitLastRefreshed];
                     [defaults synchronize];

                     self.isExecuting = NO;
                     
                     [self executeRequest:executeBlock error:errorBlock];
                 } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                     self.isExecuting = NO;

                     if (error.code == 401) {
                         [self logout];
                     } else if (error.userInfo[AFNETWORKING_ERROR_KEY] != nil) {
                         NSDictionary * errorResponse = [NSJSONSerialization JSONObjectWithData:error.userInfo[AFNETWORKING_ERROR_KEY]
                                                                                      options:kNilOptions
                                                                                        error:&error];
                         NSArray * errors = errorResponse[@"errors"];
                         
                         for (NSDictionary * errorItem in errors) {
                             if ([@"invalid_grant" isEqualToString:errorItem[@"errorType"]]) {
                                 [self logout];
                             }
                         }
                     }
                 }];
            
            return;
        }
        
        @synchronized(self.pendingRequests) {
            if (self.pendingRequests.count > 0) {
                void (^toExecute)(NSString *) = nil;
                
                toExecute = [self.pendingRequests lastObject];
                
                [self.pendingRequests removeObject:toExecute];
                
                NSTimeInterval now = [NSDate date].timeIntervalSince1970;
                
                if (now < self.waitUntil) {
                    NSDate * wait = [NSDate dateWithTimeIntervalSince1970:self.waitUntil];
                    
                    errorBlock(@{
                                 @"error-type": @"waiting-rate-limit",
                                 @"wait-until":wait
                                 });
                } else {
                    toExecute(accessToken);
                    
                    [self executeRequest:nil error:^(NSDictionary * error) {
                        errorBlock(error);
                    }];
                }
            }
        }

        self.isExecuting = NO;
    }
}

- (NSString *) generatorId {
    return GENERATOR_ID;
}

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options {
    if ([self.listeners containsObject:listener] == NO) {
        [self.listeners addObject:listener];
    }
    
    [self updateOptions:options];
}

- (void) removeListener:(id<PDKDataListener>)listener {
    [self.listeners removeObject:listener];
}

@end
