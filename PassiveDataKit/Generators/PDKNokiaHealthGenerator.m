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


NSString * const PDKNokiaHealthAlert = @"pdk-nokia-health-alert"; //!OCLINT
NSString * const PDKNokiaHealthAlertMisconfigured = @"pdk-nokia-health-misconfigured-alert"; //!OCLINT

@interface PDKNokiaHealthGenerator()

@property NSMutableArray * listeners;

@property id<OIDExternalUserAgentSession> currentExternalUserAgentFlow;
@property NSDictionary * options;

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
        
        //        self.database = [self openDatabase];
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
        NSLog(@"NH OPTIONS: %@", self.options);
        
        NSString * title = NSLocalizedStringFromTableInBundle(@"title_generator_nokia_health_app_misconfigured", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
        NSString * message = NSLocalizedStringFromTableInBundle(@"message_generator_nokia_health_app_misconfigured", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
        
        [[PassiveDataKit sharedInstance] updateAlertWithTag:PDKNokiaHealthAlertMisconfigured title:title message:message level:PDKAlertLevelError action:^{
            
        }];
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
            [[PDKNokiaHealthGenerator sharedInstance] loginToService];
        }];
    } else {
        [[PassiveDataKit sharedInstance] cancelAlertWithTag:PDKNokiaHealthAlert];
    }

    if (authed) {
        OIDAuthState *authState = (OIDAuthState *) [NSKeyedUnarchiver unarchiveObjectWithData:authStateData];
        
        [authState performActionWithFreshTokens:^(NSString * _Nullable accessToken, NSString * _Nullable idToken, NSError * _Nullable error) {
            NSNumber * activitiesEnabled = self.options[PDKNokiaHealthActivityMeasuresEnabled];
            
            if (activitiesEnabled == nil) {
                activitiesEnabled = @(YES);
            }
            
            if (activitiesEnabled.boolValue) {
                [self fetchActivityMeasuresWithAccessToken:accessToken];
            }

            NSNumber * intradayActivitiesEnabled = self.options[PDKNokiaHealthIntradayActivityMeasuresEnabled];
            
            if (intradayActivitiesEnabled == nil) {
                intradayActivitiesEnabled = @(YES);
            }
            
            if (intradayActivitiesEnabled.boolValue) {
                [self fetchIntradayActivityMeasuresWithAccessToken:accessToken];
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
        }];
    }
}

- (void) fetchActivityMeasuresWithAccessToken:(NSString *) accessToken {
    __weak __typeof(self) weakSelf = self;
    
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.health.nokia.com/v2/measure?action=getactivity&access_token=[STRING]&startdateymd=[YMD]&enddateymd=[YMD]&offset=[INT]"]];
    
    NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                    
                                                } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                    
                                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                    
                                                    if (error != nil) {
                                                        NSLog(@"NH WEIGHT ERROR: %@", error);
                                                        [[PDKNokiaHealthGenerator sharedInstance] logout];
                                                    } else {
                                                        NSLog(@"GOT RESPONSE: %@", responseObject);
                                                        
                                                        [weakSelf logActivityMeasures:responseObject];
                                                    }
                                                }];
    [task resume];
}

- (void) logActivityMeasures:(id) responseObject {
    NSLog(@"NH ACTIVITY MEASURES: %@", responseObject);
}

- (void) fetchIntradayActivityMeasuresWithAccessToken:(NSString *) accessToken {
    __weak __typeof(self) weakSelf = self;
    
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.health.nokia.com/v2/measure?action=getintradayactivity&access_token=[STRING]&startdate=[INT]&enddate=[INT]"]];
    
    NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                    
                                                } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                    
                                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                    
                                                    if (error != nil) {
                                                        NSLog(@"NH WEIGHT ERROR: %@", error);
                                                        [[PDKNokiaHealthGenerator sharedInstance] logout];
                                                    } else {
                                                        NSLog(@"GOT RESPONSE: %@", responseObject);
                                                        
                                                        [weakSelf logIntradayActivityMeasures:responseObject];
                                                    }
                                                }];
    [task resume];
}

- (void) logIntradayActivityMeasures:(id) responseObject {
    NSLog(@"NH INTRADAY ACTIVITY MEASURES: %@", responseObject);

    NSNumber * status = [responseObject valueForKey:@"status"];
    
    if (status != nil && status.integerValue == 0) {
        NSDictionary * body = [responseObject valueForKey:@"body"];
        
        
    }
}

- (void) fetchSleepMeasuresWithAccessToken:(NSString *) accessToken {
    __weak __typeof(self) weakSelf = self;
    
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.health.nokia.com/v2/sleep?action=get&access_token=[STRING]&startdate=[INT]&enddate=[INT]"]];
    
    NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                    
                                                } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                    
                                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                    
                                                    if (error != nil) {
                                                        NSLog(@"NH WEIGHT ERROR: %@", error);
                                                        [[PDKNokiaHealthGenerator sharedInstance] logout];
                                                    } else {
                                                        NSLog(@"GOT RESPONSE: %@", responseObject);
                                                        
                                                        [weakSelf logSleepMeasures:responseObject];
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
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.health.nokia.com/v2/sleep?action=getsummary&access_token=[STRING]&startdateymd=[YMD]&enddateymd=[YMD]"]];
    
    NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                    
                                                } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                    
                                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                    
                                                    if (error != nil) {
                                                        NSLog(@"NH WEIGHT ERROR: %@", error);
                                                        [[PDKNokiaHealthGenerator sharedInstance] logout];
                                                    } else {
                                                        NSLog(@"GOT RESPONSE: %@", responseObject);
                                                        
                                                        [weakSelf logSleepSummary:responseObject];
                                                    }
                                                }];
    [task resume];
}

- (void) logSleepSummary:(id) responseObject {
    NSLog(@"NH SLEEP SUMMARY: %@", responseObject);
}

- (void) fetchBodyMeasuresWithAccessToken:(NSString *) accessToken {
    __weak __typeof(self) weakSelf = self;
    
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.health.nokia.com/measure?action=getmeas&access_token=[STRING]&meastype=[INTEGER]&category=[INT]&startdate=[INT]&enddate=[INT]&offset=[INT]"]];
    
    NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                    
                                                } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                    
                                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                    
                                                    if (error != nil) {
                                                        NSLog(@"NH WEIGHT ERROR: %@", error);
                                                        [[PDKNokiaHealthGenerator sharedInstance] logout];
                                                    } else {
                                                        NSLog(@"GOT RESPONSE: %@", responseObject);
                                                        
                                                        [weakSelf logBodyMeasures:responseObject];
                                                    }
                                                }];
    [task resume];
}

- (void) logBodyMeasures:(id) responseObject {
    NSLog(@"NH BODY MEASURES: %@", responseObject);
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

- (void) loginToService {
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
    
    NSLog(@"NH REQUEST: %@", request.externalUserAgentRequestURL);
    NSLog(@"NH REQUEST REDIR : %@", request.redirectURL);

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
                                                     
                                                     NSLog(@"AAA TOK CODE ID %@", tokenExchangeRequest.clientID);
                                                     NSLog(@"AAA TOK CODE SECRET %@", tokenExchangeRequest.clientSecret);
                                                     
                                                     NSLog(@"AAA Token Request: %@\nHTTPBody: %@",
                                                           [tokenExchangeRequest URLRequest].URL,
                                                           [[NSString alloc] initWithData:[tokenExchangeRequest URLRequest].HTTPBody
                                                                                 encoding:NSUTF8StringEncoding]);

                                                     [OIDAuthorizationService performTokenRequest:tokenExchangeRequest
                                                                    originalAuthorizationResponse:authorizationResponse
                                                                                         callback:^(OIDTokenResponse *_Nullable tokenResponse,
                                                                                                    NSError *_Nullable tokenError) {
                                                                                             OIDAuthState *authState;
                                                                                             if (tokenResponse) {
                                                                                                 authState = [[OIDAuthState alloc]
                                                                                                              initWithAuthorizationResponse:
                                                                                                              authorizationResponse
                                                                                                              tokenResponse:tokenResponse];
                                                                                             }

                                                                                             NSLog(@"NH AUTH STATE : %@", authState);
                                                                                             NSLog(@"NH ERROR : %@", tokenError);
                                                                                             
                                                                                             if (authState) {
                                                                                                 NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
                                                                                                 
                                                                                                 NSData * authData = [NSKeyedArchiver archivedDataWithRootObject:authState];
                                                                                                 
                                                                                                 [defaults setValue:authData
                                                                                                             forKey:PDKNokiaHealthAuthState];
                                                                                                 [defaults synchronize];
                                                                                                 
                                                                                                 [[PDKNokiaHealthGenerator sharedInstance] refresh];
                                                                                             } else {
                                                                                                 NSLog(@"NH Authorization error: %@", [tokenError localizedDescription]);
                                                                                             }
                                                                                         }];
                                                 }
                                             }
                                         }];

    NSLog(@"NH FLOW : %@", self.currentExternalUserAgentFlow);
}

- (void) logout {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    [defaults removeObjectForKey:PDKNokiaHealthAuthState];
    [defaults synchronize];
}

@end
