//
//  PDKInstance.m
//  PassiveDataKit
//
//  Created by Chris Karr on 5/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

#import "PassiveDataKit.h"

#import "PDKDataPointsManager.h"

#import "PDKLocationGenerator.h"

@interface PassiveDataKit ()

@property NSMutableDictionary * listeners;

@end

NSString * const PDKCapabilityRationale = @"PDKCapabilityRationale";
NSString * const PDKLocationSignificantChangesOnly = @"PDKLocationSignificantChangesOnly";
NSString * const PDKLocationAlwaysOn = @"PDKLocationAlwaysOn";
NSString * const PDKLocationRequestedAccuracy = @"PDKLocationRequestedAccuracy";
NSString * const PDKLocationRequestedDistance = @"PDKLocationRequestedDistance";
NSString * const PDKLocationInstance = @"PDKLocationInstance";
NSString * const PDKUserIdentifier = @"PDKUserIdentifier";
NSString * const PDKGenerator = @"PDKGenerator";
NSString * const PDKGeneratorIdentifier = @"PDKGeneratorIdentifier";
NSString * const PDKMixpanelToken = @"PDKMixpanelToken";

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
    }
    
    return YES;
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
    switch(generator) {
        case PDKLocation:
            [[PDKLocationGenerator sharedInstance] removeListener:listener];
            break;
        default:
            break;
    }
}

- (void) incrementGenerator:(PDKDataGenerator) generator withListener:(id<PDKDataListener>) listener options:(NSDictionary *) options {
    switch(generator) {
        case PDKLocation:
            [[PDKLocationGenerator sharedInstance] addListener:listener options:options];
            break;
        default:
            break;
    }
}

+ (NSString *) keyForGenerator:(PDKDataGenerator) generator
{
    switch(generator) {
        case PDKLocation:
            return @"PDKLocationGenerator";
        default:
            break;
    }

    return @"PDKUnknownGenerator";
}

- (BOOL) logDataPoint:(NSString *) generator generatorId:(NSString *) generatorId source:(NSString *) source properties:(NSDictionary *) properties {
    return [[PDKDataPointsManager sharedInstance] logDataPoint:generator generatorId:generatorId source:source properties:properties];
}

- (BOOL) logEvent:(NSString *) eventName properties:(NSDictionary *) properties {
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

@end
