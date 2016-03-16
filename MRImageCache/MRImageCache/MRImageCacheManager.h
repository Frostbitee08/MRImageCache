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

+ (void)setIdleRetainRange:(NSTimeInterval)range;

+ (void)setMaximumDatabaseSize:(NSInteger)kilobytes;

//Modifiers

- (void)addImage:(UIImage *)image withIdentification:(NSString *)identification;

- (void)addImageFromURL:(NSURL *)url;

- (void)addImageFromURL:(NSURL *)url withIdentification:(NSString *)identification;

- (void)removeImage:(UIImage *)image;

- (void)removeImageWithIdentification:(id)identification;

//Accessors

- (UIImage *)imageWithIdentification:(id)identification;

- (UIImage *)imageWithURL:(NSURL *)url retrieveIfNecessary:(BOOL)retrieve;

@end
