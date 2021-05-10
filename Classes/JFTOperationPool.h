//
//  JFTOperationPool.h
//  JFTOperationPool
//
//  Created by jft0m on 2021/5/10.
//

#import <Foundation/Foundation.h>
#import "JFTOperationRequestElement.h"
#import "JFTOperationRequestCreator.h"

NS_ASSUME_NONNULL_BEGIN

typedef int32_t JFTOperationRequestID;

static const JFTOperationRequestID JFTInvalidImageRequestID = 0;

typedef void(^JFTOperationCompletion)(__kindof NSOperation *operation, JFTOperationRequestID requestID);

/// 任务复用管理器
@interface JFTOperationPool : NSObject

- (instancetype)initWithMaxConcurrentOperationCount:(NSInteger)maxConcurrentOperationCount;

- (JFTOperationRequestID)requestWithElement:(id<JFTOperationRequestElement>)element completion:(JFTOperationCompletion)completion;

- (void)cancelRequestWithRequestID:(JFTOperationRequestID)requestID;

- (__kindof NSOperation *)createOperationWithElement:(id<JFTOperationRequestElement>)element;

@end

NS_ASSUME_NONNULL_END
