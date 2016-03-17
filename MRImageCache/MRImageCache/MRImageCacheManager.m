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
static const float networkRequesTimeout = 30.0f;

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

- (oneway void)_changeImageIdentifierFrom:(id)from to:(id)to {
    UIImage *image = memoryMap[from];
    [memoryMap removeObjectForKey:from];
    [memoryMap setObject:image forKey:to];
    
    //TODO: Also change the identification on the filesystem
}

- (oneway UIImage *)_imageFromMemoryWithIdentification:(id)identification andUrl:(NSURL *)url {
    if (identification) {
        if ([memoryMap.allKeys containsObject:identification]) {
            return memoryMap[identification];
        }
    }
    if (url) {
        if ([memoryMap.allKeys containsObject:url.absoluteString]) {
            if (identification) {
                [self _changeImageIdentifierFrom:url.absoluteString to:identification];
                return memoryMap[identification];
            }
            
            return memoryMap[url.absoluteString];
        }
    }
    
    return nil;
}

- (void)_imageFromFilesystemWithIdentification:(id)identification andUrl:(NSURL *)url completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    NSURL *imageUrl = nil;
    if (identification) {
        if ([fileSystemMap.allKeys containsObject:identification]) {
            imageUrl = fileSystemMap[identification];
        }
    }
    if (url && imageUrl == nil) {
        if ([fileSystemMap.allKeys containsObject:url.absoluteString]) {
            imageUrl = fileSystemMap[url.absoluteString];
        }
    }
    
    NSError *error = [[NSError alloc] initWithDomain:@"domain" code:404 userInfo:nil];
    if (imageUrl == nil) handler(nil, error);
    else {
        dispatch_barrier_async(fileSystemQueue, ^{
            UIImage *image = [UIImage imageWithContentsOfFile:imageUrl.path];
            
            if (image) handler(image, nil);
            else       handler(nil, error);
        });
    }
}

#pragma mark - Modifiers

- (void)addImage:(UIImage *)image withIdentification:(NSString *)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    dispatch_barrier_async(fileSystemQueue, ^{
        
    });
}

- (void)addImageFromURL:(NSURL *)url completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:networkRequesTimeout];
    [self addImageWithRequest:request withIdentification:url.absoluteString completionHandler:handler];
}

- (void)addImageFromURL:(NSURL *)url withIdentification:(NSString *)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:networkRequesTimeout];
    [self addImageWithRequest:request withIdentification:identification completionHandler:handler];
}

- (void)addImageWithRequest:(NSURLRequest *)request withIdentification:(NSString *)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    dispatch_barrier_async(networkQueue, ^{
        NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (error) {
                handler(nil, error);
            }
            else {
                UIImage *image = [UIImage imageWithContentsOfFile:location.path];
                [self addImage:image withIdentification:identification completionHandler:handler];
            }
        }];
        
        [task resume];
    });
}

- (void)removeImage:(UIImage *)image completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    
}

- (void)removeImageWithIdentification:(id)identification completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    
}

#pragma mark - Accessors

- (void)fetchImageWithIdentification:(id)identification completionHandler:(void (^)(UIImage *, NSError *))handler {
    UIImage *image = [self _imageFromMemoryWithIdentification:identification andUrl:nil];
    
    if (image) handler(image, nil);
    else       [self _imageFromFilesystemWithIdentification:identification andUrl:nil completionHandler:handler];
}

- (void)fetchImageWithIdentification:(id)identification cacheIfNecessaryFromURL:(NSURL *)url completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    UIImage *image = [self _imageFromMemoryWithIdentification:identification andUrl:url];
    
    if (image) handler(image, nil);
    else  {
        [self _imageFromFilesystemWithIdentification:identification andUrl:nil completionHandler:^(UIImage *image, NSError *error) {
            if (image) handler(image, error);
            else       [self addImageFromURL:url withIdentification:identification completionHandler:handler];
        }];
    }
}

- (void)fetchImageWithIdentification:(id)identification cacheIfNecessaryFromRequest:(NSURLRequest *)request completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    [self fetchImageWithIdentification:identification completionHandler:^(UIImage *image, NSError *error) {
        if (image) handler(image, error);
        else       [self addImageWithRequest:request withIdentification:identification completionHandler:handler];
    }];
}

@end
