//
//  MRImageCacheManager.h
//  MRImageCache
//
//  Created by Rocco Del Priore on 3/16/16.
//  Copyright © 2016 Rocco Del Priore. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MRImageCacheManager : NSObject

//Class Methods

+ (instancetype)sharedInstance;

+ (void)setIdleRetainRange:(NSTimeInterval)range;

+ (void)setMaximumDatabaseSize:(NSInteger)kilobytes;

//Modifiers

- (BOOL)addImage:(UIImage *)image withIdentification:(NSString *)identification;

- (void)addImageFromURL:(NSURL *)url completionHandler:(void (^)(UIImage * image, NSError * error))handler;

- (void)addImageFromURL:(NSURL *)url withIdentification:(NSString *)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler;

- (BOOL)removeImage:(UIImage *)image;

- (BOOL)removeImageWithIdentification:(id)identification;

//Accessors

- (void)fetchImageWithIdentification:(id)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler;

- (void)fetchImageWithURL:(NSURL *)url retrieveIfNecessary:(BOOL)retrieve completionHandler:(void (^)(UIImage * image, NSError * error))handler;

@end
