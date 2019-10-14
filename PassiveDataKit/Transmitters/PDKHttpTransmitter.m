//
//  PDKHttpTransmitter.m
//  PassiveDataKit
//
//  Created by Chris Karr on 6/18/17.
//  Copyright © 2017 Audacious Software. All rights reserved.
//

#import <SystemConfiguration/SystemConfiguration.h>
#import <sqlite3.h>

@import AFNetworking;

#import "PDKHttpTransmitter.h"

typedef enum {
    ConnectionTypeUnknown,
    ConnectionTypeNone,
    ConnectionType3G,
    ConnectionTypeWiFi
} ConnectionType;

@interface PDKHttpTransmitter ()<NSURLSessionDelegate>

@property BOOL requireCharging;
@property BOOL requireWiFi;

@property sqlite3 * database;

@property NSURLSession * session;

@property NSMutableArray * readingsTransmitted;
@property NSTimeInterval lastTransmissionStart;

@property NSUInteger payloadSizeCount;

@end

@implementation PDKHttpTransmitter

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

        if (options[PDK_TRANSMITTER_PAYLOAD_SIZE_KEY] != nil) {
            self.payloadSizeCount = [options[PDK_TRANSMITTER_PAYLOAD_SIZE_KEY] unsignedIntegerValue];
        } else {
            self.payloadSizeCount = 32;
        }
        
        self.database = [self openDatabase];
        
//        NSDictionary * infoDict = [[NSBundle mainBundle] infoDictionary];
//        NSString * appId = [infoDict objectForKey:@"CFBundleIdentifier"];
        
//        NSString * backgroundIdentifier = [NSString stringWithFormat:@"pdk-http-transmitter-%@", appId];
        
//        NSURLSessionConfiguration * urlSessionConfig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:backgroundIdentifier];
        
        self.readingsTransmitted = [NSMutableArray array];
        
//        self.session = [NSURLSession sessionWithConfiguration:urlSessionConfig
//                                                     delegate:self
//                                                delegateQueue:nil];

        NSURLSessionConfiguration * urlSessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:urlSessionConfig];

        [[PassiveDataKit sharedInstance] registerListener:self forGenerator:PDKAnyGenerator options:@{}];
    }
    
    return self;
}

- (NSUInteger) pendingSize {
    return -1;
}

- (NSUInteger) transmittedSize {
    return -1;
}

- (void) unregister {
    [[PassiveDataKit sharedInstance] unregisterListener:self forGenerator:PDKAnyGenerator];
}

#pragma mark - Database Methods

- (NSString *) databasePath {
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
        
        if (sqlite3_open_v2(path, &database, SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE|SQLITE_OPEN_FILEPROTECTION_NONE, NULL) == SQLITE_OK) { //!OCLINT
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

- (NSInteger) pendingDataPoints {
    NSInteger remaining = -1;

    @synchronized(self) {
        sqlite3_stmt * countStatement = NULL;
        
        NSString * querySQL = @"SELECT COUNT(*) FROM data";
        
        const char * query_stmt = [querySQL UTF8String];
        
        if (sqlite3_prepare_v2(self.database, query_stmt, -1, &countStatement, NULL) == SQLITE_OK) {
            sqlite3_step(countStatement);
            
            remaining = sqlite3_column_int(countStatement, 0);
            
            sqlite3_finalize(countStatement);
        }
    }
    
    return remaining;
}

#pragma mark - Data Transmission Methods

- (NSURLRequest *) uploadRequestForPayload:(NSArray *) payload {
    if (payload.count > 0) {
        NSMutableURLRequest * request = [[AFJSONRequestSerializer serializer] requestWithMethod:@"CREATE"
                                                                                      URLString:[self.uploadUrl description]
                                                                                     parameters:payload
                                                                                          error:nil];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        return request;
    }
    
    return nil;
}

- (NSUInteger) payloadSize {
    // TODO: Make configurable...
    
    return self.payloadSizeCount;
}

- (void) transmitWithCompletionHandler:(void (^)(UIBackgroundFetchResult result)) completionHandler; {
    if (self.lastTransmissionStart != 0) {
        if (completionHandler != nil) {
            completionHandler(UIBackgroundFetchResultNoData);
        }
        
        return;
    }
    
    self.lastTransmissionStart = [NSDate date].timeIntervalSince1970;
    [self.readingsTransmitted removeAllObjects];
    
    [self transmitReadingsWithCompletionHandler:completionHandler];
}

- (void) transmitReadingsWithCompletionHandler:(void (^)(UIBackgroundFetchResult result)) completionHandler; {
    @synchronized(self) {
        for (NSNumber * identifier in self.readingsTransmitted) {
            sqlite3_stmt * deleteStatement = NULL;
            
            NSString * deleteSQL = @"DELETE FROM data WHERE (id = ?)";
            
            const char * delete_stmt = [deleteSQL UTF8String];
            
            if (sqlite3_prepare_v2(self.database, delete_stmt, -1, &deleteStatement, NULL) == SQLITE_OK)
            {
                if (sqlite3_bind_int(deleteStatement, 1, [identifier intValue]) == SQLITE_OK) {
                    sqlite3_step(deleteStatement);
                }
                
                sqlite3_finalize(deleteStatement);
            }
        }
        
        [self.readingsTransmitted removeAllObjects];
    }
    
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    
    if (now - self.lastTransmissionStart > 15) {
        if (completionHandler != nil) {
            self.lastTransmissionStart = 0;

            completionHandler(UIBackgroundFetchResultNewData);
        }
        
        return;
    }
    
    @synchronized(self) {
        NSInteger remaining = [self pendingDataPoints];
        
        if (remaining >=  1) {
            sqlite3_stmt * statement = NULL;
            
            NSString * querySQL = [NSString stringWithFormat:@"SELECT D.id, D.properties FROM data D ORDER BY D.timestamp LIMIT %d", (int) [self payloadSize]];
            
            const char * query_stmt = [querySQL UTF8String];
            
            if (sqlite3_prepare_v2(self.database, query_stmt, -1, &statement, NULL) == SQLITE_OK) {
                NSMutableArray * payload = [NSMutableArray array];
                
                while (sqlite3_step(statement) == SQLITE_ROW) {
                    NSInteger pointId = sqlite3_column_int(statement, 0);
                    
                    const unsigned char * rawJsonString = sqlite3_column_text(statement, 1);
                    
                    if (rawJsonString != NULL) {
                        NSString * jsonString = [[NSString alloc] initWithUTF8String:(const char *) rawJsonString];
                        
                        NSError * error = nil;
                        
                        if (jsonString != nil) {
                            NSMutableDictionary * dataPoint = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]
                                                                                              options:(NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves)
                                                                                                error:&error];
                            
                            if (error == nil) {
                                [self.readingsTransmitted addObject:[NSNumber numberWithInteger:pointId]];
                                [payload addObject:dataPoint];
                            }
                            else {
                                NSLog(@"Error fetching from PDKHttpTransmitter database: %@", error);
                                
                                [self.readingsTransmitted addObject:[NSNumber numberWithInteger:pointId]];
                            }
                        }
                    }
                }
                
                NSURLRequest * request = [self uploadRequestForPayload:payload];

                if (request != nil) { //!OCLINT
                    NSURLSessionDownloadTask * upload = [self.session downloadTaskWithRequest:request
                                                                            completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                                                // NSLog(@"MAIN XMIT ERROR: %@", error);
                                                                                
                                                                                if (error != nil) {
                                                                                    self.lastTransmissionStart = 0;
                                                                                    
                                                                                    completionHandler(UIBackgroundFetchResultFailed);
                                                                                    
                                                                                    return;
                                                                                }

                                                                                [self transmitReadingsWithCompletionHandler:completionHandler];
                                                                            }];

                    [upload resume];
                }
                
                sqlite3_finalize(statement);
            }
        } else {
            if (completionHandler != nil) {
                self.lastTransmissionStart = 0;
                
                completionHandler(UIBackgroundFetchResultNewData);
            }
        }
    }
}

#pragma mark - Data Storage Methods

- (NSDictionary *) processIncomingDataPoint:(NSDictionary *) dataPoint forGenerator:(PDKDataGenerator) dataGenerator {
    id<PDKGenerator> generator = [[PassiveDataKit sharedInstance] generatorInstance:dataGenerator];
    
    return [self processIncomingDataPoint:dataPoint forCustomGenerator:[generator generatorId]];
}

- (NSDictionary *) processIncomingDataPoint:(NSDictionary *) dataPoint forCustomGenerator:(NSString *) generatorId {
    NSMutableDictionary * toStore = [NSMutableDictionary dictionaryWithDictionary:dataPoint];
    
    if (toStore[PDK_METADATA_KEY] == nil) {
        NSMutableDictionary * metadata = [NSMutableDictionary dictionary];
        
        metadata[PDK_GENERATOR_ID_KEY] = generatorId;
        metadata[PDK_GENERATOR_KEY] = [NSString stringWithFormat:@"%@: %@", generatorId, [[PassiveDataKit sharedInstance] userAgent]];
        
        if (self.source != nil) {
            metadata[PDK_SOURCE_KEY] = self.source;
        } else {
            metadata[PDK_SOURCE_KEY] = [[PassiveDataKit sharedInstance] identifierForUser];
        }
        
        metadata[PDK_TIMESTAMP_KEY] = @([NSDate date].timeIntervalSince1970);
        
        toStore[PDK_METADATA_KEY] = metadata;
    }
    
    return toStore;
}

- (void) receivedData:(NSDictionary *) dataPoint forGenerator:(PDKDataGenerator) dataGenerator {
    NSDictionary * toStore = [self processIncomingDataPoint:dataPoint forGenerator:dataGenerator];
    
    @synchronized (self) {
        if (toStore != nil) {
            sqlite3_stmt * stmt = NULL;
            
            NSString * insert = @"INSERT INTO data (timestamp, properties) VALUES (?, ?)";
            
            if(sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
                if (sqlite3_bind_double(stmt, 1, [toStore[PDK_METADATA_KEY][PDK_TIMESTAMP_KEY] doubleValue]) == SQLITE_OK) {
                    NSError * err = nil;
                    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:toStore options:0 error:&err];
                    NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                    
                    if (sqlite3_bind_text(stmt, 2, [jsonString UTF8String], -1, SQLITE_TRANSIENT) == SQLITE_OK) {
                        int retVal = sqlite3_step(stmt);

                        if (SQLITE_DONE != retVal) {
                            NSLog(@"Error while inserting data. %d '%s'", retVal, sqlite3_errmsg(self.database));
                        }
                    } else {
                        NSLog(@"Error WITH JSON STRING: %@", jsonString);
                    }
                }

                sqlite3_finalize(stmt);
            }
        }
    }
}

- (void) receivedData:(NSDictionary *) dataPoint forCustomGenerator:(NSString *) generatorId {
    NSDictionary * toStore = [self processIncomingDataPoint:dataPoint forCustomGenerator:generatorId];
    
    @synchronized (self) {
        if (toStore != nil) {
            sqlite3_stmt * stmt;
            
            NSString * insert = @"INSERT INTO data (timestamp, properties) VALUES (?, ?);";
            
            if(sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
                if (sqlite3_bind_double(stmt, 1, [toStore[PDK_METADATA_KEY][PDK_TIMESTAMP_KEY] doubleValue]) == SQLITE_OK) {
                    NSError * err = nil;
                    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:toStore options:0 error:&err];
                    NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                    
                    sqlite3_bind_text(stmt, 2, [jsonString UTF8String], -1, SQLITE_TRANSIENT);
                    
                    if (SQLITE_DONE != sqlite3_step(stmt)) {
                        NSLog(@"Error while inserting data. '%s'", sqlite3_errmsg(self.database));
                    }
                }
                
                sqlite3_finalize(stmt);
            }
        }
    }
}

@end
