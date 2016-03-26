//
//  MRImageCacheManager.m
//  MRImageCache
//
//  Created by Rocco Del Priore on 3/16/16.
//  Copyright © 2016 Rocco Del Priore. All rights reserved.
//

#import "MRImageCacheManager.h"
#import "MRUtilities.h"

NSString *MRDefaultDomain = nil;
NSString *MRShortTermDomain  = nil;
NSString *MRLongTermDomain   = nil;
NSString *MRWorkingDomain    = nil;

static NSString *const MRMapImageKey      = @"d";
static NSString *const MRMapPathKey       = @"p";
static NSString *const MRBasePathKey      = @"MRI";
static const char *MRFileSystemQueueTitle = "MRIFileSystemQueue";
static const char *MRNetworkQueueTitle    = "MRINetworkQueue";

#define MRSafeHandlerCall(x, ...) \
	do { \
		if ((x)) { \
			x(__VA_ARGS__); \
		} \
	} while (0);

static const __unused float MRNetworkRequestDefaultTimeout = 30.0f;

@implementation MRImageCacheManager {
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

- (instancetype)initPrivate {
	self = [super init];
	if (self) {
		MRDefaultDomain   = [self defaultDomain];
		MRShortTermDomain = [self shortTermCacheDomain];
		MRLongTermDomain  = [self longTermCacheDomain];
		MRWorkingDomain   = [self workingCacheDomain];
		
		fileSystemQueue = dispatch_queue_create(MRFileSystemQueueTitle, 0);
		networkQueue    = dispatch_queue_create(MRNetworkQueueTitle, 0);
		map             = [NSMutableDictionary dictionary];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(memoryWarningReceived) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
		[self populateMap];
	}
	return self;
}

- (void)populateMap {
	//Should this be under FSQueue? Worried about making it ASync
	NSURL *directoryURL = [self _basePathForProject];
	NSArray *domains = [self _directoriesInDirectory:directoryURL];
	
	for (NSURL *domain in domains) {
		map[domain.lastPathComponent] = [NSMutableDictionary dictionary];
		NSArray *identifiers = [self _filesInDirectory:domain];
		for (NSURL *identifier in identifiers) {
			map[domain.lastPathComponent][identifier.lastPathComponent] = [@{MRMapPathKey:identifier} mutableCopy];
		}
	}
}

- (void)memoryWarningReceived {
	// Cleanup.
}

- (NSArray *)allDomains {
	return map.allKeys;
}

- (NSString *)defaultDomain {
	//return [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@"mric"];
	return @"mric";
}

- (NSString *)shortTermCacheDomain {
	return @"mricShortTerm";
}

- (NSString *)longTermCacheDomain {
	return @"mricLongTerm";
}

- (NSString *)workingCacheDomain {
	return @"mricWorking";
}

#pragma mark - Helpers

//TODO: Assert Identifier for all functions
// XXX: Should establish consistency of either throwing exception, or ignoring it.
// XXX: Maybe assume that this function will NEVER have a nil parameter, since it's internal.
// XXX: So our code should sanity check before calling to here.

- (NSArray *)_directoriesInDirectory:(NSURL *)url {
	NSMutableArray *array = [NSMutableArray array];
	NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:url includingPropertiesForKeys:keys options:0 errorHandler:^(NSURL *url, NSError *error) { return YES;}];
	
	for (NSURL *url in enumerator) {
		NSError *error;
		NSNumber *isDirectory = nil;
		if (! [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
			// handle error
		}
		else if (! [isDirectory boolValue]) {
			// No error and it’s not a directory; do something with the file
		}
		else {
			[array addObject:url];
		}
	}
	
	return array;
}

- (NSArray *)_filesInDirectory:(NSURL *)url {
	NSMutableArray *array = [NSMutableArray array];
	NSArray *keys = [NSArray arrayWithObject:NSURLIsRegularFileKey];
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:url includingPropertiesForKeys:keys options:0 errorHandler:^(NSURL *url, NSError *error) { return YES;}];
	
	for (NSURL *url in enumerator) {
		NSError *error;
		NSNumber *isDirectory = nil;
		if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
			// handle error
		}
		else if ([isDirectory boolValue]) {
			// No error and it’s not a directory; do something with the file
		}
		else {
			[array addObject:url];
		}
	}
	
	return array;
}

- (BOOL)_moveFileFromPath:(NSURL *)path toDestination:(NSURL *)destination withUniqueIdentifier:(NSString *)identifier inTargetDomain:(NSString *)domain error:(NSError **)error {
	[[NSFileManager defaultManager] removeItemAtURL:destination error:nil];
	if (![[NSFileManager defaultManager] moveItemAtURL:path toURL:destination error:error]) {
		if (error) {
			//            NSLog(@"Move Error: %@", error);
			return NO;
		}
		else {
			if (![map.allKeys containsObject:domain]) {
				map[domain] = [NSMutableDictionary  dictionary];
			}
			
			map[domain][identifier] = [@{MRMapPathKey : destination} mutableCopy];
			return YES;
		}
	}
	return NO;
}

- (NSURL *)_basePathForProject {
	NSArray *scope = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	if (scope.count) {
		NSURL *base = [NSURL fileURLWithPath:[scope objectAtIndex:0]];
		base = [base URLByAppendingPathComponent:MRBasePathKey isDirectory:YES];
		
		return base;
	}
	
	return nil;
}

- (NSURL *)_pathForIdentifier:(NSString *)identifier inTargetDomain:(NSString *)domain {
	if (!identifier || !domain) {
		return nil;
	}
	
	NSURL *base = [self _basePathForProject];
	if (base) {
		base = [base URLByAppendingPathComponent:domain isDirectory:YES];
		base = [base URLByAppendingPathComponent:identifier];
	}
	
	return base;
}

- (NSDictionary *)_imageDictionaryForUniqueIdentifier:(id)identifier inTargetDomain:(NSString *)domain {
	if (!identifier || !domain) {
		return nil;
	}
	
	if ([map.allKeys containsObject:domain]) {
		NSDictionary *domainDictionary = map[domain];
		if ([domainDictionary.allKeys containsObject:identifier]) {
			return domainDictionary[identifier];
		}
	}
	
	return nil;
}

- (UIImage *)_imageFromURL:(NSURL *)url error:(NSError **)error {
	// XXX: [url.filePathURL path], [url path], [url.fileReferenceURL path], absoluteURL, meh.
	UIImage *image = [UIImage imageWithContentsOfFile:[url.filePathURL path]];
	
	if (!image) {
		// Try to stat the image, perhaps will give us more info on the situation.
		// Populate Error
	}
	
	return image;
}

// TODO: Add NSError for MRIErrorType Enum
// TODO: Also declare MRI Error Domain

#pragma mark - Add

- (BOOL)addImageSynchronously:(UIImage *)image uniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain error:(NSError **)error {
	
	dispatch_semaphore_t wait = dispatch_semaphore_create(0);
	
	__block BOOL didSucceed = NO;
	__block NSError *addError = nil;
	
	[self addImage:image uniqueIdentifier:identifier targetDomain:domain completionHandler:^(BOOL success, NSError * _Nullable error) {
		didSucceed = success;
		addError = error;
		dispatch_semaphore_signal(wait);
	}];
	
	dispatch_semaphore_wait(wait, NSEC_PER_SEC * MRNetworkRequestDefaultTimeout);
	// XXX: Fix timeout. Doesn't really make sense.
	// Need assurance that this handler will ALWAYS be called to.
	
	if (addError && error) {
		*error = addError;
	}
	
	return didSucceed;
}

- (void)addImage:(UIImage *)image uniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(BOOL success, NSError * error))handler {
	dispatch_barrier_async(fileSystemQueue, ^{
		
		NSURL *target = [self _pathForIdentifier:identifier inTargetDomain:domain];
		
		NSError *moveError = nil;
		
		[[NSFileManager defaultManager] removeItemAtURL:target error:&moveError];
		
		if (moveError) {
			// XXX: if error is due to the file not existing, ignore
			// XXX: if error is due to actual issue, stop here.
		}
		
		BOOL success = [[NSFileManager defaultManager] createFileAtPath:target.path contents:UIImagePNGRepresentation(image) attributes:nil];
		// TODO: change attributes to have NSFileProtection
		
		if (success) {
			if (![map.allKeys containsObject:domain]) {
				map[domain] = [NSMutableDictionary  dictionary];
			}
			map[domain][identifier] = [@{MRMapPathKey:target} mutableCopy];
			
			MRSafeHandlerCall(handler, YES, nil);
		}
		
		else {
			MRSafeHandlerCall(handler, NO, [NSError errorWithDomain:@"erorrDomain which I swear I made." code:1 userInfo:nil]);
			// TODO: Fill in proper error here.
		}
	});
}

- (UIImage *)addImageFromURLSynchronously:(NSURL *)url uniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain error:(NSError **)error {
	
	dispatch_semaphore_t wait = dispatch_semaphore_create(0);
	
	__block NSError *retError = nil;
	__block UIImage *retImage = nil;
	
	[self addImageFromURL:url uniqueIdentifier:identifier  targetDomain:domain completionHandler:^(UIImage * _Nullable image, NSError * _Nullable error) {
		retImage = image;
		retError = error;
		
		dispatch_semaphore_signal(wait);
	}];
	
	dispatch_semaphore_wait(wait, NSEC_PER_SEC * MRNetworkRequestDefaultTimeout);
	// XXX: fix rimeout.
	
	if (retError && error) {
		*error = retError;
	}
	
	return retImage;
}

- (void)addImageFromURL:(NSURL *)url uniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage * image, NSError * error))handler {
	if (![url isFileURL]) {
		// TODO: throw exception here, or generate good error for the handler
		// XXX: MAKE SURE TO CALL THE HANDLER IF NOT THROWING AN EXCEPTION.
		return;
	}
	
	dispatch_barrier_async(fileSystemQueue, ^{
		UIImage *image = [UIImage imageWithContentsOfFile:[url.filePathURL path]];
		
		if (!image) {
			// handler(nil, )
			// pass good error.
			return;
		}
		
		[self addImage:image uniqueIdentifier:identifier targetDomain:domain completionHandler:^(BOOL success, NSError * _Nullable error) {
			if (success) {
				MRSafeHandlerCall(handler, image, nil);
			}
			else {
				MRSafeHandlerCall(handler, nil, error);
			}
		}];
	});
}

#pragma mark - Remove

- (BOOL)removeImageSynchronouslyWithIdentifier:(NSString *)identifier targetDomain:(NSString *)domain error:(NSError **)error {
	dispatch_semaphore_t wait = dispatch_semaphore_create(0);
	
	__block BOOL didSucceed = NO;
	__block NSError *retError = nil;
	
	[self removeImageWithIdentifier:identifier targetDomain:domain completionHandler:^(BOOL success, NSError * _Nullable error) {
		
		didSucceed = success;
		retError = error;
		
		dispatch_semaphore_signal(wait);
	}];
	
	dispatch_semaphore_wait(wait, NSEC_PER_SEC * MRNetworkRequestDefaultTimeout);
	// TOOD: again, fix timeout here.
	
	if (retError && error) {
		*error = retError;
	}
	
	return didSucceed;
}

- (void)removeImageWithIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(BOOL success, NSError * error))handler {
	dispatch_barrier_async(fileSystemQueue, ^{
		
		NSURL *target = [self _pathForIdentifier:identifier inTargetDomain:domain];
		
		NSError *removeError = nil;
		
		BOOL success = [[NSFileManager defaultManager] removeItemAtURL:target error:&removeError];
		
		MRSafeHandlerCall(handler, success, removeError);
	});
}

#pragma mark - Move

- (BOOL)moveImageSynchronouslyWithUniqueIdentifier:(NSString *)identifier currentDomain:(NSString *)current targetDomain:(NSString *)target error:(NSError **)error {
	if (!map[current]) {
		// TODO: Throw Exception for bad API usage
	}
	else if (![[map[current] allKeys] containsObject:identifier]) {
		// TODO: Throw Exception for bad API usage
	}
	else {
		NSURL *currentPath = [self _pathForIdentifier:identifier inTargetDomain:current];
		NSURL *targetPath = [self _pathForIdentifier:identifier inTargetDomain:target];
		
		if ([self _moveFileFromPath:currentPath toDestination:targetPath withUniqueIdentifier:identifier inTargetDomain:target error:error]) {
			return [self removeImageSynchronouslyWithIdentifier:identifier targetDomain:current error:error];
		}
	}
	
	return false;
}

- (void)moveImageWithUniqueIdentifier:(NSString *)identifier currentDomain:(NSString *)current targetDomain:(NSString *)target completionHandler:(void (^)(BOOL success, NSError * error))handler {
	dispatch_barrier_async(fileSystemQueue, ^{
		NSError *error = nil;
		BOOL success = [self moveImageSynchronouslyWithUniqueIdentifier:identifier currentDomain:current targetDomain:target error:&error];
		
		MRSafeHandlerCall(handler, success, error);
	});
}

- (BOOL)moveAllImagesSynchronouslyInDomain:(NSString *)current toDomain:(NSString *)target overwriteFilesInTarget:(BOOL)overwrite error:(NSError **)error {
	if (![map.allKeys containsObject:current]) {
		// TODO: Throw Exception for bad API usage
	}
	else if (![map.allKeys containsObject:target]) {
		// TOOD: Rename Current Domnain
	}
	else {
		// TODO: Merge Domnains into target, and remove current
	}
	
	return false;
}

- (void)moveAllImagesInDomain:(NSString *)current toDomain:(NSString *)target overwriteFilesInTarget:(BOOL)overwrite completionHandler:(void (^)(BOOL success, NSError * error))handler {
	dispatch_barrier_async(fileSystemQueue, ^{
		NSError *error = nil;
		BOOL success = [self moveAllImagesSynchronouslyInDomain:current toDomain:target overwriteFilesInTarget:overwrite error:&error];
		MRSafeHandlerCall(handler, success, error);
	});
}

#pragma mark - Accessors

- (UIImage *)fetchImageSynchronouslyWithRequest:(NSURLRequest *)request uniqueIdentifier:(NSString *)identifer targetDomain:(NSString *)domain error:(NSError **)error {
	
	dispatch_semaphore_t wait = dispatch_semaphore_create(0);
	
	__block NSError *retError = nil;
	__block UIImage *retImage = nil;
	
	[self fetchImageWithRequest:request uniqueIdentifier:identifer targetDomain:domain completionHandler:^(UIImage *__nullable image, NSError *__nullable error) {
		
		retImage = image;
		retError = error;
		
		dispatch_semaphore_signal(wait);
	}];
	
	dispatch_semaphore_wait(wait, NSEC_PER_SEC * MRNetworkRequestDefaultTimeout);
	
	if (retError && error) {
		*error = retError;
	}
	
	return retImage;
}

- (void)fetchImageWithRequest:(NSURLRequest *)request uniqueIdentifier:(NSString *)identifer targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage *image, NSError *error))handler {
	// TODO: Interesting thing happens here.
	// Consider the case where the user may want an updated version of the image.
	// If we store the date of retrieval, we can make a request with If-Modified-Since which will save time and resources.
	// Check if request has If-Modified-Since header, else, we should perhaps add it. Not sure if its ok to add headers to the users requests.
	// Also, perhaps have a parameter that specifies whether or not to actually make the request if it already exists on disk.
	// This was my decision, to make this function and always-callable. I have overseen a good case. My apologies
	
	NSDictionary *imageDictionary = [self _imageDictionaryForUniqueIdentifier:identifer inTargetDomain:domain];
	
	if (!request /* || !should request even exists on disk */) {
		
		// Check Memory
		if (imageDictionary[MRMapImageKey]) {
			MRSafeHandlerCall(handler, imageDictionary[MRMapImageKey], nil);
		}
		
		// Check Filesystem
		else if (imageDictionary[MRMapPathKey]) {
			dispatch_barrier_async(fileSystemQueue, ^{
				NSError *error = nil;
				UIImage *image = [self _imageFromURL:imageDictionary[MRMapPathKey] error:&error];
				
				MRSafeHandlerCall(handler, image, error);
			});
		}
		
		else {
			// XXX: Image doesn't exist. Oups!
		}
	}
	
	// Fetch remote
	else {
		NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
			if (error) {
				MRSafeHandlerCall(handler, nil, error);
				return;
			}
			
			NSError *moveError = nil;
			NSURL *toLocation = [self _pathForIdentifier:identifer inTargetDomain:domain];
			
			BOOL didMove = [self _moveFileFromPath:location toDestination:toLocation withUniqueIdentifier:identifer inTargetDomain:domain error:&moveError];
			
			if (!didMove) {
				MRSafeHandlerCall(handler, nil, moveError);
			}
			
			else {
				dispatch_barrier_async(fileSystemQueue, ^{
					NSError *error = nil;
					UIImage *image = [self _imageFromURL:toLocation error:&error];
					
					if (image) map[domain][identifer][MRMapImageKey] = image;
					MRSafeHandlerCall(handler, image, error);
				});
			}
		}];
		
		[task resume];
	}
}

- (UIImage *)fetchImageSynchronouslyWithUniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain error:(NSError **)error {
	return [self fetchImageSynchronouslyWithRequest:nil uniqueIdentifier:identifier targetDomain:domain error:error];
}

- (void)fetchImageWithUniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage *image, NSError *error))handler {
	[self fetchImageWithRequest:nil uniqueIdentifier:identifier targetDomain:domain completionHandler:handler];
}

@end
