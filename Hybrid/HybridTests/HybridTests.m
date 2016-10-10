//
//  HybridTests.m
//  HybridTests
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "HyBridManager.h"
@interface HybridTests : XCTestCase

@end

@implementation HybridTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}


-(void)testHandle
{
    XCTestExpectation *exp = [self expectationWithDescription:@"a1"];
    [HyBridManager HandleWebViewURL:nil CommExcWebView:nil CommExcResult:^(NSString *jsMethodName, NSString *jsIdentify, id jsParams) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        NSLog(@"a");
    }];
    
}

-(void)testUseResult1
{
    XCTestExpectation *exp = [self expectationWithDescription:@"a2"];
    [HyBridManager StartWithLog:YES];
    [HyBridManager UseResourceWithURI:@"moduleA/logo.png" complete:^(NSData *source, NSError *error) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        NSLog(@"a");
    }];
}

-(void)testUseResult2
{
    XCTestExpectation *exp = [self expectationWithDescription:@"a3"];
    [HyBridManager StartWithLog:YES];
    [HyBridManager UseResourceWithModuleName:@"moduleA" fileName:@"57e24d21N624f138b.jpg" complete:^(NSData *source, NSError *error) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        NSLog(@"a");
    }];
}
@end
