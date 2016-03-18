//
//  MRImageCacheManager.h
//  MRImageCache
//
//  Created by Rocco Del Priore on 3/16/16.
//  Copyright © 2016 Rocco Del Priore. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MRImageCacheManager : NSObject

+ (nullable instancetype)alloc	__attribute__((unavailable("Refer to sharedInstance.")));
+ (nullable instancetype)new	__attribute__((unavailable("Refer to sharedInstance."))); // Improve these warnings.
- (nullable instancetype)init	__attribute__((unavailable("Refer to sharedInstance.")));

+ (nonnull instancetype)sharedInstance;

//Settings

// these aren't thread safe right now. –-

- (void)setIdleRetainRange:(NSTimeInterval)range;

- (void)setMaximumDatabaseSize:(NSInteger)kilobytes;

//Domains

- (nonnull NSArray *)allDomains;

- (nonnull NSString *)defaultDomain;

- (nonnull NSString *)shortTermCacheDomain;

- (nonnull NSString *)longTermCacheDomain;

- (nonnull NSString *)workingCacheDomain; // Considering ruling this out.

//Add Images
/*
 Add methods will download and add an image reguardless of whether it already exists.
 If you are unsure whether an image already exists, and do not want to add a duplicate,
 please use the fetch methods.
 
 In add methods, NSURL expects a filesystem URL
*/

- (void)addImage:(UIImage *__nonnull)image uniqueIdentifier:(NSString *__nullable)identifier targetDomain:(nullable NSString *)domain completionHandler:(void (^__nonnull)(UIImage *__nullable image, NSError *__nullable error))handler;

- (void)addImage:(UIImage *__nonnull)image uniqueIdentifier:(NSString *__nullable)identifier completionHandler:(void (^__nonnull)(UIImage *__nullable image, NSError *__nullable error))handler;

- (void)addImageFromURL:(NSURL *__nonnull)url targetDomain:(NSString *__nullable)domain completionHandler:(void (^__nonnull)(UIImage *__nullable image, NSError *__nullable error))handler;

- (void)addImageFromURL:(NSURL *__nonnull)url completionHandler:(void (^__nonnull)(UIImage *__nullable image, NSError *__nullable error))handler;

//Remove Images

- (void)removeImageWithIdentifier:(NSString *__nonnull)identifier targetDomain:(NSString *__nullable)domain completionHandler:(void (^__nonnull)(UIImage *__nullable image, NSError *__nullable error))handler;

- (void)removeImageWithIdentifier:(NSString *__nonnull)identifier completionHandler:(void (^__nonnull)(UIImage *__nullable image, NSError *__nullable error))handler;

//Request Images
/*
 Fetch methods check to see if an image exists before adding and returning.
 Can pass anything as identifier. Perhaps even the URL you use to fetch it. It will be hashed.
*/

- (void)fetchImageWithRequest:(NSURLRequest *__nullable)request uniqueIdentifier:(NSString *__nullable)identifer targetDomain:(NSString *__nullable)domain completionHandler:(void (^__nonnull)(UIImage *__nullable image, NSError *__nullable error))handler;

- (void)fetchImageWithRequest:(NSURLRequest *__nullable)request uniqueIdentifier:(NSString *__nullable)identifer completionHandler:(void (^__nonnull)(UIImage *__nullable image, NSError *__nullable error))handler;

- (void)fetchImageWithUniqueIdentifier:(NSString *__nonnull)identifier targetDomain:(NSString *__nullable)domain completionHandler:(void (^__nonnull)(UIImage *__nullable image, NSError *__nullable error))handler;

- (void)fetchImageWithUniqueIdentifier:(NSString *__nonnull)identifier completionHandler:(void (^__nonnull)(UIImage *__nullable image, NSError *__nullable error))handler;

@end
