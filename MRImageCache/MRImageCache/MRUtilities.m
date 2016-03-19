//
//  RMUtilities.m
//  MRImageCache
//
//  Created by Rocco Del Priore on 3/16/16.
//  Copyright © 2016 Rocco Del Priore. All rights reserved.
//

#import <CommonCrypto/CommonCrypto.h>

#import "MRUtilities.h"

NSString *MRMD5HashFromString(NSString *string) {
    return nil;
}

NSString *MRSHA1HashFromString(NSString *string) {
	unsigned char hashDigest[CC_SHA1_DIGEST_LENGTH];
	
	NSData *bytes = [string dataUsingEncoding:NSUTF8StringEncoding];
	
	if (!CC_SHA1([bytes bytes], (CC_LONG)[bytes length], hashDigest)) {
		// Issue calculating SHA1.
		return nil;
	}
	
	return [[NSString alloc] initWithBytes:hashDigest length:CC_SHA1_DIGEST_LENGTH encoding:NSUTF8StringEncoding];
}

NSString *MRMD5HashFromFile(NSURL *filePath) {
    return nil;
}

NSString *MRRFC2616DTimestampFromDate(NSDate *date) {
    return nil;
}