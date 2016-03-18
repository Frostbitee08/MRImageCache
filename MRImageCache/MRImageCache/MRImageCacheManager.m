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

- (void)_changeImageIdentifierFrom:(id)from to:(id)to {
	// not thread safe. 
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

//TODO: Add NSError for MRIErrorType Enum

#pragma mark - Modifiers

- (void)addImage:(UIImage *)image uniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage * image, NSError * error))handler {
	
}

- (void)addImageFromURL:(NSURL *)url targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage * image, NSError * error))handler {
	
}

- (void)removeImageWithIdentifier:(id)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage * image, NSError * error))handler {
	
}

#pragma mark - Accessors

- (void)fetchImageAssetWithRequest:(NSURLRequest *)request uniqueIdentifier:(NSString *)identifer targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage *image, NSError *error))handler {
	//
}

- (void)fetchImageAssetWithUniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage *image, NSError *error))handler {
	[self fetchImageAssetWithRequest:nil uniqueIdentifier:identifier targetDomain:domain completionHandler:handler];
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

- (void)fetchImageAssetWithRequest:(NSURLRequest *)request uniqueIdentifier:(NSString *)identifer completionHandler:(void (^)(UIImage *image, NSError *error))handler {
    [self fetchImageAssetWithRequest:request uniqueIdentifier:identifer targetDomain:nil completionHandler:handler];
}

- (void)fetchImageAssetWithUniqueIdentifier:(NSString *)identifier completionHandler:(void (^)(UIImage *, NSError *))handler {
    [self fetchImageAssetWithUniqueIdentifier:identifier targetDomain:nil completionHandler:handler];
}

@end
