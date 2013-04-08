//
//  QSCloudDelegate.h
//  QSCloudApp
//
//  Created by Rob McBroom on 2013/04/08.
//

#import "Cloud/Cloud.h"
#import "QSCloudAppDefines.h"

@interface QSCloudDelegate : NSObject <CLAPIEngineDelegate>
{
    CLAPIEngine *engine;
}

@property (readonly, strong) CLAPIEngine *engine;

+ (QSCloudDelegate *)sharedInstance;

@end
