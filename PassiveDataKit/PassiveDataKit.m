//
//  PDKInstance.m
//  PassiveDataKit
//
//  Created by Chris Karr on 5/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

#import "PassiveDataKit.h"

#import "PDKDataPointsManager.h"

#import "PDKEventsGenerator.h"
#import "PDKLocationGenerator.h"
#import "PDKGooglePlacesGenerator.h"

#import "PDKDataReportViewController.h"

@interface PassiveDataKit ()

@property NSMutableDictionary * listeners;

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
    }
    
    return self;
}

- (BOOL) registerListener:(id<PDKDataListener>) listener forGenerator:(PDKDataGenerator) dataGenerator options:(NSDictionary *) options {
    NSString * key = [PassiveDataKit keyForGenerator:dataGenerator];
    
    NSMutableArray * dataListeners = [self.listeners valueForKey:key];
    
    if (dataListeners == nil) {
        dataListeners = [NSMutableArray array];
        
        [self.listeners setValue:dataListeners forKey:key];
    }
    
    if ([dataListeners containsObject:listener] == NO) {
        [dataListeners addObject:listener];
        
        [self incrementGenerator:dataGenerator withListener:listener options:options];
    } else {
        [self updateGenerator:dataGenerator withOptions:options];
    }
    
    return YES;
}

- (NSArray *) activeListeners {
    NSMutableArray * listeners = [NSMutableArray arrayWithArray:[self.listeners allKeys]];
    
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults valueForKey:PDKLastEventLogged] != nil) {
        [listeners addObject:PDKEventGenerator];
        
        if ([self mixpanelEnabled]) {
            [listeners addObject:PDKMixpanelEventGenerator];
        }
    }
    
    return listeners;
}

- (BOOL) unregisterListener:(id<PDKDataListener>) listener forGenerator:(PDKDataGenerator) dataGenerator {
    NSString * key = [PassiveDataKit keyForGenerator:dataGenerator];
    
    NSMutableArray * dataListeners = [self.listeners valueForKey:key];
    
    if (dataListeners != nil) {
        [dataListeners removeObject:listener];
        
        [self decrementGenerator:dataGenerator withListener:listener];
    }
    
    return YES;
}

- (void) decrementGenerator:(PDKDataGenerator) generator withListener:(id<PDKDataListener>) listener {
    switch(generator) { //!OCLINT
        case PDKLocation:
            [[PDKLocationGenerator sharedInstance] removeListener:listener];
            break;
        case PDKGooglePlaces:
            [[PDKGooglePlacesGenerator sharedInstance] removeListener:listener];
            break;
    }
}

- (void) incrementGenerator:(PDKDataGenerator) generator withListener:(id<PDKDataListener>) listener options:(NSDictionary *) options {
    switch(generator) { //!OCLINT
        case PDKLocation:
            [[PDKLocationGenerator sharedInstance] addListener:listener options:options];
            break;
        case PDKGooglePlaces:
            [[PDKGooglePlacesGenerator sharedInstance] addListener:listener options:options];
            break;
    }
}

- (void) updateGenerator:(PDKDataGenerator) generator withOptions:(NSDictionary *) options {
    switch(generator) { //!OCLINT
        case PDKLocation:
            [[PDKLocationGenerator sharedInstance] updateOptions:options];

            break;
        case PDKGooglePlaces:
            [[PDKGooglePlacesGenerator sharedInstance] updateOptions:options];
            break;
    }
}


+ (NSString *) keyForGenerator:(PDKDataGenerator) generator
{
    switch(generator) { //!OCLINT
        case PDKLocation:
            return @"PDKLocationGenerator";
        case PDKGooglePlaces:
            return @"PDKGooglePlacesGenerator";
    }

    return @"PDKUnknownGenerator";
}

- (void) setMandatoryEventLogging:(BOOL) isMandatory {
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:(isMandatory == NO)   forKey:PDKEventsGeneratorCanDisable];
    
    [defaults synchronize];
}


- (BOOL) logDataPoint:(NSString *) generator generatorId:(NSString *) generatorId source:(NSString *) source properties:(NSDictionary *) properties {
    return [[PDKDataPointsManager sharedInstance] logDataPoint:generator generatorId:generatorId source:source properties:properties];
}

- (BOOL) logEvent:(NSString *) eventName properties:(NSDictionary *) properties {
    NSUserDefaults * defaults= [NSUserDefaults standardUserDefaults];
    
    [defaults setValue:[NSDate date] forKey:PDKLastEventLogged];
    [defaults synchronize];
    
    return [[PDKDataPointsManager sharedInstance] logEvent:eventName properties:properties];
}

- (void) uploadDataPoints:(NSURL *) url window:(NSTimeInterval) uploadWindow complete:(void (^)(BOOL success, int uploaded)) completed {
    [[PDKDataPointsManager sharedInstance] uploadDataPoints:url window:uploadWindow complete:completed];
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

- (NSString *) generator {
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
    
    NSOperatingSystemVersion osVer = [NSProcessInfo processInfo].operatingSystemVersion;
    
    NSString * version = [NSString stringWithFormat:@"%d.%d.%d", (int) osVer.majorVersion, (int) osVer.minorVersion, (int) osVer.patchVersion];

    return [NSString stringWithFormat:@"%@ %@ (iOS %@)", info[@"CFBundleName"], info[@"CFBundleShortVersionString"], version, nil];
}

- (BOOL) setGenerator:(NSString *) newGenerator {
    if (newGenerator != nil) {
        [[NSUserDefaults standardUserDefaults] setValue:newGenerator forKey:PDKGenerator];
        
        return YES;
    }
    
    return NO;
}

- (void) resetGenerator {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:PDKGenerator];
}

- (NSString *) generatorId {
    NSString * identifier = [[NSUserDefaults standardUserDefaults] stringForKey:PDKGeneratorIdentifier];
    
    if (identifier != nil) {
        return identifier;
    }
    
    if ([[NSBundle mainBundle] bundleIdentifier] != nil) {
        return [[NSBundle mainBundle] bundleIdentifier];
    }
    
    return @"passive-data-kit";
}

- (BOOL) setGeneratorId:(NSString *) newIdentifier
{
    if (newIdentifier != nil) {
        [[NSUserDefaults standardUserDefaults] setValue:newIdentifier forKey:PDKGeneratorIdentifier];
        
        return YES;
    }
    
    return NO;
}

- (void) resetGeneratorId {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:PDKGeneratorIdentifier];
}

- (BOOL) mixpanelEnabled {
    return [[NSUserDefaults standardUserDefaults] stringForKey:PDKMixpanelToken] != nil;
}

- (void) enableMixpanel:(NSString *) token {
    [[NSUserDefaults standardUserDefaults] setValue:token forKey:PDKMixpanelToken];
}

- (void) disableMixpanel {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:PDKMixpanelToken];
}

- (UIViewController *) dataReportController {
    return [[PDKDataReportViewController alloc] init];
}

@end
