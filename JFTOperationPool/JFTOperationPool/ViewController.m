//
//  ViewController.m
//  JFTOperationPool
//
//  Created by jft0m on 2021/5/10.
//

#import "ViewController.h"
#import "JFTAtlasRenderOperationPool.h"
#import "JFTAtlasRenderElement.h"

@interface ViewController ()
@property (nonatomic) JFTAtlasRenderOperationPool *operationPool;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _operationPool = [[JFTAtlasRenderOperationPool alloc] initWithMaxConcurrentOperationCount:5];
    for (int i = 0; i < 10; i++) {
        JFTAtlasRenderElement *element = [[JFTAtlasRenderElement alloc] initWithNumber:@(2)];
        JFTOperationRequestID requestID = [_operationPool requestWithElement:element completion:^(__kindof NSOperation * _Nullable operation, JFTOperationRequestID requestID, NSError * _Nullable error) {
            NSLog(@"[%@] finish", @(requestID));
        }];
        if (i > 7) {
            NSLog(@"[%@] start", @(requestID));
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.operationPool cancelRequestWithRequestID:requestID];
            });
        }
    }
//    for (int i = 0; i < 10; i++) {
//        JFTAtlasRenderElement *element = [[JFTAtlasRenderElement alloc] initWithNumber:@(i)];
//        JFTOperationRequestID requestID = [_operationPool requestWithElement:element completion:^(__kindof NSOperation * _Nonnull operation, JFTOperationRequestID requestID) {
//            NSLog(@"[%@] finish", @(requestID));
//        }];
//        NSLog(@"[%@] start", @(requestID));
//    }
    
}

@end
