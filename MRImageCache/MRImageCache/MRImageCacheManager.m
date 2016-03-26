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
    return [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@"mricShortTerm"];
}

- (NSString *)longTermCacheDomain {
    return [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@"mricLongTerm"];
}

- (NSString *)workingCacheDomain {
    return [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@"mricWorking"];
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
        //Populate Error
    }
    
    return image;
}

// TODO: Add NSError for MRIErrorType Enum
// TODO: Also declare MRI Error Domain

#pragma mark - Add

- (BOOL)addImageSynchronously:(UIImage *)image uniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain error:(NSError **)error {
    NSURL *target = [self _pathForIdentifier:identifier inTargetDomain:domain];
    
    [[NSFileManager defaultManager] removeItemAtURL:target error:nil];
    BOOL success = [[NSFileManager defaultManager] createFileAtPath:target.path contents:UIImagePNGRepresentation(image) attributes:nil];
    
    if (success) {
        if (![map.allKeys containsObject:domain]) {
            map[domain] = [NSMutableDictionary  dictionary];
        }
        map[domain][identifier] = [@{MRMapPathKey:target} mutableCopy];
    }
    
    return success;
}

- (void)addImage:(UIImage *)image uniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(BOOL success, NSError * error))handler {
    dispatch_barrier_async(fileSystemQueue, ^{
        NSError *error = nil;
        BOOL success = [self addImageSynchronously:image uniqueIdentifier:identifier targetDomain:domain error:&error];
        
        if (handler) {
            handler(success, error);
        }
    });
}

- (UIImage *)addImageFromURLSynchronously:(NSURL *)url targetDomain:(NSString *)domain error:(NSError **)error {
    if (![url isFileReferenceURL]) {
        // TODO: throw exception, or do something.
        return nil;
    }
    
    UIImage *image = [UIImage imageWithContentsOfFile:[url.filePathURL path]];
    if (image) {
        if ([self addImageSynchronously:image uniqueIdentifier:url.lastPathComponent targetDomain:domain error:error]) {
            return image;
        }
    }
    
    return nil;
}

- (void)addImageFromURL:(NSURL *)url targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage * image, NSError * error))handler {
    dispatch_barrier_async(fileSystemQueue, ^{
        NSError *error = nil;
        UIImage *image = [self addImageFromURLSynchronously:url targetDomain:domain error:&error];
        
        if (handler) {
            handler(image, error);
        }
    });
}

#pragma mark - Remove

- (BOOL)removeImageSynchronouslyWithIdentifier:(NSString *)identifier targetDomain:(NSString *)domain error:(NSError **)error {
    NSURL *target = [self _pathForIdentifier:identifier inTargetDomain:domain];
    return [[NSFileManager defaultManager] removeItemAtURL:target error:error];
}

- (void)removeImageWithIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(BOOL success, NSError * error))handler {
    dispatch_barrier_async(fileSystemQueue, ^{
        NSError *error = nil;
        BOOL success = [self removeImageSynchronouslyWithIdentifier:identifier targetDomain:domain error:&error];
        
        if (handler) {
            handler(success, error);
        }
    });
}

#pragma mark - Move

- (BOOL)moveImageSynchronouslyWithUniqueIdentifier:(NSString *)identifier currentDomain:(NSString *)current targetDomain:(NSString *)target error:(NSError **)error {
    if (![map.allKeys containsObject:current]) {
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
        
        if (handler) {
            handler(success, error);
        }
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
        if (handler) handler(success, error);
    });
}

#pragma mark - Accessors

- (UIImage *)fetchImageSynchronouslyWithRequest:(NSURLRequest *)request uniqueIdentifier:(NSString *)identifer targetDomain:(NSString *)domain error:(NSError **)error {
    NSDictionary *imageDictionary = [self _imageDictionaryForUniqueIdentifier:identifer inTargetDomain:domain];
    //Check Memory
    if (imageDictionary[MRMapImageKey]) {
        return imageDictionary[MRMapImageKey];
    }
    //Check Filesystem
    else if (imageDictionary[MRMapPathKey]) {
        return [self _imageFromURL:imageDictionary[MRMapPathKey] error:error];
    }
    //Fetch From Remote
    else if (request) {
        //TODO: Fetch From Remote Synchronously
    }
    
    return nil;
}

- (void)fetchImageWithRequest:(NSURLRequest *)request uniqueIdentifier:(NSString *)identifer targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage *image, NSError *error))handler {
    NSDictionary *imageDictionary = [self _imageDictionaryForUniqueIdentifier:identifer inTargetDomain:domain];
    //Check Memory
    if (imageDictionary[MRMapImageKey]) {
        if (handler) {
            handler(imageDictionary[MRMapImageKey], nil);
        }
    }
    //Check Filesystem
    else if (imageDictionary[MRMapPathKey]) {
        dispatch_barrier_async(fileSystemQueue, ^{
            NSError *error = nil;
            UIImage *image = [self _imageFromURL:imageDictionary[MRMapPathKey] error:&error];
            
            if (handler) {
                handler(image, error);
            }
        });
    }
    //Fetch From Remote
    else if (request) {
        NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (error) { handler(nil, error); return; }
            
            NSError *error2 = nil;
            NSURL *toLocation = [self _pathForIdentifier:identifer inTargetDomain:domain];
            
            if (![self _moveFileFromPath:location toDestination:toLocation withUniqueIdentifier:identifer inTargetDomain:domain error:&error2]) {
                NSLog(@"move file failed: %@", error2);
                if (handler) handler(nil, error2);
            }
            else {
                dispatch_barrier_async(fileSystemQueue, ^{
                    NSLog(@"Move File success");
                    NSError *error = nil;
                    UIImage *image = [self _imageFromURL:toLocation error:&error];
                    
                    if (image) map[domain][identifer][MRMapImageKey] = image;
                    if (handler) handler(image, error);
                });
            }
        }];
        [task resume];
    }
    //Call Failure
    else {
        if (handler) handler(nil, nil);
    }
}

- (UIImage *)fetchImageSynchronouslyWithUniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain error:(NSError **)error {
    return [self fetchImageSynchronouslyWithRequest:nil uniqueIdentifier:identifier targetDomain:domain error:error];
}

- (void)fetchImageWithUniqueIdentifier:(NSString *)identifier targetDomain:(NSString *)domain completionHandler:(void (^)(UIImage *image, NSError *error))handler {
    [self fetchImageWithRequest:nil uniqueIdentifier:identifier targetDomain:domain completionHandler:handler];
}

@end
