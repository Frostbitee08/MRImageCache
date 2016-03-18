//
//  MRImageCacheTests.m
//  MRImageCacheTests
//
//  Created by Rocco Del Priore on 3/16/16.
//  Copyright © 2016 Rocco Del Priore. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <MRImageCache/MRImageCache.h>

@interface MRImageCacheTests : XCTestCase

@end

@implementation MRImageCacheTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
	
	[self testAccessors];
	
	[self testModifiers];
	
	[self testConvenienceMethods];
	
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testAccessors {
	// TODO: put tests here.
}

- (void)testModifiers {
	// TODO: put tests here.
}

- (void)testConvenienceMethods {
	
	// These methods may do something in the future. Not entirely terrible to test them.
	
	MRImageCacheManager *cacher = [MRImageCacheManager sharedInstance];
	
	[cacher addImage:[UIImage new] uniqueIdentifier:nil completionHandler:^(UIImage * _Nullable image, NSError * _Nullable error) {
		
	}];
	
	[cacher addImageFromURL:[NSURL new] completionHandler:^(UIImage * _Nullable image, NSError * _Nullable error) {
		
	}];
	
	[cacher removeImageWithIdentifier:[NSString new] completionHandler:^(UIImage * _Nullable image, NSError * _Nullable error) {
		
	}];
	
	[cacher fetchImageWithRequest:nil uniqueIdentifier:nil completionHandler:^(UIImage * _Nullable image, NSError * _Nullable error) {
		
	}];
	
	[cacher fetchImageWithUniqueIdentifier:[NSString new] completionHandler:^(UIImage * _Nullable image, NSError * _Nullable error) {
		
	}];
	
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
