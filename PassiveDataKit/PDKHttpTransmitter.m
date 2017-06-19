//
//  PDKHttpTransmitter.m
//  PassiveDataKit
//
//  Created by Chris Karr on 6/18/17.
//  Copyright © 2017 Audacious Software. All rights reserved.
//

#import <SystemConfiguration/SystemConfiguration.h>
#import <sqlite3.h>

#import "NSString+RAInflections.h"

#import "PDKAFURLSessionManager.h"

#import "PDKHttpTransmitter.h"

#define PDK_METADATA_KEY @"passive-data-metadata"
#define PDK_GENERATOR_ID_KEY @"generator-id"
#define PDK_GENERATOR_KEY @"generator"
#define PDK_TIMESTAMP_KEY @"timestamp"

#define PDK_DEFAULT_TRANSMITTER_ID @"http-transmitter"

typedef enum {
    ConnectionTypeUnknown,
    ConnectionTypeNone,
    ConnectionType3G,
    ConnectionTypeWiFi
} ConnectionType;

@interface PDKHttpTransmitter ()

@property NSString * source;
@property NSString * transmitterId;
@property NSURL * uploadUrl;
@property BOOL requireCharging;
@property BOOL requireWiFi;

@property sqlite3 * database;

@end

@implementation PDKHttpTransmitter

+ (ConnectionType) connectionType
{
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, "8.8.8.8");
    SCNetworkReachabilityFlags flags;
    BOOL success = SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);
    if (!success) {
        return ConnectionTypeUnknown;
    }
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    BOOL isNetworkReachable = (isReachable && !needsConnection);
    
    if (!isNetworkReachable) {
        return ConnectionTypeNone;
    } else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
        return ConnectionType3G;
    } else {
        return ConnectionTypeWiFi;
    }
}

- (id<PDKTransmitter>) initWithOptions:(NSDictionary *) options {
    if (self = [super init]) {
        self.source = options[PDK_SOURCE_KEY];

        self.transmitterId = options[PDK_TRANSMITTER_ID_KEY];
        
        if (self.transmitterId == nil) {
            self.transmitterId = PDK_DEFAULT_TRANSMITTER_ID;
        }
        
        if (options[PDK_TRANSMITTER_UPLOAD_URL_KEY] != nil) {
            self.uploadUrl = [NSURL URLWithString:options[PDK_TRANSMITTER_UPLOAD_URL_KEY]];
        } else {
            self.uploadUrl = nil;
        }

        if (options[PDK_TRANSMITTER_REQUIRE_CHARGING_KEY] != nil) {
            self.requireCharging = [options[PDK_TRANSMITTER_REQUIRE_CHARGING_KEY] boolValue];
        } else {
            self.requireCharging = NO;
        }

        if (options[PDK_TRANSMITTER_REQUIRE_WIFI_KEY] != nil) {
            self.requireWiFi = [options[PDK_TRANSMITTER_REQUIRE_WIFI_KEY] boolValue];
        } else {
            self.requireWiFi = NO;
        }
        
        self.database = [self openDatabase];
        
        [[PassiveDataKit sharedInstance] registerListener:self forGenerator:PDKAnyGenerator];
    }
    
    return self;
}

- (NSString *) databasePath
{
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString * cachePath = paths[0];
    
    NSString * filename = [NSString stringWithFormat:@"%@-http-transmitter.sqlite3", [self.transmitterId slugalize], nil];
    
    NSString * dbPath = [cachePath stringByAppendingPathComponent:filename];
    
    return dbPath;
}

- (sqlite3 *) openDatabase {
    NSString * dbPath = [self databasePath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:dbPath] == NO)
    {
        sqlite3 * database = NULL;
        
        const char * path = [dbPath UTF8String];
        
        if (sqlite3_open(path, &database) == SQLITE_OK) {
            char * error;
            
            const char * createStatement = "CREATE TABLE IF NOT EXISTS data (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp REAL, properties TEXT)";
            
            if (sqlite3_exec(database, createStatement, NULL, NULL, &error) != SQLITE_OK) { //!OCLINT
                
            }
            
            sqlite3_close(database);
        }
    }
    
    const char * dbpath = [dbPath UTF8String];
    
    sqlite3 * database = NULL;
    
    if (sqlite3_open(dbpath, &database) == SQLITE_OK) {
        return database;
    }
    
    return NULL;
}

- (void) transmit:(BOOL) force completionHandler:(void (^)(UIBackgroundFetchResult result)) completionHandler {
    if (force == NO && self.requireCharging) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        
        UIDeviceBatteryState batteryState = [UIDevice currentDevice].batteryState;

        [UIDevice currentDevice].batteryMonitoringEnabled = NO;

        if (batteryState == UIDeviceBatteryStateUnplugged || batteryState == UIDeviceBatteryStateUnknown) {
            if (completionHandler != nil) {
                completionHandler(UIBackgroundFetchResultNoData);
            }
            
            return;
        }
    }

    if (force == NO && self.requireWiFi) {
        if ([PDKHttpTransmitter connectionType] != ConnectionTypeWiFi) {
            if (completionHandler != nil) {
                completionHandler(UIBackgroundFetchResultNoData);
            }

            return;
        }
    }

    [self transmitReadings:0 completionHandler:completionHandler];
}

- (void) transmitReadings:(NSUInteger) uploadWindow completionHandler:(void (^)(UIBackgroundFetchResult result)) completionHandler {
    if (uploadWindow == 0) {
        uploadWindow = 8; //!OCLINT
    }
    
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    
    sqlite3_stmt * statement = NULL;
    
    NSString * querySQL = @"SELECT D.id, D.properties FROM data D WHERE (D.timestamp < ?) LIMIT 16";
    
    const char * query_stmt = [querySQL UTF8String];
    
    if (sqlite3_prepare_v2(self.database, query_stmt, -1, &statement, NULL) == SQLITE_OK)
    {
        sqlite3_bind_double(statement, 1, now);
        
        NSMutableArray * payload = [NSMutableArray array];
        NSMutableArray * uploaded = [NSMutableArray array];
        
        while (sqlite3_step(statement) == SQLITE_ROW)
        {
            NSInteger pointId = sqlite3_column_int(statement, 0);
            NSString * jsonString = [[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(statement, 1)];
            
            NSError * error = nil;
            
            NSMutableDictionary * dataPoint = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]
                                                                              options:(NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves)
                                                                                error:&error];
            if (error == nil) {
                [uploaded addObject:[NSNumber numberWithInteger:pointId]];
                [payload addObject:dataPoint];
            }
            else {
                NSLog(@"Error fetching from PDKHttpTranmitter database: %@", error);

                if (completionHandler != nil) {
                    completionHandler(UIBackgroundFetchResultFailed);
                }

                return;
            }
        }
        
        sqlite3_finalize(statement);
        
        NSMutableURLRequest *req = [[PDKAFJSONRequestSerializer serializer] requestWithMethod:@"CREATE"
                                                                                    URLString:[self.uploadUrl description]
                                                                                   parameters:payload
                                                                                        error:nil];
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        NSLog(@"UPLOADING PAYLOAD: %@", payload);
        
        PDKAFURLSessionManager * manager = [[PDKAFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        
        [[manager dataTaskWithRequest:req
                       uploadProgress:nil
                     downloadProgress:nil
                    completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                        if ([responseObject containsObject:@"Data bundle added successfully, and ready for processing."] == NO) {
                            NSLog(@"Invalid response: %@", responseObject);
                        }
                        else if (error == nil) {
                            for (NSNumber * identifier in uploaded) {
                                sqlite3_stmt * deleteStatement = NULL;
                                
                                NSString * deleteSQL = @"DELETE FROM data WHERE (id = ?)";
                                
                                const char * delete_stmt = [deleteSQL UTF8String];
                                
                                if (sqlite3_prepare_v2(self.database, delete_stmt, -1, &deleteStatement, NULL) == SQLITE_OK)
                                {
                                    sqlite3_bind_int(deleteStatement, 1, [identifier intValue]);
                                    
                                    while (sqlite3_step(deleteStatement) == SQLITE_ROW) { //!OCLINT
                                        
                                    }
                                    
                                    sqlite3_finalize(deleteStatement);
                                } else {
                                    if (completionHandler != nil) {
                                        completionHandler(UIBackgroundFetchResultFailed);
                                    }

                                    NSLog(@"Error while deleting data. '%s'", sqlite3_errmsg(self.database));

                                    return;
                                }
                            }
                            
                            NSTimeInterval interval = [NSDate date].timeIntervalSince1970 - now;
                            
                            if (uploadWindow > 0 && interval > uploadWindow && uploaded.count > 0) {
                                [self transmitReadings:(uploadWindow - interval) completionHandler:completionHandler];
                            } else {
                                if (completionHandler != nil) {
                                    completionHandler(UIBackgroundFetchResultNewData);
                                }

                            }
                        }
                        
                    }] resume];
    }
}

- (NSUInteger) pendingSize {
    return -1;
}

- (NSUInteger) transmittedSize {
    return -1;
}

- (void) receivedData:(NSDictionary *) data forGenerator:(PDKDataGenerator) dataGenerator {
    NSMutableDictionary * toStore = [NSMutableDictionary dictionaryWithDictionary:data];
    
    if (toStore[PDK_METADATA_KEY] == nil) {
        NSMutableDictionary * metadata = [NSMutableDictionary dictionary];
        
        id<PDKGenerator> generator = [[PassiveDataKit sharedInstance] generatorInstance:dataGenerator];
        
        metadata[PDK_GENERATOR_ID_KEY] = [generator generatorId];
        metadata[PDK_GENERATOR_KEY] = [generator fullGeneratorName];
        
        if (self.source != nil) {
            metadata[PDK_SOURCE_KEY] = self.source;
        } else {
            metadata[PDK_SOURCE_KEY] = [[PassiveDataKit sharedInstance] identifierForUser];
        }

        metadata[PDK_TIMESTAMP_KEY] = [NSNumber numberWithDouble:[NSDate date].timeIntervalSince1970];
        
        toStore[PDK_METADATA_KEY] = metadata;
    }
    
    sqlite3_stmt * stmt;
    
    NSString * insert = @"INSERT INTO data (timestamp, properties) VALUES (?, ?);";
    
    if(sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_double(stmt, 1, [toStore[PDK_METADATA_KEY][PDK_TIMESTAMP_KEY] doubleValue]);
        
        NSError * err = nil;
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:toStore options:0 error:&err];
        NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
        sqlite3_bind_text(stmt, 2, [jsonString UTF8String], -1, SQLITE_TRANSIENT);
        
        if (SQLITE_DONE != sqlite3_step(stmt)) {
            NSLog(@"Error while inserting data. '%s'", sqlite3_errmsg(self.database));
        }
        
        sqlite3_finalize(stmt);
    }
}

@end
