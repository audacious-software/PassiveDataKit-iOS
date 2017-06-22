//
//  PDKInstance.m
//  PassiveDataKit
//
//  Created by Chris Karr on 5/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

#import "PassiveDataKit.h"

#import "PDKEventsGenerator.h"
#import "PDKLocationGenerator.h"
#import "PDKGooglePlacesGenerator.h"

#import "PDKDataReportViewController.h"

@interface PassiveDataKit ()

@property NSMutableDictionary * listeners;
@property NSMutableArray * transmitters;

@end

NSString * const PDKCapabilityRationale = @"PDKCapabilityRationale"; //!OCLINT
NSString * const PDKLocationSignificantChangesOnly = @"PDKLocationSignificantChangesOnly"; //!OCLINT
NSString * const PDKLocationAlwaysOn = @"PDKLocationAlwaysOn"; //!OCLINT
NSString * const PDKLocationRequestedAccuracy = @"PDKLocationRequestedAccuracy"; //!OCLINT
NSString * const PDKLocationRequestedDistance = @"PDKLocationRequestedDistance"; //!OCLINT
NSString * const PDKLocationInstance = @"PDKLocationInstance"; //!OCLINT
NSString * const PDKLocationAccessDenied = @"PDKLocationAccessDenied"; //!OCLINT

NSString * const PDKUserIdentifier = @"PDKUserIdentifier"; //!OCLINT
NSString * const PDKGenerator = @"PDKGenerator"; //!OCLINT
NSString * const PDKGeneratorIdentifier = @"PDKGeneratorIdentifier"; //!OCLINT
NSString * const PDKMixpanelToken = @"PDKMixpanelToken"; //!OCLINT
NSString * const PDKLastEventLogged = @"PDKLastEventLogged"; //!OCLINT
NSString * const PDKEventGenerator = @"PDKEventsGenerator"; //!OCLINT
NSString * const PDKMixpanelEventGenerator = @"PDKMixpanelEventGenerator"; //!OCLINT

NSString * const PDKGooglePlacesInstance = @"PDKGooglePlacesInstance"; //!OCLINT
NSString * const PDKGooglePlacesSpecificLocation = @"PDKGooglePlacesSpecificLocation"; //!OCLINT
NSString * const PDKGooglePlacesAPIKey = @"PDKGooglePlacesAPIKey"; //!OCLINT
NSString * const PDKGooglePlacesType = @"PDKGooglePlacesType"; //!OCLINT
NSString * const PDKGooglePlacesRadius = @"PDKGooglePlacesRadius"; //!OCLINT
NSString * const PDKGooglePlacesIncludeFullDetails = @"PDKGooglePlacesIncludeFullDetails"; //!OCLINT
NSString * const PDKGooglePlacesFreetextQuery = @"PDKGooglePlacesFreetextQuery"; //!OCLINT

@implementation PassiveDataKit

static PassiveDataKit * sharedObject = nil;

+ (PassiveDataKit *) sharedInstance
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
        self.listeners = [NSMutableDictionary dictionary];
        self.transmitters = [NSMutableArray array];
    }
    
    return self;
}

- (void) addTransmitter:(id<PDKTransmitter>) transmitter {
    if ([self.transmitters containsObject:transmitter] == NO) {
        [self.transmitters addObject:transmitter];
    }
}

- (BOOL) registerListener:(id<PDKDataListener>) listener forGenerator:(PDKDataGenerator) dataGenerator {
    NSString * key = [PassiveDataKit keyForGenerator:dataGenerator];
    
    NSMutableArray * dataListeners = [self.listeners valueForKey:key];
    
    if (dataListeners == nil) {
        dataListeners = [NSMutableArray array];
        
        [self.listeners setValue:dataListeners forKey:key];
    }
    
    if ([dataListeners containsObject:listener] == NO) {
        [dataListeners addObject:listener];
    }
    
    return YES;
}

- (BOOL) unregisterListener:(id<PDKDataListener>) listener forGenerator:(PDKDataGenerator) dataGenerator {
    NSString * key = [PassiveDataKit keyForGenerator:dataGenerator];
    
    NSMutableArray * dataListeners = [self.listeners valueForKey:key];
    
    if (dataListeners != nil) {
        [dataListeners removeObject:listener];
    }
    
    return YES;
}

- (NSArray *) activeListeners {
    NSMutableArray * listeners = [NSMutableArray arrayWithArray:[self.listeners allKeys]];
    
    return listeners;
}

- (void) receivedData:(NSDictionary *) data forGenerator:(PDKDataGenerator) dataGenerator {
    NSString * key = [PassiveDataKit keyForGenerator:dataGenerator];
    NSString * anyKey = [PassiveDataKit keyForGenerator:PDKAnyGenerator];
    
    NSMutableArray * dataListeners = [NSMutableArray arrayWithArray:[self.listeners valueForKey:key]];
    
    [dataListeners addObjectsFromArray:[self.listeners valueForKey:anyKey]];

    for (id<PDKDataListener> listener in dataListeners) {
        [listener receivedData:data forGenerator:dataGenerator];
    }
}

+ (NSString *) keyForGenerator:(PDKDataGenerator) generator
{
    switch(generator) { //!OCLINT
        case PDKLocation:
            return @"PDKLocationGenerator";
        case PDKGooglePlaces:
            return @"PDKGooglePlacesGenerator";
        case PDKEvents:
            return @"PDKEventsGenerator";
        case PDKAnyGenerator:
            return @"PDKAnyGenerator";
    }

    return @"PDKUnknownGenerator";
}

- (id<PDKGenerator>) generatorInstance:(PDKDataGenerator) generator {
    switch(generator) { //!OCLINT
        case PDKLocation:
            return [PDKLocationGenerator sharedInstance];
        case PDKGooglePlaces:
            return [PDKGooglePlacesGenerator sharedInstance];
        case PDKEvents:
            return [PDKEventsGenerator sharedInstance];
        case PDKAnyGenerator:
            break;
    }
    
    return nil;
}

- (void) logEvent:(NSString *) eventName properties:(NSDictionary *) properties {
    [[PDKEventsGenerator sharedInstance] logEvent:eventName properties:properties];
}

- (void) transmit:(BOOL) force {
    for (id<PDKTransmitter> transmitter in self.transmitters) {
        [transmitter transmit:force completionHandler:nil];
    }
}

- (void) transmitWithCompletionHandler:(void (^)(UIBackgroundFetchResult result)) completionHandler {
    for (id<PDKTransmitter> transmitter in self.transmitters) {
        [transmitter transmit:NO completionHandler:completionHandler];
    }
}

- (NSString *) identifierForUser {
    NSString * identifier = [[NSUserDefaults standardUserDefaults] stringForKey:PDKUserIdentifier];
    
    if (identifier != nil) {
        return identifier;
    }
    
    return [UIDevice currentDevice].identifierForVendor.UUIDString;
}

- (BOOL) setIdentifierForUser:(NSString *) newIdentifier {
    if (newIdentifier != nil) {
        [[NSUserDefaults standardUserDefaults] setValue:newIdentifier forKey:PDKUserIdentifier];
        
        return YES;
    }
    
    return NO;
}

- (void) resetIdentifierForUser {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:PDKUserIdentifier];
}

- (NSString *) userAgent {
    NSString * generator = [[NSUserDefaults standardUserDefaults] stringForKey:PDKGenerator];
    
    if (generator != nil) {
        return generator;
    }
    
    NSMutableDictionary * info = [NSMutableDictionary dictionaryWithDictionary:[[NSBundle mainBundle] infoDictionary]];
    
    if (info[@"CFBundleName"] == nil) {
        info[@"CFBundleName"] = @"Passive Data Kit";
    }

    if (info[@"CFBundleShortVersionString"] == nil) {
        info[@"CFBundleShortVersionString"] = @"1.0";
    }
    
    return [NSString stringWithFormat:@"%@/%@", info[@"CFBundleName"], info[@"CFBundleShortVersionString"], nil];
}

- (UIViewController *) dataReportController {
    return [[PDKDataReportViewController alloc] init];
}

@end
