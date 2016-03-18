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
	// XXX: on +load/+initialize, load disk save into mem
	// XXX: return vals here
	NSArray *defaultDomains = @[
								[self shortTermCacheDomain],
								[self longTermCacheDomain],
								[self workingCacheDomain]
								];
	
	// add user defined domains here.
	
	return defaultDomains;
}

- (NSString *)defaultDomain {
	// XXX: defaultDomain should be shortTerm, longTerm, or working. Not sure which yet though.
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

- (BOOL)_moveFileFromPath:(NSURL *)path toDestination:(NSURL *)destination error:(NSError **)error {
	return NO;
}

- (void)_updateFileSystemMapWithURL:(NSURL *)location uniqueIdentifier:(NSString *)identifier inTargetDomain:(NSString *)domain {
	
}

- (void)_updateMemoryMapWithImage:(UIImage *)image uniqueIdentifier:(NSString *)identifier inTargetDomain:(NSString *)domain {
	
}

- (NSURL *)_pathForIdentifier:(NSString *)identifier inTargetDomain:(NSString *)domain {
	return nil;
}

- (UIImage *)_imageFromMemoryWithIdentifier:(NSString *)identifier targetDomain:(NSString *)domain {
	// TODO: push this into memory cache
	
	if (!identifier) {
		// XXX: Should establish consistency of either throwing exception, or ignoring it.
		// XXX: Maybe assume that this function will NEVER have a nil parameter, since it's internal.
		// XXX: So our code should sanity check before calling to here.
		return nil;
	}
	
	if ([memoryMap.allKeys containsObject:domain]) {
		NSDictionary *domainMap = memoryMap[domain];
		if ([domainMap.allKeys containsObject:identifier]) {
			return domainMap[identifier];
		}
	}
	return nil;
}

- (NSURL *)_imagePathFromFileSystemWithIdentifier:(NSString *)identifier targetDomain:(NSString *)domain {
	if (!identifier) {
		// XXX: look at _imageFromMemoryWithIdentifier:targetDomain: for commentary
		return nil;
	}
	
	if ([fileSystemMap.allKeys containsObject:domain]) {
		NSDictionary *domainMap = fileSystemMap[domain];
		if ([domainMap.allKeys containsObject:identifier]) {
			return domainMap[identifier];
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

- (void)removeImageWithIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage * image, NSError * error))handler {
	
}

#pragma mark - Accessors

- (void)fetchImageWithRequest:(NSURLRequest *)request uniqueIdentifier:(NSString *)identifer targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage *image, NSError *error))handler {
	//Check Memory
	UIImage *image = [self _imageFromMemoryWithIdentifier:identifer targetDomain:domain];
	if (image) { handler(image, nil); return; }
	
	//Check File System
	NSURL *url = [self _imagePathFromFileSystemWithIdentifier:identifer targetDomain:domain];
	if (url) { [self _imageFromURL:url completionHandler:handler]; return; }
	
	//Fetch From Remote
	
	NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
		if (error) {
			handler(nil, error);
		}
		else {
			NSError *error = nil;
			NSURL *toLocation = [self _pathForIdentifier:identifer inTargetDomain:domain];
			
			if (![self _moveFileFromPath:location toDestination:toLocation error:&error]) {
				handler(nil, error);
			}
			else {
				// XXX: add to file system map
				// XXX: add load from disk to queue and pass to handler
				// [self _imageFromURL:toLocation completionHandler:^(UIImage *image, NSError *error) {
				//		if (error) handler(nil, error);
				//		else handler(image, nil);
				// }];
			
			}
			
//                [[NSFileManager defaultManager] removeItemAtURL:toLocation error:nil];
//                if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:toLocation error:&error]) {
//                    if (error) {
//                        handler(nil, error);
//                    }
//                    else {
//                        [self _updateFileSystemMapWithURL:toLocation uniqueIdentifier:identifer inTargetDomain:domain];
//                        [self _imageFromURL:toLocation completionHandler:^(UIImage *image, NSError *error) {
//                            [self _updateMemoryMapWithImage:image uniqueIdentifier:identifer inTargetDomain:domain];
//                            handler(image, error);
//                        }];
//                    }
//                }
		}
	}];
	
	[task resume];
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

// XXX: What domain does this search? does it remove from ALL of them???
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
