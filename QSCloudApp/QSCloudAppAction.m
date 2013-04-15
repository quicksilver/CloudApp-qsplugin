//
//  QSCloudAppAction.m
//  QSCloudApp
//
//  Created by Rob McBroom on 2012/10/20.
//

#import "QSCloudDelegate.h"
#import "QSCloudAppAction.h"

@implementation QSCloudAppActionProvider

- (QSObject *)getLinkForCloudItem:(QSObject *)dObject
{
    NSString *address = [dObject objectForType:QSTextType];
    QSObject *itemURL = [QSObject URLObjectWithURL:address title:[dObject displayName]];
    return itemURL;
}

- (QSObject *)copyLinkForCloudItem:(QSObject *)dObject
{
    NSString *address = [dObject objectForType:QSTextType];
    QSObject *itemURL = [QSObject URLObjectWithURL:address title:nil];
    [itemURL putOnPasteboardAsPlainTextOnly:[NSPasteboard generalPasteboard]];
    return nil;
}

- (QSObject *)renameItem:(QSObject *)dObject to:(QSObject *)iObject
{
    runOnMainQueueSync(^{
        CLAPIEngine *engine = [[QSCloudDelegate sharedInstance] engine];
        CLWebItem *cloudItem = [dObject objectForCache:QSCloudWebItemKey];
        if (cloudItem) {
            NSString *oldName = [cloudItem name];
            NSString *newName = [iObject stringValue];
            NSString *message = [NSString stringWithFormat:@"Name changed to '%@'", newName];
            NSDictionary *info = @{@"name": oldName, @"message": message};
            [engine changeNameOfItem:cloudItem toName:newName userInfo:info];
        }
    });
    return nil;
}

- (QSObject *)deleteItem:(QSObject *)dObject
{
    runOnMainQueueSync(^{
        CLAPIEngine *engine = [[QSCloudDelegate sharedInstance] engine];
        for (QSObject *target in [dObject splitObjects]) {
            CLWebItem *cloudItem = [target objectForCache:QSCloudWebItemKey];
            if (cloudItem) {
                NSDictionary *info = @{@"name": [target displayName]};
                [engine deleteItem:cloudItem userInfo:info];
            }
        }
    });
    return nil;
}

- (QSObject *)enablePrivacyforItem:(QSObject *)dObject
{
    runOnMainQueueSync(^{
        CLAPIEngine *engine = [[QSCloudDelegate sharedInstance] engine];
        for (QSObject *target in [dObject splitObjects]) {
            CLWebItem *cloudItem = [target objectForCache:QSCloudWebItemKey];
            if (cloudItem) {
                NSString *message = @"Item is now private";
                NSDictionary *info = @{@"name": [target displayName], @"message": message};
                [engine changePrivacyOfItem:cloudItem toPrivate:YES userInfo:info];
            }
        }
    });
    return nil;
}

- (QSObject *)disablePrivacyforItem:(QSObject *)dObject
{
    runOnMainQueueSync(^{
        CLAPIEngine *engine = [[QSCloudDelegate sharedInstance] engine];
        for (QSObject *target in [dObject splitObjects]) {
            CLWebItem *cloudItem = [target objectForCache:QSCloudWebItemKey];
            if (cloudItem) {
                NSString *message = @"Item is now public";
                NSDictionary *info = @{@"name": [target displayName], @"message": message};
                [engine changePrivacyOfItem:cloudItem toPrivate:NO userInfo:info];
            }
        }
    });
    return nil;
}

- (QSObject *)togglePrivacyforItem:(QSObject *)dObject
{
    runOnMainQueueSync(^{
        CLAPIEngine *engine = [[QSCloudDelegate sharedInstance] engine];
        for (QSObject *target in [dObject splitObjects]) {
            CLWebItem *cloudItem = [target objectForCache:QSCloudWebItemKey];
            if (cloudItem) {
                BOOL private = [cloudItem isPrivate];
                NSString *message = private ? @"Item is now public" : @"Item is now private";
                NSDictionary *info = @{@"name": [target displayName], @"message": message};
                [engine changePrivacyOfItem:cloudItem toPrivate:!private userInfo:info];
            }
        }
    });
    return nil;
}

- (QSObject *)uploadFile:(QSObject *)dObject
{
    runOnMainQueueSync(^{
        CLAPIEngine *engine = [[QSCloudDelegate sharedInstance] engine];
        // create an object to represent the remote counterpart
        // QSCloudAppDelegate will add real data to it when the upload finishes
        QSObject *uploadPlaceholder = nil;
        for (QSObject *fileObject in [dObject splitObjects]) {
            NSString *displayName = [fileObject displayName];
            NSString *path = [fileObject singleFilePath];
            uploadPlaceholder = [QSObject objectWithName:displayName];
            [uploadPlaceholder setDetails:@"Uploading…"];
            [uploadPlaceholder setObject:@"" forType:QSCloudFileType];
            [uploadPlaceholder setPrimaryType:QSCloudFileType];
            QSTask *task = [QSTask taskWithIdentifier:[NSString stringWithFormat:@"CloudAppUpload:%@", path]];
            [task setName:displayName];
            [task setStatus:@"Uploading to CloudApp"];
            [task setIcon:[QSResourceManager imageNamed:@"com.linebreak.CloudAppMacOSX"]];
            [task startTask:nil];
            NSDictionary *info = @{@"task": task, @"upload": uploadPlaceholder};
            __unused NSString *result = [engine uploadFileWithName:displayName fileData:[NSData dataWithContentsOfFile:path] userInfo:info];
            //NSLog(@"Starting upload for %@\nTransaction ID: %@", path, result);
        }
    });
    return nil;
}

- (QSObject *)downloadFile:(QSObject *)dObject toFolder:(QSObject *)iObject
{
    NSString *destination = [iObject singleFilePath];
    QSObject *savedFile = nil;
    for (QSObject *cloudFile in [dObject splitObjects]) {
        NSString *fileName = [cloudFile objectForType:QSCloudFileType];
        NSString *path = [destination stringByAppendingPathComponent:fileName];
        NSURL *source = [cloudFile objectForType:QSCloudDownloadURLType];
        NSError *error = nil;
        NSData *fileContents = [NSData dataWithContentsOfURL:source options:0 error:&error];
        if (error) {
            NSLog(@"CloudApp Download error: %@", error);
            QSShowNotifierWithAttributes([NSDictionary dictionaryWithObjectsAndKeys:@"QSCloudDownloadError", QSNotifierType, [QSResourceManager imageNamed:@"com.linebreak.CloudAppMacOSX"], QSNotifierIcon, @"Download Failed", QSNotifierTitle, [error localizedDescription], QSNotifierText, nil]);
        } else if ([fileContents writeToFile:path atomically:NO]) {
            savedFile = [QSObject fileObjectWithPath:path];
            // notification for event triggers
            [[NSNotificationCenter defaultCenter] postNotificationName:@"QSEventNotification" object:@"QSCloudAppFileDownload" userInfo:[NSDictionary dictionaryWithObject:savedFile forKey:@"object"]];
        }
    }
    return savedFile;
}

#pragma mark Quicksilver Validation

- (NSArray *)validActionsForDirectObject:(QSObject *)dObject indirectObject:(QSObject *)iObject
{
    NSMutableArray *allowedActions = [NSMutableArray array];
    NSArray *selectedObjects = [dObject splitObjects];
    // only allow renaming for a single object
    if ([dObject count] == 1) {
        [allowedActions addObject:@"QSCloudRenameItemAction"];
    }
    
    // don't allow directories to be uploaded
    // if all selected files have the same privacy setting, allow it to be set to the opposite
    BOOL selectionContainsDirectory = NO;
    BOOL commonPrivacySetting = YES;
    BOOL private = [[[selectedObjects lastObject] objectForCache:QSCloudWebItemKey] isPrivate];
    for (QSObject *object in selectedObjects) {
        if ([object isDirectory]) {
            selectionContainsDirectory = YES;
        }
        CLWebItem *cloudItem = [object objectForCache:QSCloudWebItemKey];
        if (cloudItem) {
            if ([cloudItem isPrivate] != private) {
                commonPrivacySetting = NO;
            }
        }
    }
    if (!selectionContainsDirectory) {
        [allowedActions addObject:@"QSCloudUploadFileAction"];
    }
    if (commonPrivacySetting) {
        [allowedActions addObject:(private ? @"QSCloudDisablePrivacyAction" : @"QSCloudEnablePrivacyAction")];
    }
    
    return allowedActions;
}

- (NSArray *)validIndirectObjectsForAction:(NSString *)action directObject:(QSObject *)dObject
{
    if ([action isEqualToString:@"QSCloudDownloadFileAction"]) {
        // list all catalog folders, with the download folder as default
        NSArray *fileObjects = [[QSLibrarian sharedInstance] arrayForType:QSFilePathType];
        NSString *downloads = [[QSDownloads downloadsLocation] path];
        id defaultFolder = downloads ? [QSObject fileObjectWithPath:downloads] : [NSNull null];
        NSIndexSet *folderIndexes = [fileObjects indexesOfObjectsWithOptions:NSEnumerationConcurrent passingTest:^BOOL(QSObject *thisObject, NSUInteger i, BOOL *stop) {
            return ([thisObject isFolder] && ![[thisObject singleFilePath] isEqualToString:downloads]);
        }];
        return [@[defaultFolder] arrayByAddingObjectsFromArray:[fileObjects objectsAtIndexes:folderIndexes]];
    }
    if ([action isEqualToString:@"QSCloudRenameItemAction"]) {
        return @[[QSObject textProxyObjectWithDefaultValue:[dObject displayName]]];
    }
    return nil;
}

@end
