//
//  PDKEventManager.m
//  PassiveDataKit
//
//  Created by Chris Karr on 6/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

#import <sqlite3.h>

#import "Mixpanel.h"

#import "PassiveDataKit.h"
#import "PDKAFHTTPSessionManager.h"
#import "PDKDataPointsManager.h"
#import "PDKMixpanelEventGenerator.h"
#import "PDKEventGenerator.h"

@interface PDKDataPointsManager ()

@property sqlite3 * database;

@end

@implementation PDKDataPointsManager

static PDKDataPointsManager * sharedObject = nil;

+ (PDKDataPointsManager *) sharedInstance
{
    static dispatch_once_t _singletonPredicate;
    
    dispatch_once(&_singletonPredicate, ^{
        sharedObject = [[super allocWithZone:nil] init];
        
    });
    
    return sharedObject;
}

+ (id) allocWithZone:(NSZone *) zone //!OCLINT
{
    return [self sharedInstance];
}

- (id) init
{
    if (self = [super init])
    {
        self.database = [self openDatabase];
    }
    
    return self;
}

- (BOOL) logEvent:(NSString *) eventName properties:(NSDictionary *) properties {
    NSMutableDictionary * payload = [NSMutableDictionary dictionary];
    
    if (properties != nil) {
        [payload addEntriesFromDictionary:properties];
    }
    
    payload[@"event"] = eventName;
    
    if ([[PassiveDataKit sharedInstance] mixpanelEnabled]) {
        Mixpanel * mixpanel = [Mixpanel sharedInstanceWithToken:[[NSUserDefaults standardUserDefaults] stringForKey:PDKMixpanelToken]];
        
        [mixpanel identify:[[PassiveDataKit sharedInstance] identifierForUser]];
        
        NSMutableDictionary * info = [NSMutableDictionary dictionaryWithDictionary:[[NSBundle mainBundle] infoDictionary]];
        
        if (info[@"CFBundleName"] == nil) {
            info[@"CFBundleName"] = @"Passive Data Kit";
        }
        
        if (info[@"CFBundleShortVersionString"] == nil) {
            info[@"CFBundleShortVersionString"] = @"1.0";
        }
        
        payload[@"$browser"] = info[@"CFBundleName"];
        payload[@"$browser_version"] = info[@"CFBundleShortVersionString"];

        if (mixpanel != nil) {
            [mixpanel track:eventName properties:payload];
        }
        
        [PDKMixpanelEventGenerator logForReview:payload];
    }

    [PDKEventGenerator logForReview:payload];

    return [self logDataPoint:nil generatorId:nil source:nil properties:payload];
}

- (BOOL) logDataPoint:(NSString *) generator generatorId:(NSString *) generatorId source:(NSString *) source properties:(NSDictionary *) properties {
    if (source == nil) {
        source = [[PassiveDataKit sharedInstance] identifierForUser];
    }

    if (generator == nil) {
        generator = [[PassiveDataKit sharedInstance] generator];
    }

    if (generatorId == nil) {
        generatorId = [[PassiveDataKit sharedInstance] generatorId];
    }

    NSDate * now = [NSDate date];
    
    if (properties == nil) {
        properties = @{}; //!OCLINT
    }

    sqlite3_stmt * stmt;
    
    NSString * insert = @"INSERT INTO data (source, generator, generatorId, timestamp, properties) VALUES (?, ?, ?, ?, ?);";

    if(sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [source UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 2, [generator UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 3, [generatorId UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_double(stmt, 4, now.timeIntervalSince1970);
        
        NSError * err = nil;
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:properties options:0 error:&err];
        NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
        sqlite3_bind_text(stmt, 5, [jsonString UTF8String], -1, SQLITE_TRANSIENT);

        if (SQLITE_DONE != sqlite3_step(stmt)) {
            NSLog(@"Error while inserting data. '%s'", sqlite3_errmsg(self.database));
            
            return NO;
        }
 
        sqlite3_finalize(stmt);
    }

    return YES;
}

- (void) uploadDataPoints:(NSURL *) url window:(NSTimeInterval) uploadWindow complete:(void (^)(BOOL success, int uploaded)) completed { //!OCLINT
    if (uploadWindow == 0) {
        uploadWindow = 5;
    }
    
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    
    sqlite3_stmt * statement = NULL;
    
    NSString * querySQL = @"SELECT D.id, D.source, D.generator, D.generatorId, D.timestamp, D.properties FROM data D WHERE (D.timestamp < ?) LIMIT 16";
    
    const char * query_stmt = [querySQL UTF8String];
    
    if (sqlite3_prepare_v2(self.database, query_stmt, -1, &statement, NULL) == SQLITE_OK)
    {
        sqlite3_bind_double(statement, 1, now);
        
        NSMutableArray * payload = [NSMutableArray array];
        NSMutableArray * uploaded = [NSMutableArray array];
        
        while (sqlite3_step(statement) == SQLITE_ROW)
        {
            NSInteger pointId = sqlite3_column_int(statement, 0);
            
            NSString * source = [[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(statement, 1)];
            NSString * generator = [[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(statement, 2)];
            NSString * generatorId = [[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(statement, 3)];
            NSTimeInterval timestamp = sqlite3_column_double(statement, 4);
            NSString * jsonString = [[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(statement, 5)];
            
            NSError * error = nil;
            
            NSMutableDictionary * dataPoint = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]
                                                                              options:(NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves)
                                                                                error:&error];
            if (error == nil) {
                NSMutableDictionary * metadata = [NSMutableDictionary dictionary];
                metadata[@"source"] = source;
                metadata[@"generator-id"] = generatorId;
                metadata[@"generator"] = generator;
                metadata[@"timestamp"] = [NSNumber numberWithDouble:timestamp];
                
                [uploaded addObject:[NSNumber numberWithInteger:pointId]];
                
                dataPoint[@"passive-data-metadata"] = metadata;
                
                [payload addObject:dataPoint];
            }
            else {
                completed(NO, 0);
                
                return;
            }
        }
        
        sqlite3_finalize(statement);

        NSMutableURLRequest *req = [[PDKAFJSONRequestSerializer serializer] requestWithMethod:@"CREATE"
                                                                                 URLString:[url description]
                                                                                parameters:payload
                                                                                     error:nil];
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];

        PDKAFURLSessionManager * manager = [[PDKAFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

        [[manager dataTaskWithRequest:req
                       uploadProgress:nil
                     downloadProgress:nil
                    completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                        if ([responseObject containsObject:@"Data bundle added successfully, and ready for processing."] == NO) {
                            NSLog(@"Invalid response: %@", responseObject);
                            
                            completed(NO, 0);
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
                                   NSLog(@"Error while deleting data. '%s'", sqlite3_errmsg(self.database));

                                   completed(NO, 0);
                                   
                                   return;
                               }
                           }
                           
                           completed(YES, (int) uploaded.count);
                            
                            NSTimeInterval interval = [NSDate date].timeIntervalSince1970 - now;

                            if (uploadWindow > 0 && interval > uploadWindow && uploaded.count > 0) {
                                [self uploadDataPoints:url window:(uploadWindow - interval) complete:completed];
                            }
                       } else {
                           completed(NO, 0);
                       }

                    }] resume];
    }
    else {
        completed(NO, 0);
    }
}

- (NSString *) databasePath
{
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString * cachePath = paths[0];
    
    NSString * dbPath = [cachePath stringByAppendingPathComponent:@"data.sqlite3"];
    
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
            
            const char * createStatement = "CREATE TABLE IF NOT EXISTS data (id INTEGER PRIMARY KEY AUTOINCREMENT, source TEXT, generator TEXT, generatorId TEXT, timestamp REAL, properties TEXT)";
            
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

@end
