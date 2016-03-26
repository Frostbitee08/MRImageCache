//
//  MRImageCacheManager.h
//  MRImageCache
//
//  Created by Rocco Del Priore on 3/16/16.
//  Copyright © 2016 Rocco Del Priore. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString *__nonnull MRDefaultDomain;
extern NSString *__nonnull MRShortTermDomain;
extern NSString *__nonnull MRLongTermDomain;
extern NSString *__nonnull MRWorkingDomain;

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

/*
 default functions are only available for the purpose of overriding.
 overriding methods changes static vars as well.
 */

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

- (void)addImage:(UIImage *__nonnull)image uniqueIdentifier:(NSString *__nonnull)identifier targetDomain:(NSString *__nonnull)domain completionHandler:(void (^__nullable)(BOOL success, NSError *__nullable error))handler;

- (BOOL)addImageSynchronously:(UIImage *__nonnull)image uniqueIdentifier:(NSString *__nonnull)identifier targetDomain:(NSString *__nonnull)domain error:(NSError *__nullable*__nullable)error;

- (void)addImageFromURL:(NSURL *__nonnull)url targetDomain:(NSString *__nonnull)domain completionHandler:(void (^__nullable)(UIImage *__nullable image, NSError *__nullable error))handler;

- (UIImage * _Nullable)addImageFromURLSynchronously:(NSURL *__nonnull)url targetDomain:(NSString *__nonnull)domain error:(NSError *__nullable*__nullable)error;

//Remove Images

- (void)removeImageWithIdentifier:(NSString *__nonnull)identifier targetDomain:(NSString *__nonnull)domain completionHandler:(void (^__nullable)(BOOL success, NSError *__nullable error))handler;;

- (BOOL)removeImageSynchronouslyWithIdentifier:(NSString *__nonnull)identifier targetDomain:(NSString *__nonnull)domain error:(NSError *__nullable*__nullable)error;

//Move Images

- (void)moveImageWithUniqueIdentifier:(NSString *__nonnull)identifier currentDomain:(NSString *__nonnull)current targetDomain:(NSString *__nonnull)target completionHandler:(void (^__nullable)(BOOL success, NSError *__nullable error))handler;

- (BOOL)moveImageSynchronouslyWithUniqueIdentifier:(NSString *__nonnull)identifier currentDomain:(NSString *__nonnull)current targetDomain:(NSString *__nonnull)target error:(NSError *__nullable*__nullable)error;

- (void)moveAllImagesInDomain:(NSString *__nonnull)current toDomain:(NSString *__nonnull)target overwriteFilesInTarget:(BOOL)overwrite completionHandler:(void (^__nonnull)(BOOL success, NSError *__nullable error))handler;;

- (BOOL)moveAllImagesSynchronouslyInDomain:(NSString *__nonnull)current toDomain:(NSString *__nonnull)target overwriteFilesInTarget:(BOOL)overwrite error:(NSError *__nullable*__nullable)error;

//Request Images
/*
 Fetch methods check to see if an image exists before adding and returning.
 Can pass anything as identifier. Perhaps even the URL you use to fetch it. It will be hashed.
 */

- (void)fetchImageWithRequest:(NSURLRequest *__nullable)request uniqueIdentifier:(NSString *__nonnull)identifer targetDomain:(NSString *__nonnull)domain completionHandler:(void (^__nullable)(UIImage *__nullable image, NSError *__nullable error))handler;

- (UIImage * _Nullable)fetchImageSynchronouslyWithRequest:(NSURLRequest *__nullable)request uniqueIdentifier:(NSString *__nonnull)identifer targetDomain:(NSString *__nonnull)domain error:(NSError *__nullable*__nullable)error;

- (void)fetchImageWithUniqueIdentifier:(NSString *__nonnull)identifier targetDomain:(NSString *__nonnull)domain completionHandler:(void (^__nullable)(UIImage *__nullable image, NSError *__nullable error))handler;

- (UIImage * _Nullable)fetchImageSynchronouslyWithUniqueIdentifier:(NSString *__nonnull)identifier targetDomain:(NSString *__nonnull)domain error:(NSError *__nullable*__nullable)error;

@end
