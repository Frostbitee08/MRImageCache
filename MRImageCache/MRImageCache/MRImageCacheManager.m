//
//  MRImageCacheManager.m
//  MRImageCache
//
//  Created by Rocco Del Priore on 3/16/16.
//  Copyright © 2016 Rocco Del Priore. All rights reserved.
//

#import "MRImageCacheManager.h"
#import "MRUtilities.h"

static const char *MRFileSystemQueueTitle = "MRIFileSystemQueue";
static const char *MRNetworkQueueTitle = "MRINetworkQueue";

static const __unused float MRNetworkRequestDefaultTimeout = 30.0f;


@implementation MRImageCacheManager {
	// probably want our own NSURLSession
    dispatch_queue_t fileSystemQueue;
    dispatch_queue_t networkQueue;
	
	BOOL useIdleRange;
	NSTimeInterval idleRange;

	BOOL useMaximumDatabaseSize;
	NSInteger maximumDatabaseSize;
    
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

- (void)setIdleRetainRange:(NSTimeInterval)range {
	if (range <= 0) {
        useIdleRange = false;
    }
    else {
        idleRange = range;
        //TODO: Update Database with new range
    }
}

- (void)setMaximumDatabaseSize:(NSInteger)kilobytes {
    if (kilobytes <= 0) {
		useMaximumDatabaseSize = NO;
    }
    else {
        useMaximumDatabaseSize = kilobytes;
        //TODO: Update Database with new maximum size
    }
}

#pragma mark - Initializers

- (instancetype)init {
    self = [super init];
    if (self) {
        fileSystemQueue = dispatch_queue_create(MRFileSystemQueueTitle, 0);
        networkQueue = dispatch_queue_create(MRNetworkQueueTitle, 0);
        
        fileSystemMap = [NSMutableDictionary dictionary];
        memoryMap     = [NSMutableDictionary dictionary];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(memoryWarningReceived) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}


- (void)memoryWarningReceived {
	// Cleanup.
}

- (NSArray *)allDomains {
	// on +load/+initialize, load disk save into mem
	// return vals here
	NSArray *defaultDomains = @[
								[self shortTermCacheDomain],
								[self longTermCacheDomain],
								[self workingCacheDomain]
								];
	
	// add user defined domains here.
	
	return defaultDomains;
}

- (NSString *)defaultDomain {
	// defaultDomain should be shortTerm, longTerm, or working. Not sure which yet though.
	return [[NSBundle mainBundle] bundleIdentifier]; // should append mricXXXXXX
}

- (NSString *)shortTermCacheDomain {
	return [[NSBundle mainBundle] bundleIdentifier]; // should append mricShortTermXXXXXX
}

- (NSString *)longTermCacheDomain {
	return [[NSBundle mainBundle] bundleIdentifier]; // should append mricLongTermXXXXXX
}

- (NSString *)workingCacheDomain {
	return [[NSBundle mainBundle] bundleIdentifier]; // should append mircWorkingXXXXXX
}

#pragma mark - Helpers

- (void)_updateFileSystemMapWithURL:(NSURL *)location forIdentifier:(id)identification inTargetDomain:(NSString *)domain {
    
}

- (void)_updateMemoryMapWithImage:(UIImage *)image forIdentifier:(id)identification inTargetDomain:(NSString *)domain {
    
}

- (NSURL *)_pathForIdentifier:(id)identification inTargetDomain:(NSString *)domain {
    return nil;
}

- (oneway UIImage *)_imageFromMemoryWithIdentification:(id)identification targetDomain:(NSString *)domain {
    if (identification && [memoryMap.allKeys containsObject:domain]) {
        NSDictionary *domainMap = memoryMap[domain];
        if ([domainMap.allKeys containsObject:identification]) {
            return domainMap[identification];
        }
    }
    return nil;
}

- (oneway NSURL *)_imagePathFromFileSystemWithIdentification:(id)identification targetDomain:(NSString *)domain {
    if (identification && [fileSystemMap.allKeys containsObject:domain]) {
        NSDictionary *domainMap = fileSystemMap[domain];
        if ([domainMap.allKeys containsObject:identification]) {
            return domainMap[identification];
        }
    }
    return nil;
}

- (void)_imageFromURL:(NSURL *)url completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    NSError *error = [[NSError alloc] initWithDomain:@"domain" code:404 userInfo:nil];
    dispatch_barrier_async(fileSystemQueue, ^{
        UIImage *image = [UIImage imageWithContentsOfFile:url.path];
        
        if (image) handler(image, nil);
        else       handler(nil, error);
    });
}

//TODO: Add NSError for MRIErrorType Enum

#pragma mark - Modifiers

- (void)addImage:(UIImage *)image uniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage * image, NSError * error))handler {
	
}

- (void)addImageFromURL:(NSURL *)url targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage * image, NSError * error))handler {
	
}

- (void)removeImageWithIdentifier:(id)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage * image, NSError * error))handler {
	
}

#pragma mark - Accessors

- (void)fetchImageWithRequest:(NSURLRequest *)request uniqueIdentifier:(NSString *)identifer targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage *image, NSError *error))handler {
    //Check Memory
    UIImage *image = [self _imageFromMemoryWithIdentification:identifer targetDomain:domain];
    if (image) { handler(image, nil); return; }
    
    //Check File System
    NSURL *url = [self _imagePathFromFileSystemWithIdentification:identifer targetDomain:domain];
    if (url) { [self _imageFromURL:url completionHandler:handler]; return; }
    
    //Fetch From Remote
    dispatch_barrier_async(networkQueue, ^{
        NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (error) {
                handler(nil, error);
            }
            else {
                NSError *error = nil;
                NSURL *toLocation = [self _pathForIdentifier:identifer inTargetDomain:domain];
                
                [[NSFileManager defaultManager] removeItemAtURL:toLocation error:nil];
                if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:toLocation error:&error]) {
                    if (error) {
                        handler(nil, error);
                    }
                    else {
                        [self _updateFileSystemMapWithURL:toLocation forIdentifier:identifer inTargetDomain:domain];
                        [self _imageFromURL:toLocation completionHandler:^(UIImage *image, NSError *error) {
                            [self _updateMemoryMapWithImage:image forIdentifier:identifer inTargetDomain:domain];
                            handler(image, error);
                        }];
                    }
                }
            }
        }];
        [task resume];
    });
}

- (void)fetchImageWithUniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage *image, NSError *error))handler {
	[self fetchImageWithRequest:nil uniqueIdentifier:identifier targetDomain:domain completionHandler:handler];
}

#pragma mark - Pass Through

- (void)addImage:(UIImage *)image uniqueIdentifier:(NSString *)identifier completionHandler:(void (^)(UIImage *, NSError *))handler {
    [self addImage:image uniqueIdentifier:identifier targetDomain:nil completionHandler:handler];
}

- (void)addImageFromURL:(NSURL *)url completionHandler:(void (^)(UIImage *, NSError *))handler {
    [self addImageFromURL:url targetDomain:nil completionHandler:handler];
}

- (void)removeImageWithIdentifier:(id)identifier completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    [self removeImageWithIdentifier:identifier targetDomain:nil completionHandler:handler];
}

- (void)fetchImageWithRequest:(NSURLRequest *)request uniqueIdentifier:(NSString *)identifer completionHandler:(void (^)(UIImage *image, NSError *error))handler {
    [self fetchImageWithRequest:request uniqueIdentifier:identifer targetDomain:nil completionHandler:handler];
}

- (void)fetchImageWithUniqueIdentifier:(NSString *)identifier completionHandler:(void (^)(UIImage *, NSError *))handler {
    [self fetchImageWithUniqueIdentifier:identifier targetDomain:nil completionHandler:handler];
}

@end
