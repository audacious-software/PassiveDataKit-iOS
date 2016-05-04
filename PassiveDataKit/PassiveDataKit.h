//
//  PassiveDataKit.h
//  PassiveDataKit
//
//  Created by Chris Karr on 5/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for PassiveDataKit.
FOUNDATION_EXPORT double PassiveDataKitVersionNumber;

//! Project version string for PassiveDataKit.
FOUNDATION_EXPORT const unsigned char PassiveDataKitVersionString[];

extern NSString *const PDKCapabilityRationale;
extern NSString *const PDKLocationSignificantChangesOnly;
extern NSString *const PDKLocationRequestedAccuracy;
extern NSString *const PDKLocationRequestedDistance;
extern NSString *const PDKLocationInstance;


typedef NS_ENUM(NSInteger, PDKDataGenerator) {
    PDKLocation
};


@protocol PDKDataListener

- (void) receivedData:(NSDictionary *) data forGenerator:(PDKDataGenerator) dataGenerator;

@end

@protocol PDKGenerator

- (void) removeListener:(id<PDKDataListener>)listener;
- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options;

@end


@interface PassiveDataKit : NSObject

+ (PassiveDataKit *) sharedInstance;

- (BOOL) registerListener:(id<PDKDataListener>) listener forGenerator:(PDKDataGenerator) dataGenerator options:(NSDictionary *) options;
- (BOOL) unregisterListener:(id<PDKDataListener>) listener forGenerator:(PDKDataGenerator) dataGenerator;

@end
