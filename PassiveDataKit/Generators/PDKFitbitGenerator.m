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


NSString * const PDKFitbitClientID = @"PDKFitbitClientID"; //!OCLINT
NSString * const PDKFitbitCallbackURL = @"PDKFitbitCallbackURL"; //!OCLINT
NSString * const PDKFitbitClientSecret = @"PDKFitbitClientSecret"; //!OCLINT

NSString * const PDKFitbitAuthState = @"PDKFitbitAuthState"; //!OCLINT

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

NSString * const PDKFitbitAlert = @"pdk-fitbit-alert"; //!OCLINT

@interface PDKFitbitGenerator()

@property NSMutableArray * listeners;

@property id<OIDExternalUserAgentSession> currentExternalUserAgentFlow;
@property NSDictionary * options;

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
    return NSLocalizedStringFromTableInBundle(@"name_generator_fitbit", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
}

- (void) refresh {
    BOOL authed = YES;
    
    if (self.options[PDKFitbitClientID] == nil || self.options[PDKFitbitCallbackURL] == nil || self.options[PDKFitbitClientSecret] == nil) {
        NSLog(@"FB OPTIONS: %@", self.options);

        NSString * message = NSLocalizedStringFromTableInBundle(@"message_generator_fitbit_app_misconfigured", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);

        [[PassiveDataKit sharedInstance] updateAlertWithTag:PDKFitbitAlert message:message level:PDKAlertLevelError action:^{

        }];
    }

    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    NSData * authStateData = [defaults valueForKey:PDKFitbitAuthState];

    if (authed && authStateData == nil) {
        authed = NO;
    }


    if (authed) {
        OIDAuthState *authState = (OIDAuthState *) [NSKeyedUnarchiver unarchiveObjectWithData:authStateData];

        [authState performActionWithFreshTokens:^(NSString * _Nullable accessToken, NSString * _Nullable idToken, NSError * _Nullable error) {
            AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];

            NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.fitbit.com/1/user/-/activities.json"]];
            [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];
 
            NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                        uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                            
                                                        } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                            
                                                        } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                            [[PassiveDataKit sharedInstance] cancelAlertWithTag:PDKFitbitAlert];

                                                            NSLog(@"GOT RESPONSE: %@", responseObject);
                                                        }];
            [task resume];
        }];
    } else {
        NSString * message = NSLocalizedStringFromTableInBundle(@"message_generator_fitbit_needs_auth", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);

        [[PassiveDataKit sharedInstance] updateAlertWithTag:PDKFitbitAlert message:message level:PDKAlertLevelError action:^{
            NSURL * authorizationEndpoint = [NSURL URLWithString:@"https://www.fitbit.com/oauth2/authorize"];
            NSURL * tokenEndpoint = [NSURL URLWithString:@"https://api.fitbit.com/oauth2/token"];

            OIDServiceConfiguration * configuration = [[OIDServiceConfiguration alloc] initWithAuthorizationEndpoint:authorizationEndpoint
                                                                                                       tokenEndpoint:tokenEndpoint];
            
            NSArray * scopes = self.options[PDKFitbitScopes];
            
            if (scopes == nil || scopes.count == 0) {
                scopes = @[PDKFitbitScopeActivity];
            }

            OIDAuthorizationRequest *request = [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                                                             clientId:self.options[PDKFitbitClientID]
                                                                                         clientSecret:self.options[PDKFitbitClientSecret]
                                                                                               scopes:scopes
                                                                                          redirectURL:[NSURL URLWithString:self.options[PDKFitbitCallbackURL]]
                                                                                         responseType:OIDResponseTypeCode
                                                                                 additionalParameters:nil];

            NSLog(@"FB 11");

            UIWindow * window = [[[UIApplication sharedApplication] delegate] window];

            NSLog(@"FB 12");

            self.currentExternalUserAgentFlow = [OIDAuthState authStateByPresentingAuthorizationRequest:request
                                                                               presentingViewController:window.rootViewController
                                                                                               callback:^(OIDAuthState *_Nullable authState, NSError *_Nullable error) {
                                                                                                   if (authState) {
                                                                                                       NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
                                                                                                       
                                                                                                       NSData * authData = [NSKeyedArchiver archivedDataWithRootObject:authState];
                                                                                                       
                                                                                                       [defaults setValue:authData
                                                                                                                   forKey:PDKFitbitAuthState];
                                                                                                       [defaults synchronize];
                                                                                                       
                                                                                                       [[PDKFitbitGenerator sharedInstance] refresh];
                                                                                                   } else {
                                                                                                       NSLog(@"Authorization error: %@", [error localizedDescription]);
                                                                                                   }
                                                                                               }];
        }];
    }
}

- (BOOL)application:(UIApplication *) app openURL:(NSURL *) url options:(NSDictionary<NSString *, id> *) options {
    NSLog(@"FB HANDLE URL: %@", url);
    
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
/*
    Activities
        Calories
            BMR
            activity
            goal
        Steps
            Distance
        Floors
            Elevation
        Minutes
            very active
            fairly active
            lightly active
            sedentary
 
    Body
        fat %
            source
        weight
            bmi
            source
 
    Heart Rate (since last check)
        mins unknown
        mins resting
        mins fat burn
        mins cardio
        mins peak
 
    Sleep
        level
        duration
        interval start
 */
    
/*    NSString * dbPath = [self databasePath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:dbPath] == NO)
    {
        sqlite3 * database = NULL;
        
        const char * path = [dbPath UTF8String];
        
        int retVal = sqlite3_open_v2(path, &database, SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE|SQLITE_OPEN_FILEPROTECTION_NONE, NULL);
        
        if (retVal == SQLITE_OK) {
            char * error;
            
            const char * createStatement = "CREATE TABLE IF NOT EXISTS battery_data (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp REAL, level REAL, status TEXT)";
            
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
    } */
    
    return NULL;
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

@end
