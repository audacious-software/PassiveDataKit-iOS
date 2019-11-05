//
//  PDKBatteryGenerator.m
//  PassiveDataKit
//
//  Created by Chris Karr on 9/18/17.
//  Copyright © 2017 Audacious Software. All rights reserved.
//

#include <sqlite3.h>

@import Charts;

#import "PDKBatteryGenerator.h"
#import "PDKBatteryGeneratorViewController.h"

NSString * const PDKBatteryLevel = @"level"; //!OCLINT

NSString * const PDKBatteryStatus = @"status"; //!OCLINT
NSString * const PDKBatteryStatusFull = @"full"; //!OCLINT
NSString * const PDKBatteryStatusCharging = @"charging"; //!OCLINT
NSString * const PDKBatteryStatusUnplugged = @"discharging"; //!OCLINT
NSString * const PDKBatteryStatusUnknown = @"unknown"; //!OCLINT

#define GENERATOR_ID @"pdk-device-battery"

#define RETENTION_PERIOD @"PDKGeofencesGenerator.RETENTION_PERIOD"
#define RETENTION_PERIOD_DEFAULT (90 * 24 * 60 * 60)

#define DATABASE_VERSION @"PDKBatteryGenerator.DATABASE_VERSION"
#define CURRENT_DATABASE_VERSION @(1)

@interface PDKBatteryGenerator()

@property NSMutableArray * listeners;
@property NSDictionary * lastOptions;

@property NSMutableArray * batteryDays;

@property sqlite3 * database;
@property NSDateFormatter * dateFormatter;
@property NSDateFormatter * dateDisplayFormatter;

@end

static PDKBatteryGenerator * sharedObject = nil;

@implementation PDKBatteryGenerator

+ (PDKBatteryGenerator *) sharedInstance {
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

        self.database = [self openDatabase];

        self.dateFormatter = [[NSDateFormatter alloc] init];
        self.dateFormatter.dateFormat = @"yyyy'-'MM'-'dd'";

        self.dateDisplayFormatter = [[NSDateFormatter alloc] init];
        self.dateDisplayFormatter.timeStyle = NSDateFormatterNoStyle;
        self.dateDisplayFormatter.dateStyle = NSDateFormatterShortStyle;

        self.batteryDays = [NSMutableArray array];
    }
    
    return self;
}

- (NSString *) databasePath {
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString * documentsPath = paths[0];
    
    NSString * dbPath = [documentsPath stringByAppendingPathComponent:@"pdk-battery.sqlite3"];
    
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
    }
    
    return NULL;
}

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options {
    if ([self.listeners containsObject:listener] == NO) {
        [self.listeners addObject:listener];
    }
    
    if (self.listeners.count > 0) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryDidChange:) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryDidChange:) name:UIDeviceBatteryStateDidChangeNotification object:nil];

        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        
        [self batteryDidChange:nil];

    }
}

- (void) removeListener:(id<PDKDataListener>)listener {
    [self.listeners removeObject:listener];
    
    if (self.listeners.count == 0) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        
        [UIDevice currentDevice].batteryMonitoringEnabled = NO;
    }
}

- (void) refresh {
    [self batteryDidChange:nil];
}

- (void) batteryDidChange:(NSNotification *) theNote { //!OCLINT
    NSDate * now = [NSDate date];

    NSMutableDictionary * data = [NSMutableDictionary dictionary];

    float level = [UIDevice currentDevice].batteryLevel * 100.0;
    
    if (level < 0) {
        return;
    }
    
    data[PDKBatteryLevel] = [NSNumber numberWithFloat:level];
    
    switch([UIDevice currentDevice].batteryState) {
        case UIDeviceBatteryStateFull:
            data[PDKBatteryStatus] = PDKBatteryStatusFull;
            break;
        case UIDeviceBatteryStateCharging:
            data[PDKBatteryStatus] = PDKBatteryStatusCharging;
            break;
        case UIDeviceBatteryStateUnplugged:
            data[PDKBatteryStatus] = PDKBatteryStatusUnplugged;
            break;
        case UIDeviceBatteryStateUnknown:
            data[PDKBatteryStatus] = PDKBatteryStatusUnknown;
            break;
    }

    sqlite3_stmt * stmt;
    
    NSString * insert = @"INSERT INTO battery_data (timestamp, level, status) VALUES (?, ?, ?);";
    
    int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL);
    
    if (retVal == SQLITE_OK) {
        if (sqlite3_bind_double(stmt, 1, now.timeIntervalSince1970) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 2, (double) level) == SQLITE_OK &&
            sqlite3_bind_text(stmt, 3, [data[PDKBatteryStatus] cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT) == SQLITE_OK) {
            
            int retVal = sqlite3_step(stmt);
            
            if (SQLITE_DONE != retVal) {
                NSLog(@"Error while inserting data. %d '%s'", retVal, sqlite3_errmsg(self.database));
            }
        }
        
        sqlite3_finalize(stmt);
    }
    
    [[PassiveDataKit sharedInstance] receivedData:data forGenerator:PDKBattery];
}

- (NSString *) generatorId {
    return GENERATOR_ID;
}

+ (NSString *) title {
    return NSLocalizedStringFromTableInBundle(@"name_generator_battery", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
}

+ (UIViewController *) detailsController {
    return [[PDKBatteryGeneratorViewController alloc] init];
}

- (UIView *) visualizationForSize:(CGSize) size {
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
    
    LineChartDataSet * dataSet = [[LineChartDataSet alloc] initWithEntries:levels label:@""];
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
    
    NSString * delete = @"DELETE FROM battery_data WHERE timestamp < ?";
    
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
