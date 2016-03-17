//
//  MRImageCacheManager.h
//  MRImageCache
//
//  Created by Rocco Del Priore on 3/16/16.
//  Copyright © 2016 Rocco Del Priore. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MRImageCacheManager : NSObject

+ (instancetype)sharedInstance;

//Settings

+ (void)setIdleRetainRange:(NSTimeInterval)range;

+ (void)setMaximumDatabaseSize:(NSInteger)kilobytes;

//Add Images

- (void)addImage:(UIImage *)image withIdentification:(NSString *)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler;

- (void)addImageFromURL:(NSURL *)url completionHandler:(void (^)(UIImage * image, NSError * error))handler;

- (void)addImageFromURL:(NSURL *)url withIdentification:(NSString *)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler;

- (void)addImageWithRequest:(NSURLRequest *)request withIdentification:(NSString *)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler;

//Remove Images

- (void)removeImage:(UIImage *)image completionHandler:(void (^)(UIImage * image, NSError * error))handler;

- (void)removeImageWithIdentification:(id)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler;

//Request Images

- (void)fetchImageWithIdentification:(id)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler;

- (void)fetchImageWithIdentification:(id)identification cacheIfNecessaryFromURL:(NSURL *)url completionHandler:(void (^)(UIImage * image, NSError * error))handler;

- (void)fetchImageWithIdentification:(id)identification cacheIfNecessaryFromRequest:(NSURLRequest *)request completionHandler:(void (^)(UIImage * image, NSError * error))handler;

@end
