//
//  PassiveDataKit.h
//  PassiveDataKit
//
//  Created by Chris Karr on 5/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

@import UIKit;

@import AppAuth;

// #import <AppAuth/AppAuth.h>

//! Project version number for PassiveDataKit.
FOUNDATION_EXPORT double PassiveDataKitVersionNumber;

//! Project version string for PassiveDataKit.
FOUNDATION_EXPORT const unsigned char PassiveDataKitVersionString[];

extern NSString *const PDKRequestPermissions;

extern NSString *const PDKCapabilityRationale;
extern NSString *const PDKLocationSignificantChangesOnly;
extern NSString *const PDKLocationAlwaysOn;
extern NSString *const PDKLocationRequestedAccuracy;
extern NSString *const PDKLocationRequestedDistance;
extern NSString *const PDKLocationInstance;
extern NSString *const PDKLocationAccessDenied;

extern NSString *const PDKGeneratedDate;

extern NSString *const PDKMixpanelToken;

extern NSString *const PDKGooglePlacesSpecificLocation;
extern NSString *const PDKGooglePlacesFreetextQuery;
extern NSString *const PDKGooglePlacesAPIKey;
extern NSString *const PDKGooglePlacesType;
extern NSString *const PDKGooglePlacesRadius;
extern NSString *const PDKGooglePlacesInstance;
extern NSString *const PDKGooglePlacesIncludeFullDetails;

extern NSString *const PDKPedometerStart;
extern NSString *const PDKPedometerEnd;
extern NSString *const PDKPedometerStepCount;
extern NSString *const PDKPedometerDistance;
extern NSString *const PDKPedometerAveragePace;
extern NSString *const PDKPedometerCurrentPace;
extern NSString *const PDKPedometerCurrentCadence;
extern NSString *const PDKPedometerFloorsAscended;
extern NSString *const PDKPedometerFloorsDescended;
extern NSString *const PDKPedometerDailySummaryDataEnabled;

extern NSString *const PDKLocationLatitude;
extern NSString *const PDKLocationLongitude;
extern NSString *const PDKLocationAltitude;
extern NSString *const PDKLocationAccuracy;
extern NSString *const PDKLocationAltitudeAccuracy;
extern NSString *const PDKLocationFloor;
extern NSString *const PDKPedometerFloorsDescended;
extern NSString *const PDKPedometerFloorsDescended;

extern NSString *const PDKGeofencesURL;

typedef NS_ENUM(NSInteger, PDKDataGenerator) {
    PDKAnyGenerator,
    PDKLocation,
    PDKGooglePlaces,
    PDKEvents,
    PDKPedometer,
    PDKBattery,
    PDKWithings,
    PDKFitbit,
    PDKSystemStatus,
    PDKGeofences,
    PDKDarkSkyWeather,
    PDKAccelerometer,
};

@protocol PDKDataListener

- (void) receivedData:(NSDictionary *) data forGenerator:(PDKDataGenerator) dataGenerator;
- (void) receivedData:(NSDictionary *) data forCustomGenerator:(NSString *) generatorId;

@end

@protocol PDKGenerator

- (void) updateOptions:(NSDictionary *) options;
- (NSString *) generatorId;
- (NSString *) fullGeneratorName;
- (UIView *) visualizationForSize:(CGSize) size;
- (void) addListener:(id<PDKDataListener>) listener options:(NSDictionary *) options;

@end

@protocol PDKTransmitter

- (id<PDKTransmitter>) initWithOptions:(NSDictionary *) options;
- (NSUInteger) pendingSize;
- (NSUInteger) transmittedSize;
// - (void) transmitReadings;
- (void) transmitWithCompletionHandler:(void (^)(UIBackgroundFetchResult result)) completionHandler;
- (NSInteger) pendingDataPoints;
- (void) unregister;

@end

@protocol PDKStepCountGenerator

- (void) stepsBetweenStart:(NSTimeInterval) start end:(NSTimeInterval) end callback:(void (^)(NSTimeInterval start, NSTimeInterval end, CGFloat steps)) callback backfill:(BOOL) doBackfill force:(BOOL) forceRefresh;

@end

typedef NS_ENUM(NSInteger, PDKAlertLevel) {
    PDKAlertLevelError,
    PDKAlertLevelWarning,
    PDKAlertLevelOkay
};

@interface PDKAlert : NSObject

@property (nonatomic, copy) NSString * title;
@property (nonatomic, copy) NSString * message;
@property (nonatomic, copy) NSString * alertTag;
@property (nonatomic, copy) NSDate * generated;
@property (nonatomic, copy) void (^action)(void);
@property PDKAlertLevel level;

@end

@interface PassiveDataKit : NSObject<PDKDataListener>

+ (PassiveDataKit *) sharedInstance;

- (BOOL)application:(UIApplication *) app openURL:(NSURL *) url options:(NSDictionary<NSString *, id> *) options;

- (BOOL) registerListener:(id<PDKDataListener>) listener forGenerator:(PDKDataGenerator) dataGenerator options:(NSDictionary *) options;
- (BOOL) unregisterListener:(id<PDKDataListener>) listener forGenerator:(PDKDataGenerator) dataGenerator;

- (BOOL) registerListener:(id<PDKDataListener>) listener forCustomGenerator:(NSString *) generatorId options:(NSDictionary *) options;
- (BOOL) unregisterListener:(id<PDKDataListener>) listener forCustomGenerator:(NSString *) generatorId;

- (NSArray *) activeListeners;

- (void) transmitWithCompletionHandler:(void (^)(UIBackgroundFetchResult result)) completionHandler;
- (void) clearTransmitters;

- (void) logEvent:(NSString *) eventName properties:(NSDictionary *) properties;

- (void) receivedData:(NSDictionary *) data forGenerator:(PDKDataGenerator) dataGenerator;
- (void) receivedData:(NSDictionary *) data forCustomGenerator:(NSString *) generatorId;

- (NSString *) identifierForUser;
- (BOOL) setIdentifierForUser:(NSString *) newIdentifier;
- (void) resetIdentifierForUser;

- (NSString *) userAgent;

- (id<PDKGenerator>) generatorInstance:(PDKDataGenerator) generator;

- (void) registerCustomGeneratorInstance:(id<PDKGenerator>) generator forId:(NSString *) generatorId;
- (id<PDKGenerator>) customGeneratorInstance:(NSString *) generatorId;

- (UIViewController *) dataReportController;
+ (NSString *) keyForGenerator:(PDKDataGenerator) generator;

- (UIViewController *) alertsController;

- (void) addTransmitter:(id<PDKTransmitter>) transmitter;
- (void) removeTransmitter:(id<PDKTransmitter>) transmitter;

- (NSArray *) alerts;
- (void) updateAlertWithTag:(NSString *) alertTag title:(NSString *) title message:(NSString *) message level:(PDKAlertLevel) level action:(void(^)(void)) action;
- (void) cancelAlertWithTag:(NSString *) alertTag;

// - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;

- (void) clearCurrentUserFlow;
- (void) setCurrentUserFlow:(id<OIDExternalUserAgentSession>) flow;

- (void) transmitDeviceToken:(NSData *) tokenData;

- (NSDate *) appStart;

@end
