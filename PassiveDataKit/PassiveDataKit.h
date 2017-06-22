//
//  PassiveDataKit.h
//  PassiveDataKit
//
//  Created by Chris Karr on 5/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

@import UIKit;

//! Project version number for PassiveDataKit.
FOUNDATION_EXPORT double PassiveDataKitVersionNumber;

//! Project version string for PassiveDataKit.
FOUNDATION_EXPORT const unsigned char PassiveDataKitVersionString[];

extern NSString *const PDKCapabilityRationale;
extern NSString *const PDKLocationSignificantChangesOnly;
extern NSString *const PDKLocationAlwaysOn;
extern NSString *const PDKLocationRequestedAccuracy;
extern NSString *const PDKLocationRequestedDistance;
extern NSString *const PDKLocationInstance;
extern NSString *const PDKLocationAccessDenied;

extern NSString *const PDKMixpanelToken;

extern NSString *const PDKGooglePlacesSpecificLocation;
extern NSString *const PDKGooglePlacesFreetextQuery;
extern NSString *const PDKGooglePlacesAPIKey;
extern NSString *const PDKGooglePlacesType;
extern NSString *const PDKGooglePlacesRadius;
extern NSString *const PDKGooglePlacesInstance;
extern NSString *const PDKGooglePlacesIncludeFullDetails;

typedef NS_ENUM(NSInteger, PDKDataGenerator) {
    PDKAnyGenerator,
    PDKLocation,
    PDKGooglePlaces,
    PDKEvents
};

@protocol PDKDataListener

- (void) receivedData:(NSDictionary *) data forGenerator:(PDKDataGenerator) dataGenerator;

@end

@protocol PDKGenerator

- (void) updateOptions:(NSDictionary *) options;
- (NSString *) generatorId;
- (NSString *) fullGeneratorName;
- (UIView *) visualizationForSize:(CGSize) size;

@end

@protocol PDKTransmitter

- (id<PDKTransmitter>) initWithOptions:(NSDictionary *) options;
- (NSUInteger) pendingSize;
- (NSUInteger) transmittedSize;
- (void) transmit:(BOOL) force completionHandler:(void (^)(UIBackgroundFetchResult result)) completionHandler;

@end


@interface PassiveDataKit : NSObject

+ (PassiveDataKit *) sharedInstance;

- (BOOL) registerListener:(id<PDKDataListener>) listener forGenerator:(PDKDataGenerator) dataGenerator;
- (BOOL) unregisterListener:(id<PDKDataListener>) listener forGenerator:(PDKDataGenerator) dataGenerator;

- (NSArray *) activeListeners;


- (void) transmit:(BOOL) force;
- (void) transmitWithCompletionHandler:(void (^)(UIBackgroundFetchResult result)) completionHandler;
- (void) clearTransmitters;

- (void) logEvent:(NSString *) eventName properties:(NSDictionary *) properties;

- (void) receivedData:(NSDictionary *) data forGenerator:(PDKDataGenerator) dataGenerator;

- (NSString *) identifierForUser;
- (BOOL) setIdentifierForUser:(NSString *) newIdentifier;
- (void) resetIdentifierForUser;

- (NSString *) userAgent;

- (id<PDKGenerator>) generatorInstance:(PDKDataGenerator) generator;

- (UIViewController *) dataReportController;
+ (NSString *) keyForGenerator:(PDKDataGenerator) generator;

- (void) addTransmitter:(id<PDKTransmitter>) transmitter;

@end
