//
//  MRImageCacheManager.m
//  MRImageCache
//
//  Created by Rocco Del Priore on 3/16/16.
//  Copyright © 2016 Rocco Del Priore. All rights reserved.
//

#import "MRImageCacheManager.h"

static NSInteger maximumDataBaseSize;
static NSTimeInterval idleRange;
static BOOL useMaximumDataBaseSize;
static BOOL useIdleRange;

@implementation MRImageCacheManager

#pragma mark - Class Methods

+ (void)setIdleRetainRange:(NSTimeInterval)range {
    if (range <= 0) {
        useIdleRange = false;
    }
    else {
        idleRange = range;
        //TODO: Update Database with new range
    }
}

+ (void)setMaximumDatabaseSize:(NSInteger)kilobytes {
    if (kilobytes <= 0) {
        useMaximumDataBaseSize = false;
    }
    else {
        maximumDataBaseSize = kilobytes;
        //TODO: Update Database with new maximum size
    }
}

#pragma mark - Initializers

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        useMaximumDataBaseSize = false;
        useIdleRange = false;
    });
}

#pragma mark - Modifiers

- (void)addImage:(UIImage *)image withIdentification:(NSString *)identification {
    
}

- (void)addImageFromURL:(NSURL *)url {
    
}

- (void)addImageFromURL:(NSURL *)url withIdentification:(NSString *)identification {
    
}

- (void)removeImage:(UIImage *)image {
    
}

- (void)removeImageWithIdentification:(id)identification {
    
}

#pragma mark - Accessors

- (UIImage *)imageWithIdentification:(id)identification {
    return nil;
}

- (UIImage *)imageWithURL:(NSURL *)url retrieveIfNecessary:(BOOL)retrieve {
    return nil;
}

@end
