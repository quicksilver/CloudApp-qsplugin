//
//  QSCloudAppSource.m
//  QSCloudApp
//
//  Created by Rob McBroom on 2012/10/20.
//

#import "QSCloudDelegate.h"
#import "QSCloudAppSource.h"

@implementation QSCloudAppSource

@synthesize holdArray, semaphore;

+ (QSCloudAppSource *)sharedInstance {
    static QSCloudAppSource *CloudAppSource = nil;
    if (!CloudAppSource) {
        CloudAppSource = [[QSCloudAppSource alloc] init];
    }
    return CloudAppSource;
}

- (id)init {
    if (self = [super init]) {
        semaphore = nil;
    }
    return self;
}

- (BOOL)indexIsValidFromDate:(NSDate *)indexDate forEntry:(NSDictionary *)theEntry
{
    // always rescan
	return NO;
}

- (NSImage *)iconForEntry:(NSDictionary *)dict
{
	return nil;
}

- (NSArray *)objectsForEntry:(QSCatalogEntry *)theEntry
{
    semaphore = dispatch_semaphore_create(0);
    CLAPIEngine *engine = [[QSCloudDelegate sharedInstance] engine];
    NSDictionary *info = @{@"entry": theEntry};
    NSUInteger itemLimit = [[NSUserDefaults standardUserDefaults] integerForKey:@"QSCloudAppItemLimit"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __unused NSString *result = [engine getItemListStartingAtPage:1 itemsPerPage:itemLimit userInfo:info];
    });
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    dispatch_release(semaphore);
    semaphore = nil;
    return holdArray;
}

#pragma mark Object Handler Methods

- (void)setQuickIconForObject:(QSObject *)object
{
    NSString *extension = [[object name] pathExtension];
    if (extension) {
        [object setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:extension]];
    }
}

- (BOOL)objectHasChildren:(QSObject *)object
{
    return [object isApplication];
}

- (BOOL)loadChildrenForObject:(QSObject *)object
{
    if ([object isApplication]) {
        [object setChildren:[QSLib arrayForType:QSCloudFileType]];
        return YES;
    }
    return NO;
}

@end
