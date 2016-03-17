//
//  MRImageCacheManager.m
//  MRImageCache
//
//  Created by Rocco Del Priore on 3/16/16.
//  Copyright © 2016 Rocco Del Priore. All rights reserved.
//

#import "MRImageCacheManager.h"
#import "MRUtilities.h"

static const char *fileSystemQueueTitle = "fs";
static const char *networkQueueTitle = "nw";

static NSInteger maximumDataBaseSize;
static NSTimeInterval idleRange;
static BOOL useMaximumDataBaseSize;
static BOOL useIdleRange;

@implementation MRImageCacheManager {
    dispatch_queue_t fileSystemQueue;
    dispatch_queue_t networkQueue;
    
    NSMutableDictionary *fileSystemMap;
    NSMutableDictionary *memoryMap;
}

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

- (instancetype)init {
    self = [super init];
    if (self) {
        fileSystemQueue = dispatch_queue_create(fileSystemQueueTitle, 0);
        networkQueue = dispatch_queue_create(networkQueueTitle, 0);
        
        fileSystemMap = [NSMutableDictionary dictionary];
        memoryMap     = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Helpers

- (oneway UIImage *)_imageFromMemoryWithIdentification:(id)identification andUrl:(NSURL *)url {
    if (identification) {
        if ([memoryMap.allKeys containsObject:identification]) {
            return memoryMap[identification];
        }
    }
    if (url) {
        if ([memoryMap.allKeys containsObject:url.absoluteString]) {
            if (identification) {
                UIImage *image = memoryMap[url.absoluteString];
                [memoryMap removeObjectForKey:url.absoluteString];
                [memoryMap setObject:image forKey:identification];
                return memoryMap[identification];
            }
            
            return memoryMap[url.absoluteString];
        }
    }
    
    return nil;
}

- (oneway UIImage *)_imageFromFilesystemWithIdentification:(id)identification andUrl:(NSURL *)url {
    return nil;
}

- (oneway UIImage *)_localImageWithIdentification:(id)identification andUrl:(NSURL *)url {
    UIImage *memoryImage = [self _imageFromMemoryWithIdentification:identification andUrl:url];
    if (memoryImage) return memoryImage;
    
    UIImage *filesystemImage = [self _imageFromFilesystemWithIdentification:identification andUrl:url];
    if (filesystemImage) return filesystemImage;
    
    return nil;
}

#pragma mark - Modifiers

- (void)addImage:(UIImage *)image withIdentification:(NSString *)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    
}

- (void)addImageFromURL:(NSURL *)url completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    
}

- (void)addImageFromURL:(NSURL *)url withIdentification:(NSString *)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    
}

- (void)addImageWithRequest:(NSURLRequest *)request withIdentification:(NSString *)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    
}

- (void)removeImage:(UIImage *)image completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    
}

- (void)removeImageWithIdentification:(id)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    
}

#pragma mark - Accessors

- (void)fetchImageWithIdentification:(id)identification completionHandler:(void (^)(UIImage *, NSError *))handler {
    UIImage *image = [self _localImageWithIdentification:identification andUrl:nil];
    NSError *error = [[NSError alloc] initWithDomain:@"domain" code:404 userInfo:nil];
    
    if (image) handler(image, nil);
    else       handler(nil, error);
}

- (void)fetchImageWithIdentification:(id)identification cacheIfNecessaryFromURL:(NSURL *)url completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    UIImage *image = [self _localImageWithIdentification:identification andUrl:url];
    
    if (image) handler(image, nil);
    else       [self addImageFromURL:url withIdentification:identification completionHandler:handler];
}

- (void)fetchImageWithIdentification:(id)identification cacheIfNecessaryFromRequest:(NSURLRequest *)request completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    UIImage *image = [self _localImageWithIdentification:identification andUrl:nil];
    
    if (image) handler(image, nil);
    else       [self addImageWithRequest:request withIdentification:identification completionHandler:handler];
}

- (void)fetchImageWithURL:(NSURL *)url cacheIfNecessary:(BOOL)retrieve completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    UIImage *image = [self _localImageWithIdentification:nil andUrl:url];
    NSError *error = [[NSError alloc] initWithDomain:@"domain" code:404 userInfo:nil];
    
    if (image)         handler(image, nil);
    else if (retrieve) [self addImageFromURL:url completionHandler:handler];
    else               handler(nil, error);
}

@end
