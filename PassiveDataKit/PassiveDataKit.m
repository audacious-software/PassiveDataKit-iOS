//
//  PDKInstance.m
//  PassiveDataKit
//
//  Created by Chris Karr on 5/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

#import <sys/utsname.h>

#import "PassiveDataKit.h"

#import "PDKEventsGenerator.h"
#import "PDKPedometerGenerator.h"
#import "PDKBatteryGenerator.h"
#import "PDKSystemStatusGenerator.h"
#import "PDKFitbitGenerator.h"
#import "PDKWithingsGenerator.h"
#import "PDKAccelerometerGenerator.h"

#import "PDKDataReportViewController.h"
#import "PDKAlertsTableViewController.h"

@interface PassiveDataKit ()

@property NSMutableDictionary * listeners;
@property NSMutableArray * transmitters;
@property NSMutableArray * activeAlerts;

@property NSMutableDictionary * customGenerators;

@property NSDate * startDate;

@property id<OIDExternalUserAgentSession> currentExternalUserAgentFlow;

@end

NSString * const PDKUserIdentifier = @"PDKUserIdentifier"; //!OCLINT
NSString * const PDKGenerator = @"PDKGenerator"; //!OCLINT
NSString * const PDKGeneratorIdentifier = @"PDKGeneratorIdentifier"; //!OCLINT
NSString * const PDKMixpanelToken = @"PDKMixpanelToken"; //!OCLINT
NSString * const PDKLastEventLogged = @"PDKLastEventLogged"; //!OCLINT
NSString * const PDKEventGenerator = @"PDKEventsGenerator"; //!OCLINT
NSString * const PDKMixpanelEventGenerator = @"PDKMixpanelEventGenerator"; //!OCLINT

NSString * const PDKGeneratedDate = @"PDKGeneratedDate"; //!OCLINT

NSString * const PDKRequestPermissions = @"PDKRequestPermissions"; //!OCLINT

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

        self.startDate = [NSDate date];
    }
    
    return self;
}

- (void) addTransmitter:(id<PDKTransmitter>) transmitter {
    if ([self.transmitters containsObject:transmitter] == NO) {
        [self.transmitters addObject:transmitter];
    }
}

- (void) removeTransmitter:(id<PDKTransmitter>) transmitter {
    if ([self.transmitters containsObject:transmitter]) {
        [self.transmitters removeObject:transmitter];
    }
    
    [transmitter unregister];
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
        case PDKEvents:
            return @"PDKEventsGenerator";
        case PDKPedometer:
            return @"PDKPedometerGenerator";
        case PDKBattery:
            return @"PDKBatteryGenerator";
        case PDKFitbit:
            return @"PDKFitbitGenerator";
        case PDKWithings:
            return @"PDKWithingsGenerator";
        case PDKSystemStatus:
            return @"PDKSystemStatusGenerator";
        case PDKAccelerometer:
            return @"PDKAccelerometer";
        case PDKAnyGenerator:
            return @"PDKAnyGenerator";
    }

    return @"PDKUnknownGenerator";
}

- (id<PDKGenerator>) generatorInstance:(PDKDataGenerator) generator {
    switch(generator) { //!OCLINT
        case PDKEvents:
            return [PDKEventsGenerator sharedInstance];
        case PDKPedometer:
            return [PDKPedometerGenerator sharedInstance];
        case PDKBattery:
            return [PDKBatteryGenerator sharedInstance];
        case PDKSystemStatus:
            return [PDKSystemStatusGenerator sharedInstance];
        case PDKFitbit:
            return [PDKFitbitGenerator sharedInstance];
        case PDKWithings:
            return [PDKWithingsGenerator sharedInstance];
        case PDKAccelerometer:
            return [PDKAccelerometerGenerator sharedInstance];
        case PDKAnyGenerator:
            break;
    }
    
    return nil;
}

- (void) logEvent:(NSString *) eventName properties:(NSDictionary *) properties {
    [[PDKEventsGenerator sharedInstance] logEvent:eventName properties:properties];
}

- (void) transmitWithCompletionHandler:(void (^)(UIBackgroundFetchResult result)) completionHandler {
    __block NSInteger transmitterCount = 0;
    
    __block UIBackgroundFetchResult finalResult = UIBackgroundFetchResultFailed;

    for (id<PDKTransmitter> transmitter in self.transmitters) {
        if ([transmitter pendingDataPoints] > 0) {
            transmitterCount += 1;
            
            [transmitter transmitWithCompletionHandler:^(UIBackgroundFetchResult result) {
                if (result == UIBackgroundFetchResultNewData) {
                    finalResult = UIBackgroundFetchResultNewData;
                } else if (result == UIBackgroundFetchResultNoData && finalResult == UIBackgroundFetchResultFailed) {
                    finalResult = UIBackgroundFetchResultNoData;
                }
                
                transmitterCount -= 1;
                
                if (transmitterCount == 0) {
                    switch(finalResult) {
                        case UIBackgroundFetchResultNewData:
                            NSLog(@"FINAL: NEW DATA");
                            break;
                        case UIBackgroundFetchResultNoData:
                            NSLog(@"FINAL: NO DATA");
                            break;
                        case UIBackgroundFetchResultFailed:
                            NSLog(@"FINAL: FAILED");
                            break;
                    }
                    
                    if (completionHandler != nil) {
                        completionHandler(finalResult);
                    }
                }
            }];
        }
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
    
    NSString * appAgent = [NSString stringWithFormat:@"%@/%@", info[@"CFBundleName"], info[@"CFBundleShortVersionString"], nil];

    NSString * pdkVersion = [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"CFBundleShortVersionString"];

    NSString * pdkAgent = [NSString stringWithFormat:@"Passive Data Kit/%@", pdkVersion, nil];
    
    UIDevice * device = [UIDevice currentDevice];

    struct utsname systemInfo;
    uname(&systemInfo);
    
    NSString * deviceName = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];

    NSString * iosVersion = [NSString stringWithFormat:@"(iOS %@; %@)", [device systemVersion], deviceName];
    
    return [NSString stringWithFormat:@"%@ %@ %@", appAgent, pdkAgent, iosVersion];
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
                    
                    if (responded) {
                        return YES;
                    }
                }
            }
        }
    }
    
    if (self.currentExternalUserAgentFlow != nil) {
        if ([self.currentExternalUserAgentFlow resumeExternalUserAgentFlowWithURL:url]) {
            self.currentExternalUserAgentFlow = nil;

            return YES;
        }
    }

    return NO;
}

- (void) clearCurrentUserFlow {
    self.currentExternalUserAgentFlow = nil;
}

- (void) setCurrentUserFlow:(id<OIDExternalUserAgentSession>) flow {
    self.currentExternalUserAgentFlow = flow;
}

- (void) transmitDeviceToken:(NSData *) tokenData {
    NSUInteger length = [tokenData length];
    
    NSMutableString * string = [NSMutableString stringWithCapacity:(length * 2)];
    
    const unsigned char * dataBytes = [tokenData bytes];
    
    for (NSInteger idx = 0; idx < length; ++idx) {
        [string appendFormat:@"%02x", dataBytes[idx]];
    }

    [self logEvent:@"pdk-ios-device-token" properties:@{ @"token": string}];
}

- (NSDate *) appStart {
    return self.startDate;
}

@end
