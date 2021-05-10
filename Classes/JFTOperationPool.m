//
//  JFTOperationPool.m
//  JFTOperationPool
//
//  Created by jft0m on 2021/5/10.
//

#import "JFTOperationPool.h"



@interface JFTOperationPool ()

/// 串型队列，用来处理数据
@property (nonatomic) NSOperationQueue *dataQueue;

@property (nonatomic) NSOperationQueue *requestQueue;

@property (nonatomic) NSOperationQueue *outQueue;

/// 对外暴露的请求 id，RequestID 和 NSOperation 是多对一关系
@property (nonatomic) JFTOperationRequestID lastRequestID;

@property (nonatomic) id<JFTOperationRequestCreator> operationCreator;

/// cache key --> NSOperation
@property (nonatomic) NSMapTable<NSString *, NSOperation *> *cacheKeyToOperationsMapTable;

/// requestID -->  NSOperation
/// 当没有 requestID 对 NSOperation 引用以后，真正执行 [NSOperation cancel];
@property (nonatomic) NSMapTable<NSNumber *, NSOperation *> *requestIdToOperationsMapTable;

/// requestID --> Completion
@property (nonatomic) NSMutableDictionary<NSNumber *, JFTOperationCompletion> *completions;

@end

@implementation JFTOperationPool

- (instancetype)initWithMaxConcurrentOperationCount:(NSInteger)maxConcurrentOperationCount {
    if (self = [super init]) {
        _dataQueue = [NSOperationQueue new];
        _dataQueue.name = @"com.jft0m.operation.data";
        _dataQueue.maxConcurrentOperationCount = 1;
        
        _outQueue = [NSOperationQueue new];
        _outQueue.name = @"com.jft0m.operation.out";
        
        _requestQueue = [NSOperationQueue new];
        _requestQueue.name = @"com.jft0m.operation.request";
        _requestQueue.maxConcurrentOperationCount = maxConcurrentOperationCount;
        
        _cacheKeyToOperationsMapTable = [NSMapTable strongToWeakObjectsMapTable];
        _requestIdToOperationsMapTable = [NSMapTable strongToWeakObjectsMapTable];
        _completions = [NSMutableDictionary new];
    }
    return self;
}

- (JFTOperationRequestID)requestWithElement:(id<JFTOperationRequestElement>)element completion:(JFTOperationCompletion)completion {
    JFTOperationRequestID requestID = [self makeRequestID];
    [self.dataQueue addOperationWithBlock:^{
        [self.completions setObject:completion forKey:@(requestID)];
        [self createOperationIfNeededWithElement:element requestID:requestID];
    }];
    return requestID;
}

- (void)cancelRequestWithRequestID:(JFTOperationRequestID)requestID {
    NSLog(@"[%@] cancel", @(requestID));
    [self.dataQueue addOperationWithBlock:^{
        NSDictionary<NSNumber *, NSOperation *> *dic = self.requestIdToOperationsMapTable.dictionaryRepresentation;
        __block int refCount = 0;
        [dic enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, NSOperation * _Nonnull obj, BOOL * _Nonnull stop) {
            if ([key isEqual:@(requestID)]) {
                refCount++;
            }
        }];
        if (refCount == 1) {
            // 本次移除以后，没有 requestID 对 operation 进行引用，这时候才需要真正执行 cancel
            // 反之，只需要移除引用即可
            NSOperation *operation = dic[@(requestID)];
            [operation cancel];
            NSLog(@"[%@] real cancel", @(requestID));
        }
        [self.requestIdToOperationsMapTable removeObjectForKey:@(requestID)];
        NSLog(@"[%@] did cancel", @(requestID));
    }];
}

- (JFTOperationRequestID)makeRequestID {
    JFTOperationRequestID requestID = JFTInvalidImageRequestID;
    @synchronized (self) {
        requestID = self.lastRequestID++;
    }
    return requestID;
}

- (NSMapTable *)cacheKeyToOperationsMapTable {
    NSAssert([NSOperationQueue currentQueue] == self.dataQueue, @"must call in dataQueue");
    return _cacheKeyToOperationsMapTable;
}

- (NSMapTable *)requestIdToOperationsMapTable {
    NSAssert([NSOperationQueue currentQueue] == self.dataQueue, @"must call in dataQueue");
    return _requestIdToOperationsMapTable;
}

- (NSOperation *)operationWithElement:(id<JFTOperationRequestElement>)element {
    NSAssert([NSOperationQueue currentQueue] == self.dataQueue, @"must call in dataQueue");
    
    NSString *cacheKey = [element cacheKey];
    
    NSOperation *operation = [self cachedOperation:cacheKey];
    if (!operation) {
        operation = [self createOperationWithElement:element];
        [self.cacheKeyToOperationsMapTable setObject:operation forKey:cacheKey];
        __weak typeof(operation) weakOperation = operation;
        __weak typeof(self) weakSelf = self;
        operation.completionBlock = ^{
            [weakSelf didFinishOperation:weakOperation];
        };
        [self.requestQueue addOperation:operation];
    }
    return operation;
}

- (NSOperation *)cachedOperation:(NSString *)cacheKey {
    NSAssert([NSOperationQueue currentQueue] == self.dataQueue, @"must call in dataQueue");
    return [self.cacheKeyToOperationsMapTable objectForKey:cacheKey];
}

- (void)createOperationIfNeededWithElement:(id<JFTOperationRequestElement>)element requestID:(JFTOperationRequestID)requestID {
    NSAssert([NSOperationQueue currentQueue] == self.dataQueue, @"must call in dataQueue");
    NSOperation *operation = [self operationWithElement:element];
    if (operation.isFinished) {
        NSLog(@"[%@]该任务已经完成，无需执行直接回调", @(requestID));
        [self executeCompletions:operation];
        return;
    }
    if (!operation) {
        NSParameterAssert(operation);
    } else {
        [self.requestIdToOperationsMapTable setObject:operation forKey:@(requestID)];
    }
}

- (__kindof NSOperation *)createOperationWithElement:(id<JFTOperationRequestElement>)element {
    NSAssert(NO, @"子类必须覆写");
    return nil;
}

- (void)didFinishOperation:(NSOperation *)operation {
    __weak typeof(self) weakSelf = self;
    [self.dataQueue addOperationWithBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf executeCompletions:operation];
    }];
}

- (void)executeCompletions:(NSOperation *)operation {
    NSSet<NSNumber *> *requestIDSetForOperation = [self requestIDSetForOperation:operation];
    [self.completions enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, JFTOperationCompletion  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([requestIDSetForOperation containsObject:key]) {
            [self.outQueue addOperationWithBlock:^{
                obj(operation, key.intValue);
            }];
        }
    }];
    [self.completions removeObjectsForKeys:requestIDSetForOperation.allObjects];
}

- (NSSet<NSNumber *> *)requestIDSetForOperation:(NSOperation *)operation {
    NSAssert([NSOperationQueue currentQueue] == self.dataQueue, @"must call in dataQueue");
    NSDictionary *dic = [self.requestIdToOperationsMapTable dictionaryRepresentation];
    NSMutableOrderedSet<NSNumber *> *orderedSet = [NSMutableOrderedSet new];
    [dic enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj == operation) {
            [orderedSet addObject:key];
        }
    }];
    [orderedSet sortUsingComparator:^NSComparisonResult(NSNumber * _Nonnull obj1, NSNumber * _Nonnull obj2) {
        if (obj1.intValue < obj2.intValue) {
            return NSOrderedAscending;
        } else if (obj1.intValue > obj2.intValue) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
    return orderedSet.set;
}

@end
