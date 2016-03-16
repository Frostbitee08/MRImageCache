//
//  MRImageCacheManager.m
//  MRImageCache
//
//  Created by Rocco Del Priore on 3/16/16.
//  Copyright © 2016 Rocco Del Priore. All rights reserved.
//

#import "MRImageCacheManager.h"
#import "MRUtilities.h"

static NSInteger maximumDataBaseSize;
static NSTimeInterval idleRange;
static BOOL useMaximumDataBaseSize;
static BOOL useIdleRange;

@implementation MRImageCacheManager

#pragma mark - Class Methods

+ (instancetype)sharedInstance {
    static id _instance = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

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

- (BOOL)addImage:(UIImage *)image withIdentification:(NSString *)identification {
    return false;
}

- (void)addImageFromURL:(NSURL *)url completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    
}

- (void)addImageFromURL:(NSURL *)url withIdentification:(NSString *)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    
}

- (BOOL)removeImage:(UIImage *)image {
    return false;
}

- (BOOL)removeImageWithIdentification:(id)identification {
    return false;
}

#pragma mark - Accessors

- (UIImage *)imageWithIdentification:(id)identification {
    return nil;
}

- (void)fetchImageWithURL:(NSURL *)url retrieveIfNecessary:(BOOL)retrieve completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    
}

@end
