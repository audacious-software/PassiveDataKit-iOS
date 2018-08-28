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
#import "PDKAppleHealthKitGenerator.h"
#import "PDKPedometerGenerator.h"
#import "PDKBatteryGenerator.h"
#import "PDKFitbitGenerator.h"
#import "PDKNokiaHealthGenerator.h"

#import "PDKDataReportViewController.h"
#import "PDKAlertsTableViewController.h"

@interface PassiveDataKit ()

@property NSMutableDictionary * listeners;
@property NSMutableArray * transmitters;
@property NSMutableArray * activeAlerts;

@property NSMutableDictionary * customGenerators;

@end

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

@implementation PDKAlert
@end

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

- (id) init {
    if (self = [super init]) {
        self.listeners = [NSMutableDictionary dictionary];
        self.transmitters = [NSMutableArray array];
        self.activeAlerts = [NSMutableArray array];
        
        self.customGenerators = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void) addTransmitter:(id<PDKTransmitter>) transmitter {
    if ([self.transmitters containsObject:transmitter] == NO) {
        [self.transmitters addObject:transmitter];
    }
}

- (BOOL) registerListener:(id<PDKDataListener>) listener forGenerator:(PDKDataGenerator) dataGenerator options:(NSDictionary *) options {
    NSString * key = [PassiveDataKit keyForGenerator:dataGenerator];
    
    NSMutableArray * dataListeners = [self.listeners valueForKey:key];
    
    if (dataListeners == nil) {
        dataListeners = [NSMutableArray array];
        
        [self.listeners setValue:dataListeners forKey:key];
        
        id<PDKGenerator> generator = [self generatorInstance:dataGenerator];
        [generator addListener:self options:options];
    }
    
    if ([dataListeners containsObject:listener] == NO) {
        [dataListeners addObject:listener];
    }

    [self.listeners setValue:dataListeners forKey:key];

    return YES;
}

- (BOOL) unregisterListener:(id<PDKDataListener>) listener forGenerator:(PDKDataGenerator) dataGenerator {
    NSString * key = [PassiveDataKit keyForGenerator:dataGenerator];

    NSMutableArray * dataListeners = [self.listeners valueForKey:key];
    
    if (dataListeners != nil) {
        [dataListeners removeObject:listener];
    
        [self.listeners setValue:dataListeners forKey:key];
    }
    
    return YES;
}

- (BOOL) registerListener:(id<PDKDataListener>) listener forCustomGenerator:(NSString *) generatorId options:(NSDictionary *) options {
    NSMutableArray * dataListeners = [self.listeners valueForKey:generatorId];
    
    if (dataListeners == nil) {
        dataListeners = [NSMutableArray array];
        
        [self.listeners setValue:dataListeners forKey:generatorId];
        
        id<PDKGenerator> generator = [self customGeneratorInstance:generatorId];
        
        if (generator != nil) {
            [generator addListener:self options:options];
        }
    }
    
    if ([dataListeners containsObject:listener] == NO) {
        [dataListeners addObject:listener];
    }
    
    [self.listeners setValue:dataListeners forKey:generatorId];
    
    return YES;
}

- (BOOL) unregisterListener:(id<PDKDataListener>) listener forCustomGenerator:(NSString *) generatorId {
    NSMutableArray * dataListeners = [self.listeners valueForKey:generatorId];
    
    if (dataListeners != nil) {
        [dataListeners removeObject:listener];
        
        [self.listeners setValue:dataListeners forKey:generatorId];
    }
    
    return YES;
}

- (id<PDKGenerator>) customGeneratorInstance:(NSString *) generatorId {
    return self.customGenerators[generatorId];
}

- (void) registerCustomGeneratorInstance:(id<PDKGenerator>) generator forId:(NSString *) generatorId {
    self.customGenerators[generatorId] = generator;
}

- (NSArray *) activeListeners {
    NSMutableArray * listeners = [NSMutableArray arrayWithArray:[self.listeners allKeys]];
    
    [listeners addObjectsFromArray:self.customGenerators.allKeys];
    
    [listeners removeObject:[PassiveDataKit keyForGenerator:PDKAnyGenerator]];
    
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

- (void) receivedData:(NSDictionary *) data forCustomGenerator:(NSString *) generatorId {
    NSMutableArray * dataListeners = [NSMutableArray arrayWithArray:[self.listeners valueForKey:generatorId]];

    NSString * anyKey = [PassiveDataKit keyForGenerator:PDKAnyGenerator];
    [dataListeners addObjectsFromArray:[self.listeners valueForKey:anyKey]];

    for (id<PDKDataListener> listener in dataListeners) {
        [listener receivedData:data forCustomGenerator:generatorId];
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
        case PDKAppleHealthKit:
            return @"PDKAppleHealthKitGenerator";
        case PDKPedometer:
            return @"PDKPedometerGenerator";
        case PDKBattery:
            return @"PDKBatteryGenerator";
        case PDKFitbit:
            return @"PDKFitbitGenerator";
        case PDKNokiaHealth:
            return @"PDKNokiaHealthGenerator";
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
        case PDKAppleHealthKit:
            return [PDKAppleHealthKitGenerator sharedInstance];
        case PDKPedometer:
            return [PDKPedometerGenerator sharedInstance];
        case PDKBattery:
            return [PDKBatteryGenerator sharedInstance];
        case PDKFitbit:
            return [PDKFitbitGenerator sharedInstance];
        case PDKNokiaHealth:
            return [PDKNokiaHealthGenerator sharedInstance];
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

- (void) transmitWithCompletionHandler:(void (^)(UIBackgroundFetchResult result)) completionHandler { //!OCLINT
    for (id<PDKTransmitter> transmitter in self.transmitters) {
        [transmitter transmit:NO completionHandler:completionHandler];
    }
}

- (void) clearTransmitters {
    [self.transmitters removeAllObjects];
}

- (NSString *) identifierForUser {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];
    
    NSString * identifier = [defaults stringForKey:PDKUserIdentifier];
    
    if (identifier != nil) {
        return identifier;
    }
    
    return [UIDevice currentDevice].identifierForVendor.UUIDString;
}

- (BOOL) setIdentifierForUser:(NSString *) newIdentifier {
    if (newIdentifier != nil) {
        NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];

        [defaults setValue:newIdentifier forKey:PDKUserIdentifier];
        
        return YES;
    }
    
    return NO;
}

- (void) resetIdentifierForUser {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];

    [defaults removeObjectForKey:PDKUserIdentifier];
}

- (NSString *) userAgent {
    NSUserDefaults * defaults = [[NSUserDefaults alloc] initWithSuiteName:@"PassiveDataKit"];

    NSString * generator = [defaults stringForKey:PDKGenerator];
    
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

- (UIViewController *) alertsController {
    return [[PDKAlertsTableViewController alloc] initWithStyle:UITableViewStylePlain];
}

- (NSArray *) alerts {
    return [NSArray arrayWithArray:self.activeAlerts];
}

- (void) cancelAlertWithTag:(NSString *) alertTag {
    PDKAlert * toDelete = nil;
    
    for (PDKAlert * alert in self.activeAlerts) {
        if ([alertTag isEqualToString:alert.alertTag]) {
            toDelete = alert;
        }
    }
    
    [self.activeAlerts removeObject:toDelete];
}

- (void) updateAlertWithTag:(NSString *) alertTag title:(NSString *) title message:(NSString *) message level:(PDKAlertLevel) level action:(void(^)(void)) action  {
    [self cancelAlertWithTag:alertTag];
    
    PDKAlert * alert = [[PDKAlert alloc] init];
    alert.alertTag = alertTag;
    alert.title = title;
    alert.message = message;
    alert.level = level;
    alert.action = action;
    
    [self.activeAlerts addObject:alert];
}

- (BOOL) application:(UIApplication *) app openURL:(NSURL *) url options:(NSDictionary<NSString *, id> *) options {
    SEL openUrl = NSSelectorFromString(@"application:openURL:options:");
    
    for (NSString * key in [self activeListeners]) {
        Class generatorClass = NSClassFromString(key);
        
        if (generatorClass == nil) {
            NSObject<PDKGenerator> * generator = (NSObject<PDKGenerator> *) [[PassiveDataKit sharedInstance] customGeneratorInstance:key];
            
            if (generator != nil) {
                generatorClass = [generator class];
            }
        }
        
        if (generatorClass != nil) {
            SEL sharedInstance = NSSelectorFromString(@"sharedInstance");
            
            if ([generatorClass respondsToSelector:sharedInstance]) {
                BOOL responded = NO;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                id instance = [generatorClass performSelector:sharedInstance];
#pragma clang diagnostic pop
                
                if ([instance respondsToSelector:openUrl]) {
                    NSInvocation * invoke = [NSInvocation invocationWithMethodSignature:[instance methodSignatureForSelector:openUrl]];

                    [invoke setSelector:openUrl];
                    [invoke setTarget:instance];
                    
                    [invoke setArgument:&(app) atIndex:2]; //arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
                    [invoke setArgument:&(url) atIndex:3]; //arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
                    [invoke setArgument:&(options) atIndex:4]; //arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation

                    [invoke setReturnValue:&(responded)];
                    
                    [invoke invoke];
                    
                    NSLog(@"PDK: HANDLE URL: %@ -- %@", url, @(responded));
                    
                    if (responded) {
                        return YES;
                    }
                }
            }
        }
    }

    NSLog(@"PDK: DID NOT HANDLE URL: %@", url);

    return NO;
}


@end
