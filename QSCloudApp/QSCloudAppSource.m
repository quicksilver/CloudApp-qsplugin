//
//  QSCloudAppSource.m
//  QSCloudApp
//
//  Created by Rob McBroom on 2012/10/20.
//

#import "QSCloudDelegate.h"
#import "QSCloudAppSource.h"

@implementation QSCloudAppSource

- (BOOL)indexIsValidFromDate:(NSDate *)indexDate forEntry:(NSDictionary *)theEntry
{
    // always rescan
	return NO;
}

- (NSImage *)iconForEntry:(NSDictionary *)dict
{
	return nil;
}

- (BOOL)loadObjectsForEntry:(QSCatalogEntry *)theEntry
{
    CLAPIEngine *engine = [[QSCloudDelegate sharedInstance] engine];
    NSDictionary *info = @{@"entry": theEntry};
    NSUInteger itemLimit = [[NSUserDefaults standardUserDefaults] integerForKey:@"QSCloudAppItemLimit"];
    __unused NSString *result = [engine getItemListStartingAtPage:1 itemsPerPage:itemLimit userInfo:info];
    //NSLog(@"Cloud Transaction ID: %@", result);
    return YES;
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
