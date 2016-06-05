//
//  PassiveDataKitTests.m
//  PassiveDataKitTests
//
//  Created by Chris Karr on 5/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

@import Foundation;

#import <XCTest/XCTest.h>

#import "PDKDataPointsManager.h"

@interface PassiveDataKitTests : XCTestCase

@end

@implementation PassiveDataKitTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testTest {
    XCTAssertTrue(YES, @"Testing is broken.");
}

- (void)testUpload {
    PDKDataPointsManager * pdk = [PDKDataPointsManager sharedInstance];
    
    BOOL result = [pdk logDataPoint:@"PDK Tester" generatorId:@"pdk-tester" source:@"tester" properties:@{ @"foo": @"bar" }];
    
    XCTAssertTrue(result, @"Didn't log data point.");

    XCTestExpectation *expectation = [self expectationWithDescription:@"Upload Complete"];

    [pdk uploadDataPoints:[NSURL URLWithString:@"http://pdk.audacious-software.com/data/add-bundle.json"] window:0 complete:^(BOOL success, int uploaded) {
        [expectation fulfill];

        XCTAssertTrue((uploaded > 0), @"Didn't upload data point.");
    }];

    [self waitForExpectationsWithTimeout:30 handler:nil];
}

@end
