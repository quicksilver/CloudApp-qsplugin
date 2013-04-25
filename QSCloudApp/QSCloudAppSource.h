//
//  QSCloudAppSource.h
//  QSCloudApp
//
//  Created by Rob McBroom on 2012/10/20.
//


@interface QSCloudAppSource : QSObjectSource {
    dispatch_semaphore_t semaphore;
    NSArray *holdArray;
}

@property (retain) NSArray * holdArray;
@property (readonly) dispatch_semaphore_t semaphore;

+ (QSCloudAppSource *)sharedInstance;

@end
