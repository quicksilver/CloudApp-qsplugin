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
        engine = [[CLAPIEngine engineWithDelegate:self] retain];
    }
    BOOL auth = [self authenticate];
    if (auth) {
        return self;
    } else {
        [self release];
        return nil;
    }
}

- (void)dealloc
{
    [engine release];
    engine = nil;
    [super dealloc];
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

- (QSObject *)objectFromWebItem:(CLWebItem *)cloudItem existingObject:(QSObject *)existingObject
{
    NSString *ident = [NSString stringWithFormat:@"CloudAppFile:%@", [cloudItem name]];
    QSObject *newObject = nil;
    if (existingObject) {
        newObject = existingObject;
        [newObject setIdentifier:ident];
    } else {
        newObject = [QSObject makeObjectWithIdentifier:ident];
    }
    [newObject setObject:cloudItem forCache:QSCloudWebItemKey];
    [newObject setObject:[cloudItem name] forType:QSCloudFileType];
    [newObject setName:[cloudItem name]];
    NSUInteger views = [cloudItem viewCount];
    NSString *details = [NSString stringWithFormat:@"Viewed %ld Time%@", views, (views == 1) ? @"" : @"s"];
    [newObject setDetails:details];
    //NSLog(@"Cloud URLs %@ | %@ | %@", [thing URL], [thing remoteURL], [thing href]);
    [newObject setObject:[[cloudItem URL] absoluteString] forType:QSTextType];
    [newObject setObject:[cloudItem remoteURL] forType:QSCloudDownloadURLType];
    [newObject setPrimaryType:QSCloudFileType];
    return newObject;
}

#pragma mark Cloud API Delegate Methods

- (void)itemListRetrievalSucceeded:(NSArray *)items connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo
{
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:[items count]];
    for (CLWebItem *cloudItem in items) {
        [objects addObject:[self objectFromWebItem:cloudItem existingObject:nil]];
    }
    QSCatalogEntry *entry = [userInfo objectForKey:@"entry"];
    [entry completeScanWithContents:objects];
    //NSLog(@"Cloud Item list: %@", items);
}

- (void)itemUpdateDidSucceed:(CLWebItem *)item connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo
{
    NSString *message = [userInfo objectForKey:@"message"];
    if (message) {
        NSString *name = [userInfo objectForKey:@"name"] ? [userInfo objectForKey:@"name"] : @"Item";
        NSString *title = [NSString stringWithFormat:@"%@ Updated", name];
        QSShowNotifierWithAttributes([NSDictionary dictionaryWithObjectsAndKeys:@"QSCloudItemUpdated", QSNotifierType, [QSResourceManager imageNamed:@"com.linebreak.CloudAppMacOSX"], QSNotifierIcon, title, QSNotifierTitle, message, QSNotifierText, nil]);
    }
}

- (void)itemDeletionDidSucceed:(CLWebItem *)item connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo
{
    QSShowNotifierWithAttributes([NSDictionary dictionaryWithObjectsAndKeys:@"QSCloudFileDeleted", QSNotifierType, [QSResourceManager imageNamed:@"com.linebreak.CloudAppMacOSX"], QSNotifierIcon, @"File Deleted", QSNotifierTitle, [userInfo objectForKey:@"name"], QSNotifierText, nil]);
}

- (void)requestDidSucceedWithConnectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo
{
    //	NSLog(@"[SUCCESS]: %@", connectionIdentifier);
}

- (void)requestDidFailWithError:(NSError *)error connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo {
	NSLog(@"Error communicating with CloudApp: %@", error);
    QSCatalogEntry *entry = [userInfo objectForKey:@"entry"];
    if (entry && [entry respondsToSelector:@selector(completeScanWithContents:)]) {
        [entry completeScanWithContents:nil];
    }
}

- (void)fileUploadDidProgress:(CGFloat)percentageComplete connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo {
	//NSLog(@"[UPLOAD PROGRESS]: %@, %f", connectionIdentifier, percentageComplete);
    QSTask *task = [userInfo objectForKey:@"task"];
    [task setProgress:percentageComplete];
}

- (void)fileUploadDidSucceedWithResultingItem:(CLWebItem *)item connectionIdentifier:(NSString *)connectionIdentifier userInfo:(id)userInfo {
	//NSLog(@"[UPLOAD SUCCESS]: %@, %@", connectionIdentifier, item);
    QSTask *task = [userInfo objectForKey:@"task"];
    QSObject *placeholder = [userInfo objectForKey:@"upload"];
    [self objectFromWebItem:item existingObject:placeholder];
    [task stopTask:nil];
    [placeholder putOnPasteboardAsPlainTextOnly:[NSPasteboard generalPasteboard]];
    QSShowNotifierWithAttributes([NSDictionary dictionaryWithObjectsAndKeys:@"QSCloudUploadComplete", QSNotifierType, [QSResourceManager imageNamed:@"com.linebreak.CloudAppMacOSX"], QSNotifierIcon, @"Upload Complete", QSNotifierTitle, [item name], QSNotifierText, nil]);
}

@end
