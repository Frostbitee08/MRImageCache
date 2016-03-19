//
//  RMUtilities.h
//  MRImageCache
//
//  Created by Rocco Del Priore on 3/16/16.
//  Copyright © 2016 Rocco Del Priore. All rights reserved.
//

#ifndef __MRImageCacheManager__MRUtilities__
#define __MRImageCacheManager__MRUtilities__

#import <Foundation/Foundation.h>

NSString *MRMD5HashFromString(NSString *string);
NSString *MRMD5HashFromFile(NSURL *filePath);
NSString *MRRFC2616DTimestampFromDate(NSDate *date);
NSString *MRSHA1HashFromString(NSString *string);
#endif

