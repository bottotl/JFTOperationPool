//
//  JFTOperationPool.h
//  JFTOperationPool
//
//  Created by jft0m on 2021/5/10.
//

#import <Foundation/Foundation.h>
#import "JFTOperationRequestElement.h"
#import "JFTOperationProtocol.h"

NS_ASSUME_NONNULL_BEGIN

typedef int32_t JFTOperationRequestID;

static const JFTOperationRequestID JFTInvalidImageRequestID = 0;

typedef void(^JFTOperationCompletion)(__kindof NSOperation *_Nullable operation, JFTOperationRequestID requestID, NSError *_Nullable error);

/// 任务复用管理器
@interface JFTOperationPool : NSObject

- (instancetype)initWithMaxConcurrentOperationCount:(NSInteger)maxConcurrentOperationCount;
- (instancetype)initWithRequestOperationQueue:(NSOperationQueue *)queue;

- (JFTOperationRequestID)requestWithElement:(id<JFTOperationRequestElement>)element completion:(JFTOperationCompletion)completion;

- (void)cancelRequestWithRequestID:(JFTOperationRequestID)requestID;

- (__kindof NSOperation<JFTOperationProtocol> *)createOperationWithElement:(id<JFTOperationRequestElement>)element;

@end

NS_ASSUME_NONNULL_END
