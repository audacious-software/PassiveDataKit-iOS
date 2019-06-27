//
//  PDKDarkSkyWeatherGenerator.m
//  PassiveDataKit
//
//  Created by Chris Karr on 6/27/19.
//  Copyright © 2019 Audacious Software. All rights reserved.
//

#include <sqlite3.h>

@import AFNetworking;

#import "PDKDarkSkyWeatherGenerator.h"
#import "PDKLocationGenerator.h"

#define DATABASE_VERSION @"PDKFitbitGenerator.DATABASE_VERSION"
#define CURRENT_DATABASE_VERSION @(1)
#define GENERATOR_ID @"pdk-dark-sky-weather"

#define DARK_SKY_UPDATE_INTERVAL 5 * 60

NSString * const PDKDarkSkyAPIKey = @"PDKDarkSkyAPIKey"; //!OCLINT

NSString * const PDKDarkSkyObserved = @"observed"; //!OCLINT
NSString * const PDKDarkSkyLatitude = @"latitude"; //!OCLINT
NSString * const PDKDarkSkyLongitude = @"longitude"; //!OCLINT
NSString * const PDKDarkSkyTimeZone = @"timezone"; //!OCLINT
NSString * const PDKDarkSkySummary = @"summary"; //!OCLINT
NSString * const PDKDarkSkyTemperature = @"temperature"; //!OCLINT
NSString * const PDKDarkSkyOzone = @"observed"; //!OCLINT
NSString * const PDKDarkSkyApparentTemperature = @"apparent_temperature"; //!OCLINT
NSString * const PDKDarkSkyHumidity = @"humidity"; //!OCLINT
NSString * const PDKDarkSkyDewPoint = @"dew_point"; //!OCLINT
NSString * const PDKDarkSkyWindSpeed = @"wind_speed"; //!OCLINT
NSString * const PDKDarkSkyWindGustSpeed = @"wind_gust_speed"; //!OCLINT
NSString * const PDKDarkSkyWindBearing = @"wind_bearing"; //!OCLINT
NSString * const PDKDarkSkyCloudCover = @"cloud_cover"; //!OCLINT
NSString * const PDKDarkSkyUVIndex = @"uv_index"; //!OCLINT
NSString * const PDKDarkSkyAirPresure = @"air_pressure"; //!OCLINT
NSString * const PDKDarkSkyVisibility = @"visibility"; //!OCLINT
NSString * const PDKDarkSkyPrecipitationIntensity = @"precipitation_intensity"; //!OCLINT
NSString * const PDKDarkSkyPrecipitationProbability = @"precipitation_probability"; //!OCLINT
NSString * const PDKDarkSkyFullReading = @"full_reading"; //!OCLINT

@interface PDKDarkSkyWeatherGenerator()

@property NSDictionary * options;

@property sqlite3 * database;

@property NSMutableArray * listeners;
@property NSTimeInterval lastUpdated;

@end

static PDKDarkSkyWeatherGenerator * sharedObject = nil;

@implementation PDKDarkSkyWeatherGenerator

+ (PDKDarkSkyWeatherGenerator *) sharedInstance {
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
        
        self.lastUpdated = 0;
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
    return NSLocalizedStringFromTableInBundle(@"name_generator_dark_sky_weather", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
}


- (void) refresh {
    long now = (long) [NSDate date].timeIntervalSince1970;
    
    if (now - self.lastUpdated > DARK_SKY_UPDATE_INTERVAL) {
        self.lastUpdated = now;

        AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    
        CLLocation * location = [[PDKLocationGenerator sharedInstance] lastKnownLocation];
        
        if (location != nil) {
            
            NSString * urlString = [NSString stringWithFormat:@"https://api.darksky.net/forecast/%@/%f,%f,%ld?units=si&exclude=minutely,hourly,daily", self.options[PDKDarkSkyAPIKey], (double) location.coordinate.latitude, (double) location.coordinate.longitude, now];
            
            NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
            
            NSURLSessionDataTask * task = [manager dataTaskWithRequest:request
                                                        uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                                                            
                                                        } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                                            
                                                        } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                            if (error != nil) {
                                                                
                                                            } else {
                                                                sqlite3_stmt * stmt;
                                                                
                                                                NSString * insert = @"INSERT INTO dark_sky_weather_history (observed, latitude, longitude, timezone, summary, temperature, apparent_temperature, ozone, humidity, dew_point, wind_speed, wind_gust_speed, wind_bearing, cloud_cover, uv_index, air_pressure, visibility, precipitation_intensity, precipitation_probability, full_reading) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";
                                                                
                                                                int retVal = sqlite3_prepare_v2(self.database, [insert UTF8String], -1, &stmt, NULL);
                                                                
                                                                NSMutableDictionary * data = [NSMutableDictionary dictionary];
                                                                
                                                                if (retVal == SQLITE_OK) {
                                                                    sqlite3_bind_int64(stmt, 1, now);
                                                                    
                                                                    if ([responseObject valueForKey:@"latitude"] != nil) {
                                                                        sqlite3_bind_double(stmt, 2, [[responseObject valueForKey:@"latitude"] doubleValue]);
                                                                        data[PDKDarkSkyLatitude] = [responseObject valueForKey:@"latitude"];
                                                                    } else {
                                                                        sqlite3_bind_null(stmt, 2);
                                                                    }
                                                                    
                                                                    if ([responseObject valueForKey:@"longitude"] != nil) {
                                                                        sqlite3_bind_double(stmt, 3, [[responseObject valueForKey:@"longitude"] doubleValue]);
                                                                        data[PDKDarkSkyLongitude] = [responseObject valueForKey:@"longitude"];
                                                                    } else {
                                                                        sqlite3_bind_null(stmt, 3);
                                                                    }
                                                                    
                                                                    if ([responseObject valueForKey:@"timezone"] != nil) {
                                                                        sqlite3_bind_text(stmt, 4, [[responseObject valueForKey:@"timezone"] cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT);
                                                                        data[PDKDarkSkyTimeZone] = [responseObject valueForKey:@"timezone"];
                                                                    } else {
                                                                        sqlite3_bind_null(stmt, 4);
                                                                    }
                                                                    
                                                                    NSDictionary * currently = [responseObject valueForKey:@"currently"];
                                                                    
                                                                    if (currently != nil) {
                                                                        if (currently[@"summary"] != nil) {
                                                                            sqlite3_bind_text(stmt, 5, [currently[@"summary"] cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT);
                                                                            data[PDKDarkSkySummary] = currently[@"summary"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 5);
                                                                        }
                                                                        
                                                                        if (currently[@"temperature"] != nil) {
                                                                            sqlite3_bind_double(stmt, 6, [currently[@"temperature"] doubleValue]);
                                                                            
                                                                            data[PDKDarkSkyTemperature] = currently[@"temperature"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 6);
                                                                        }
                                                                        
                                                                        if (currently[@"apparentTemperature"] != nil) {
                                                                            sqlite3_bind_double(stmt, 7, [currently[@"apparentTemperature"] doubleValue]);
                                                                            
                                                                            data[PDKDarkSkyApparentTemperature] = currently[@"apparentTemperature"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 7);
                                                                        }
                                                                        
                                                                        if (currently[@"ozone"] != nil) {
                                                                            sqlite3_bind_double(stmt, 8, [currently[@"ozone"] doubleValue]);
                                                                            
                                                                            data[PDKDarkSkyOzone] = currently[@"ozone"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 8);
                                                                        }
                                                                        
                                                                        if (currently[@"humidity"] != nil) {
                                                                            sqlite3_bind_double(stmt, 9, [currently[@"humidity"] doubleValue]);
                                                                            
                                                                            data[PDKDarkSkyHumidity] = currently[@"humidity"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 9);
                                                                        }
                                                                        
                                                                        if (currently[@"dewPoint"] != nil) {
                                                                            sqlite3_bind_double(stmt, 10, [currently[@"dewPoint"] doubleValue]);
                                                                            
                                                                            data[PDKDarkSkyDewPoint] = currently[@"dewPoint"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 10);
                                                                        }
                                                                        
                                                                        if (currently[@"windSpeed"] != nil) {
                                                                            sqlite3_bind_double(stmt, 11, [currently[@"windSpeed"] doubleValue]);
                                                                            
                                                                            data[PDKDarkSkyWindSpeed] = currently[@"windSpeed"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 11);
                                                                        }
                                                                        
                                                                        if (currently[@"windGust"] != nil) {
                                                                            sqlite3_bind_double(stmt, 12, [currently[@"windGust"] doubleValue]);
                                                                            
                                                                            data[PDKDarkSkyWindGustSpeed] = currently[@"windGust"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 12);
                                                                        }
                                                                        
                                                                        if (currently[@"windBearing"] != nil) {
                                                                            sqlite3_bind_double(stmt, 13, [currently[@"windBearing"] doubleValue]);
                                                                            
                                                                            data[PDKDarkSkyWindBearing] = currently[@"windBearing"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 13);
                                                                        }
                                                                        
                                                                        if (currently[@"cloudCover"] != nil) {
                                                                            sqlite3_bind_double(stmt, 14, [currently[@"cloudCover"] doubleValue]);
                                                                            
                                                                            data[PDKDarkSkyCloudCover] = currently[@"cloudCover"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 14);
                                                                        }
                                                                        
                                                                        if (currently[@"uvIndex"] != nil) {
                                                                            sqlite3_bind_double(stmt, 15, [currently[@"uvIndex"] doubleValue]);
                                                                            
                                                                            data[PDKDarkSkyUVIndex] = currently[@"uvIndex"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 15);
                                                                        }
                                                                        
                                                                        if (currently[@"pressure"] != nil) {
                                                                            sqlite3_bind_double(stmt, 16, [currently[@"pressure"] doubleValue]);
                                                                            
                                                                            data[PDKDarkSkyAirPresure] = currently[@"pressure"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 16);
                                                                        }
                                                                        
                                                                        if (currently[@"visibility"] != nil) {
                                                                            sqlite3_bind_double(stmt, 17, [currently[@"visibility"] doubleValue]);
                                                                            
                                                                            data[PDKDarkSkyVisibility] = currently[@"visibility"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 17);
                                                                        }
                                                                        
                                                                        if (currently[@"precipIntensity"] != nil) {
                                                                            sqlite3_bind_double(stmt, 18, [currently[@"precipIntensity"] doubleValue]);
                                                                            
                                                                            data[PDKDarkSkyPrecipitationIntensity] = currently[@"precipIntensity"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 18);
                                                                        }
                                                                        
                                                                        if (currently[@"precipProbability"] != nil) {
                                                                            sqlite3_bind_double(stmt, 19, [currently[@"precipProbability"] doubleValue]);
                                                                            
                                                                            data[PDKDarkSkyPrecipitationProbability] = currently[@"precipProbability"];
                                                                        } else {
                                                                            sqlite3_bind_null(stmt, 19);
                                                                        }
                                                                        
                                                                        NSError * error = nil;
                                                                        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:responseObject
                                                                                                                            options:NSJSONWritingPrettyPrinted
                                                                                                                              error:&error];
                                                                        
                                                                        if (jsonData == nil) {
                                                                            NSLog(@"Got an error: %@", error);
                                                                        } else {
                                                                            NSString * jsonString = [[NSString alloc] initWithData:jsonData
                                                                                                                          encoding:NSUTF8StringEncoding];
                                                                            
                                                                            sqlite3_bind_text(stmt, 20, [jsonString cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT);
                                                                            
                                                                            data[PDKDarkSkyFullReading] = jsonString;
                                                                        }
                                                                        
                                                                        int retVal = sqlite3_step(stmt);
                                                                        
                                                                        if (SQLITE_DONE != retVal) {
                                                                            NSLog(@"Error while inserting data. %d '%s'", retVal, sqlite3_errmsg(self.database));
                                                                        }
                                                                        
                                                                        [[PassiveDataKit sharedInstance] receivedData:data forGenerator:PDKDarkSkyWeather];
                                                                    }
                                                                }
                                                                
                                                                sqlite3_finalize(stmt);
                                                            }
                                                        }];
            [task resume];
        }
    }
}

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options {
    if ([self.listeners containsObject:listener] == NO) {
        [self.listeners addObject:listener];
    }
}

- (void) removeListener:(id<PDKDataListener>)listener {
    [self.listeners removeObject:listener];
}

- (NSString *) databasePath {
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString * documentsPath = paths[0];
    
    NSString * dbPath = [documentsPath stringByAppendingPathComponent:@"pdk-dark-sky-weather.sqlite3"];
    
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
            
            const char * createStatement = "CREATE TABLE dark_sky_weather_history(_id INTEGER PRIMARY KEY AUTOINCREMENT, fetched INTEGER, transmitted INTEGER, observed INTEGER, latitude REAL, longitude REAL, timezone TEXT, summary TEXT, temperature REAL, apparent_temperature REAL, ozone REAL, humidity REAL, dew_point REAL, wind_speed REAL, wind_gust_speed REAL, wind_bearing REAL, cloud_cover REAL, uv_index REAL, air_pressure REAL, visibility REAL, precipitation_intensity REAL, precipitation_probability REAL, full_reading TEXT);";
            
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

- (NSString *) generatorId {
    return GENERATOR_ID;
}

@end
