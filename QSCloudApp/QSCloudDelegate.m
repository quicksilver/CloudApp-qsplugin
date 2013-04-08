//
//  QSCloudDelegate.m
//  QSCloudApp
//
//  Created by Rob McBroom on 2013/04/08.
//

#import "QSCloudDelegate.h"

@implementation QSCloudDelegate

@synthesize engine;

static QSCloudDelegate *_sharedInstance;

+ (QSCloudDelegate *)sharedInstance {
	if (!_sharedInstance) _sharedInstance = [[[self class] allocWithZone:[self zone]] init];
	return _sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        engine = [CLAPIEngine engineWithDelegate:self];
    }
    return [self authenticate] ? self : nil;
}

- (BOOL)authenticate
{
    NSDictionary *cloudAppQuery = [NSDictionary dictionaryWithObjectsAndKeys:
                           kSecClassGenericPassword, kSecClass,
                           (id)kCFBooleanTrue, kSecReturnData,
                           (id)kCFBooleanTrue, kSecReturnAttributes,
                           kSecMatchLimitOne, kSecMatchLimit,
                           QSCloudAppServiceName, kSecAttrService,
                           nil];
    NSDictionary *itemDict = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)cloudAppQuery, (CFTypeRef *)&itemDict);
    if (status) {
        NSLog(@"Unable to get CloudApp credentials from Keychain. OSStatus %d", status);
        return NO;
    }
    NSData *data = [itemDict objectForKey:kSecValueData];
    NSString *account = [itemDict objectForKey:kSecAttrAccount];
    NSString *password = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    [engine setEmail:account];
    [engine setPassword:password];
    [itemDict release];
    return YES;
}

#pragma mark Quicksilver Methods

#pragma mark Cloud API Delegate Methods

- (void)itemListRetrievalSucceeded:(NSArray *)items connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo
{
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:[items count]];
    QSObject *newObject = nil;
    NSString *ident = nil;
    for (CLWebItem *thing in items) {
        ident = [NSString stringWithFormat:@"CloudAppFile:%@", [thing name]];
        newObject = [QSObject makeObjectWithIdentifier:ident];
        [newObject setObject:[thing name] forType:QSCloudFileType];
        [newObject setName:[thing name]];
        [newObject setDetails:@"Remote Cloud File"];
        //NSLog(@"Cloud URLs %@ | %@ | %@", [thing URL], [thing remoteURL], [thing href]);
        [newObject setObject:[thing URL] forType:QSCloudURLType];
        [newObject setObject:[thing remoteURL] forType:QSCloudDownloadURLType];
        [newObject setPrimaryType:QSCloudFileType];
        [objects addObject:newObject];
    }
    [(QSCatalogEntry *)userInfo completeScanWithContents:objects];
    //NSLog(@"Cloud Item list: %@", items);
}

- (void)requestDidSucceedWithConnectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo
{
    //	NSLog(@"[SUCCESS]: %@", connectionIdentifier);
}

- (void)requestDidFailWithError:(NSError *)error connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo {
	NSLog(@"Error communicating with CloudApp: %@", error);
    if ([userInfo respondsToSelector:@selector(completeScanWithContents:)]) {
        [(QSCatalogEntry *)userInfo completeScanWithContents:nil];
    }
}

- (void)fileUploadDidProgress:(CGFloat)percentageComplete connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo {
	NSLog(@"[UPLOAD PROGRESS]: %@, %f", connectionIdentifier, percentageComplete);
}

- (void)fileUploadDidSucceedWithResultingItem:(CLWebItem *)item connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo {
	NSLog(@"[UPLOAD SUCCESS]: %@, %@", connectionIdentifier, item);
}

@end
