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

// these aren't thread safe right now. –-

- (void)setIdleRetainRange:(NSTimeInterval)range;

- (void)setMaximumDatabaseSize:(NSInteger)kilobytes;

//Domains

- (NSArray *)allDomains;

- (NSString *)defaultDomain;

- (NSString *)shortTermCacheDomain;

- (NSString *)longTermCacheDomain;

- (NSString *)workingCacheDomain; // Considering ruling this out.

//Add Images
/*
 Add methods will download and add an image reguardless of whether it already exists.
 If you are unsure whether an image already exists, and do not want to add a duplicate,
 please use the fetch methods.
 
 In add methods, NSURL expects a filesystem URL
*/

- (void)addImage:(UIImage *)image uniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage * image, NSError * error))handler;

- (void)addImage:(UIImage *)image uniqueIdentifier:(NSString *)identifier completionHandler:(void (^)(UIImage * image, NSError * error))handler;

- (void)addImageFromURL:(NSURL *)url targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage * image, NSError * error))handler;

- (void)addImageFromURL:(NSURL *)url completionHandler:(void (^)(UIImage * image, NSError * error))handler;

//Remove Images

- (void)removeImageWithIdentifier:(id)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage * image, NSError * error))handler;

- (void)removeImageWithIdentifier:(id)identifier completionHandler:(void (^)(UIImage * image, NSError * error))handler;

//Request Images
/*
 Fetch methods check to see if an image exists before adding and returning.
 Can pass anything as identifier. Perhaps even the URL you use to fetch it. It will be hashed.
*/

- (void)fetchImageAssetWithRequest:(NSURLRequest *)request uniqueIdentifier:(NSString *)identifer targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage *image, NSError *error))handler;

- (void)fetchImageAssetWithRequest:(NSURLRequest *)request uniqueIdentifier:(NSString *)identifer completionHandler:(void (^)(UIImage *image, NSError *error))handler;

- (void)fetchImageAssetWithUniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage *image, NSError *error))handler;

- (void)fetchImageAssetWithUniqueIdentifier:(NSString *)identifier completionHandler:(void (^)(UIImage *image, NSError *error))handler;

@end
