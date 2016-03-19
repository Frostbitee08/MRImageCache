//
//  MRImageCacheManager.m
//  MRImageCache
//
//  Created by Rocco Del Priore on 3/16/16.
//  Copyright © 2016 Rocco Del Priore. All rights reserved.
//

#import "MRImageCacheManager.h"
#import "MRUtilities.h"

static NSString *const MRMapImageKey = @"d";
static NSString *const MRMapPathKey = @"p";
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
	
    NSMutableDictionary *map;
}

#pragma mark - Class Methods

+ (instancetype)sharedInstance {
	static id _instance = nil;
	static dispatch_once_t token;
	dispatch_once(&token, ^{
		_instance = [[super alloc] initPrivate];
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

- (instancetype)initPrivate { // forsaken `initializers` must be prefixed `init` :(
	self = [super init];
	if (self) {
        fileSystemQueue = dispatch_queue_create(MRFileSystemQueueTitle, 0);
        networkQueue    = dispatch_queue_create(MRNetworkQueueTitle, 0);
        map             = [NSMutableDictionary dictionary];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(memoryWarningReceived) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
	}
	return self;
}


- (void)memoryWarningReceived {
	// Cleanup.
}

- (NSArray *)allDomains {
    return map.allKeys;
}

- (NSString *)defaultDomain {
	return [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@"mric"];
}

- (NSString *)shortTermCacheDomain {
	return [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@"mricShortTerm"];
}

- (NSString *)longTermCacheDomain {
    return [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@"mricLongTerm"];
}

- (NSString *)workingCacheDomain {
	return [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@"mricWorking"];
}

#pragma mark - Helpers

- (BOOL)_moveFileFromPath:(NSURL *)path toDestination:(NSURL *)destination withUniqueIdentifier:(NSString *)identifier inTargetDomain:(NSString *)domain error:(NSError **)error {
    [[NSFileManager defaultManager] removeItemAtURL:destination error:nil];
    if (![[NSFileManager defaultManager] moveItemAtURL:path toURL:destination error:error]) {
        if (error) {
            return NO;
        }
        else {
            map[domain][identifier] = @{MRMapPathKey : destination};
            return YES;
        }
    }
	return NO;
}

- (NSURL *)_pathForIdentifier:(NSString *)identifier inTargetDomain:(NSString *)domain {
	return nil;
}

- (NSDictionary *)_imageDictionaryForUniqueIdentifier:(id)identifier inTargetDomain:(NSString *)domain {
    if (!identifier) {
        // XXX: Should establish consistency of either throwing exception, or ignoring it.
        // XXX: Maybe assume that this function will NEVER have a nil parameter, since it's internal.
        // XXX: So our code should sanity check before calling to here.
        return nil;
    }
    if (!domain) {
        domain = [self defaultDomain];
    }
    
    if ([map.allKeys containsObject:domain]) {
        NSDictionary *domainDictionary = map[domain];
        if ([domainDictionary.allKeys containsObject:identifier]) {
            return domainDictionary[identifier];
        }
    }
    
    return nil;
}

- (void)_imageFromURL:(NSURL *)url completionHandler:(void (^)(UIImage * image, NSError * error))handler {
	dispatch_barrier_async(fileSystemQueue, ^{
		// XXX: [url.filePathURL path], [url path], [url.fileReferenceURL path], absoluteURL, meh.
		UIImage *image = [UIImage imageWithContentsOfFile:[url.filePathURL path]];
		
		if (image) handler(image, nil);
		else {
			NSError *error = [[NSError alloc] initWithDomain:@"domain" code:404 userInfo:nil];
			handler(nil, error);
		}
	});
		
}

// TODO: Add NSError for MRIErrorType Enum
// TODO: Also declare MRI Error Domain

#pragma mark - Modifiers

- (void)addImage:(UIImage *)image uniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage * image, NSError * error))handler {
	
}

- (void)addImageFromURL:(NSURL *)url targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage * image, NSError * error))handler {
	if (![url isFileReferenceURL]) {
		// TODO: throw exception, or do something. ;P
		// or pass to fetch.. ?
		return;
	}
	// TODO: read image into memory then call addImage:uniqueIdentifier:targetDomain:completionHandler:?
	// or just do separate behavior to save from loading image into memory.
	// UIImage does not have lazy loading, but can remove internal backing if memory warning occurs, then load lazily thereafter.
}

- (void)removeImageWithIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(BOOL success, NSError * error))handler {
    
}

- (void)moveImageWithUniqueIdentifier:(NSString *)identifier currentDomain:(NSString *)current targetDomain:(NSString *)target completionHandler:(void (^)(BOOL success, NSError * error))handler {
    if (![map.allKeys containsObject:current]) {
        // Throw Exception for bad API usage
    }
    else if (![[map[current] allKeys] containsObject:identifier]) {
        // Throw Exception for bad API usage
    }
    else {
        NSURL *currentPath = [self _pathForIdentifier:identifier inTargetDomain:current];
        NSURL *targetPath = [self _pathForIdentifier:identifier inTargetDomain:target];
        
        dispatch_barrier_async(fileSystemQueue, ^{
            NSError *error = nil;
            if ([self _moveFileFromPath:currentPath toDestination:targetPath withUniqueIdentifier:identifier inTargetDomain:target error:&error]) {
                [self removeImageWithIdentifier:identifier targetDomain:current completionHandler:handler];
            }
            else {
                handler(FALSE, error);
            }
        });
    }
}

- (void)moveAllImagesInDomain:(NSString *)current toDomain:(NSString *)target overwriteFilesInTarget:(BOOL)overwrite completionHandler:(void (^)(BOOL success, NSError * error))handler {
    if (![map.allKeys containsObject:current]) {
        // Throw Exception for bad API usage
    }
    else if (![map.allKeys containsObject:target]) {
        // Rename Current Domnain
    }
    else {
        // Merge Domnains into target, and remove current
    }
}

#pragma mark - Accessors

- (void)fetchImageWithRequest:(NSURLRequest *)request uniqueIdentifier:(NSString *)identifer targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage *image, NSError *error))handler {
    NSDictionary *imageDictionary = [self _imageDictionaryForUniqueIdentifier:identifer inTargetDomain:domain];
    
    //Check Memory
    if (imageDictionary[MRMapImageKey]) {
        handler(imageDictionary[MRMapImageKey], nil);
    }
    //Check Filesystem
    else if (imageDictionary[MRMapPathKey]) {
        [self _imageFromURL:imageDictionary[MRMapPathKey] completionHandler:handler];
    }
    //Fetch From Remote
    else if (request) {
        NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (error) { handler(nil, error); return; }
            
            dispatch_barrier_async(fileSystemQueue, ^{
                NSError *error2 = nil;
                NSURL *toLocation = [self _pathForIdentifier:identifer inTargetDomain:domain];
                
                if (![self _moveFileFromPath:location toDestination:toLocation withUniqueIdentifier:identifer inTargetDomain:domain error:&error2]) {
                    handler(nil, error2);
                }
                else {
					[self _imageFromURL:toLocation completionHandler:handler];
                }
            });
        }];
        [task resume];
    }
}

- (void)fetchImageWithUniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage *image, NSError *error))handler {
	[self fetchImageWithRequest:nil uniqueIdentifier:identifier targetDomain:domain completionHandler:handler];
}

#pragma mark - Conveniences (Pass Through)

- (void)addImage:(UIImage *)image uniqueIdentifier:(NSString *)identifier completionHandler:(void (^)(UIImage *, NSError *))handler {
	[self addImage:image uniqueIdentifier:identifier targetDomain:nil completionHandler:handler];
}

- (void)addImageFromURL:(NSURL *)url completionHandler:(void (^)(UIImage *, NSError *))handler {
	[self addImageFromURL:url targetDomain:nil completionHandler:handler];
}

- (void)removeImageWithIdentifier:(id)identifier completionHandler:(void (^)(BOOL success, NSError * error))handler {
	[self removeImageWithIdentifier:identifier targetDomain:nil completionHandler:handler];
}

- (void)fetchImageWithRequest:(NSURLRequest *)request uniqueIdentifier:(NSString *)identifer completionHandler:(void (^)(UIImage *image, NSError *error))handler {
	[self fetchImageWithRequest:request uniqueIdentifier:identifer targetDomain:nil completionHandler:handler];
}

- (void)fetchImageWithUniqueIdentifier:(NSString *)identifier completionHandler:(void (^)(UIImage *, NSError *))handler {
	[self fetchImageWithUniqueIdentifier:identifier targetDomain:nil completionHandler:handler];
}

@end
