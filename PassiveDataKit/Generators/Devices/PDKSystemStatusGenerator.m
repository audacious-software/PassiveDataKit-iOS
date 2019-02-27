//
//  PDKSystemStatusGenerator.m
//  PassiveDataKit
//
//  Created by Chris Karr on 2/14/19.
//  Copyright © 2019 Audacious Software. All rights reserved.
//

#include <sqlite3.h>

#import "PDKSystemStatusGenerator.h"

NSString * const PDKSystemStatusRuntime = @"runtime"; //!OCLINT
NSString * const PDKSystemStatusStorageApp = @"storage_app"; //!OCLINT
NSString * const PDKSystemStatusStorageOther = @"storage_other"; //!OCLINT
NSString * const PDKSystemStatusStorageAvailable = @"storage_available"; //!OCLINT
NSString * const PDKSystemStatusStorageTotal = @"storage_total"; //!OCLINT

#define GENERATOR_ID @"pdk-system-status"

#define DATABASE_VERSION @"PDKSystemStatusGenerator.DATABASE_VERSION"
#define CURRENT_DATABASE_VERSION @(1)

@interface PDKSystemStatusGenerator()

@property NSMutableArray * listeners;
@property NSDictionary * lastOptions;

@property sqlite3 * database;

@end

static PDKSystemStatusGenerator * sharedObject = nil;

@implementation PDKSystemStatusGenerator

+ (PDKSystemStatusGenerator *) sharedInstance {
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
    }
    
    return self;
}

- (NSString *) databasePath {
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString * documentsPath = paths[0];
    
    NSString * dbPath = [documentsPath stringByAppendingPathComponent:@"pdk-system-status"];
    
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
            
            const char * createStatement = "CREATE TABLE IF NOT EXISTS system_status_data (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp REAL, runtime REAL, storage_app REAL, storage_other REAL, storage_available REAL, storage_total REAL)";
            
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
    
    [self refresh];
}

- (void) removeListener:(id<PDKDataListener>)listener {
    [self.listeners removeObject:listener];
}

+ (NSUInteger) getDirectoryFileSize:(NSURL *) directoryUrl {
    // https://stackoverflow.com/a/16658332/193812
    
    NSUInteger result = 0;
    
    NSArray * properties = @[
                             NSURLLocalizedNameKey,
                             NSURLCreationDateKey,
                             NSURLLocalizedTypeDescriptionKey
                            ];
    
    NSArray * array = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directoryUrl
                                                    includingPropertiesForKeys:properties
                                                                       options:(NSDirectoryEnumerationSkipsHiddenFiles)
                                                                         error:nil];

    for (NSURL * fileSystemItem in array) {
        BOOL directory = NO;
        
        [[NSFileManager defaultManager] fileExistsAtPath:[fileSystemItem path] isDirectory:&directory];
        
        if (!directory) {
            result += [[[[NSFileManager defaultManager] attributesOfItemAtPath:[fileSystemItem path]
                                                                         error:nil] objectForKey:NSFileSize] unsignedIntegerValue];
        } else {
            result += [PDKSystemStatusGenerator getDirectoryFileSize:fileSystemItem];
        }
    }

    return result;
}

- (void) refresh {
    NSMutableDictionary * data = [NSMutableDictionary dictionary];

    NSDictionary * spaceDetails = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];

    data[PDKSystemStatusStorageAvailable] = spaceDetails[NSFileSystemFreeSize];
    data[PDKSystemStatusStorageTotal] = spaceDetails[NSFileSystemSize];
    data[PDKSystemStatusStorageApp] = @([PDKSystemStatusGenerator getDirectoryFileSize:[NSURL fileURLWithPath:NSHomeDirectory()]]);
    data[PDKSystemStatusStorageOther] = @([data[PDKSystemStatusStorageTotal] longValue] -
                                          [data[PDKSystemStatusStorageAvailable] longValue] -
                                          [data[PDKSystemStatusStorageApp] longValue]);

    NSDate * now = [NSDate date];
    NSDate * startDate = [[PassiveDataKit sharedInstance] appStart];
    
    data[PDKSystemStatusRuntime] = @(now.timeIntervalSince1970 - startDate.timeIntervalSince1970);

    sqlite3_stmt * stmt;

    NSString * insert = @"INSERT INTO system_status_data (timestamp, runtime, storage_app, storage_other, storage_available, storage_total) VALUES (?, ?, ?, ?, ?, ?);";
    
    int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL);
    
    if (retVal == SQLITE_OK) {
        if (sqlite3_bind_double(stmt, 1, now.timeIntervalSince1970) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 2, [data[PDKSystemStatusRuntime] doubleValue]) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 3, [data[PDKSystemStatusStorageApp] doubleValue]) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 4, [data[PDKSystemStatusStorageOther] doubleValue]) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 5, [data[PDKSystemStatusStorageAvailable] doubleValue]) == SQLITE_OK &&
            sqlite3_bind_double(stmt, 6, [data[PDKSystemStatusStorageTotal] doubleValue]) == SQLITE_OK) {
            
            int retVal = sqlite3_step(stmt);
            
            if (SQLITE_DONE != retVal) {
                NSLog(@"Error while inserting data. %d '%s'", retVal, sqlite3_errmsg(self.database));
            }
        }
        
        sqlite3_finalize(stmt);
    }

    // NSLog(@"STATUS DATA: %@", data);

    [[PassiveDataKit sharedInstance] receivedData:data forGenerator:PDKSystemStatus];
}

- (NSString *) generatorId {
    return GENERATOR_ID;
}

+ (NSString *) title {
    return NSLocalizedStringFromTableInBundle(@"name_generator_system_status", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
}

@end
