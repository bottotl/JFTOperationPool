//
//  JFTOperationPool.m
//  JFTOperationPool
//
//  Created by jft0m on 2021/5/10.
//

#import "JFTOperationPool.h"

#if defined(__cplusplus)
#define let auto const
#else
#define let const __auto_type
#endif

@interface JFTOperationPool ()

/// 串型队列，用来处理数据
@property (nonatomic) NSOperationQueue *dataQueue;

@property (nonatomic) NSOperationQueue *requestQueue;

@property (nonatomic) NSOperationQueue *outQueue;

/// 对外暴露的请求 id，RequestID 和 NSOperation 是多对一关系
@property (nonatomic) JFTOperationRequestID lastRequestID;

/// cache key --> NSOperation
@property (nonatomic) NSMapTable<NSString *, NSOperation<JFTOperationProtocol> *> *cacheKeyToOperationsMapTable;

/// requestID -->  NSOperation
/// 当没有 requestID 对 NSOperation 引用以后，真正执行 [NSOperation cancel];
@property (nonatomic) NSMapTable<NSNumber *, NSOperation<JFTOperationProtocol> *> *requestIdToOperationsMapTable;

/// requestID --> Completion
/// 回调执行时机分为三种情况：
///     1. 请求发出的时候任务已经成功
///     2. 任务执行完毕后回调 - NSOperation.completionBlock 调用的时候回调
///     3. 任务被取消 - cancel 被调用的时候
@property (nonatomic) NSMutableDictionary<NSNumber *, JFTOperationCompletion> *completions;

#if DEBUG || DETA
@property (nonatomic) NSMutableSet<NSNumber *> *cancelledRequest;
@property (nonatomic) NSMutableSet<NSNumber *> *finishedRequest;
#endif

@end

@implementation JFTOperationPool

- (instancetype)initWithRequestOperationQueue:(NSOperationQueue *)queue {
    if (self = [super init]) {
        _requestQueue = queue;
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithMaxConcurrentOperationCount:(NSInteger)maxConcurrentOperationCount {
    if (self = [super init]) {
        _requestQueue = [NSOperationQueue new];
        _requestQueue.name = @"com.jft0m.operation.request";
        _requestQueue.maxConcurrentOperationCount = maxConcurrentOperationCount;
        [self commonInit];
        
        #if DEBUG || DETA
        _cancelledRequest = [NSMutableSet new];
        _finishedRequest = [NSMutableSet new];
        #endif
    }
    return self;
}

- (void)commonInit {
    _dataQueue = [NSOperationQueue new];
    _dataQueue.name = @"com.jft0m.operation.data";
    _dataQueue.maxConcurrentOperationCount = 1;
    
    _outQueue = [NSOperationQueue new];
    _outQueue.name = @"com.jft0m.operation.out";
    
    _cacheKeyToOperationsMapTable = [NSMapTable strongToWeakObjectsMapTable];
    _requestIdToOperationsMapTable = [NSMapTable strongToWeakObjectsMapTable];
    _completions = [NSMutableDictionary new];
}

- (JFTOperationRequestID)requestWithElement:(id<JFTOperationRequestElement>)element completion:(JFTOperationCompletion)completion {
    JFTOperationRequestID requestID = [self makeRequestID];
    NSLog(@"[completion][%@] commit request - %@", @(requestID), element.cacheKey);
    [self.dataQueue addOperationWithBlock:^{
        [self.completions setObject:completion forKey:@(requestID)];
        [self createOperationIfNeededWithElement:element requestID:requestID];
    }];
    return requestID;
}

- (void)cancelRequestWithRequestID:(JFTOperationRequestID)requestID {
    [self.dataQueue addOperationWithBlock:^{
        NSDictionary<NSNumber *, NSOperation *> *dic = self.requestIdToOperationsMapTable.dictionaryRepresentation;
        __block int refCount = 0;
        let requestIDKey = @(requestID);
        NSLog(@"[completion][%@] - %@", requestIDKey, dic);
        NSOperation *operation = dic[requestIDKey];
        BOOL isFinished = operation.isFinished;
        BOOL isCancelled = operation.isCancelled;
        if (isFinished || isCancelled) {
            NSLog(@"[completion][%@] cancel a %@ operation, 本次取消逻辑无效", isFinished ? @"finished" : @"cancelled" , requestIDKey);
            return;
        }
        [dic enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, NSOperation * _Nonnull obj, BOOL * _Nonnull stop) {
            if ([operation isEqual:obj]) {
                refCount++;
                NSLog(@"[completion][%@] refCount++", requestIDKey);
            }
        }];
        if (refCount == 1) {
            // 本次移除以后，没有 requestID 对 operation 进行引用，这时候才需要真正执行 cancel
            // 反之，只需要移除引用即可
            NSOperation *operation = dic[requestIDKey];
            [operation cancel];
            NSLog(@"[completion][%@] real cancel, completion will be executed after operation completionBlock called", requestIDKey);
            return;
        }
        [self.requestIdToOperationsMapTable removeObjectForKey:requestIDKey];
        JFTOperationCompletion completion = self.completions[requestIDKey];
        self.completions[requestIDKey] = nil;
        if (completion) {
            #if DEBUG || DETA
            if ([self.finishedRequest containsObject:requestIDKey]) {
                NSAssert(NO, @"重复回调");
            }
            [self.cancelledRequest addObject:requestIDKey];
            #endif
            
            NSLog(@"[completion][%@] fake cancel, completion will be executed", requestIDKey);
            [self.outQueue addOperationWithBlock:^{
                completion(nil, requestID, [NSError errorWithDomain:@"com.jft0m.operation.pool"
                                                               code:-1
                                                           userInfo:@{ NSLocalizedDescriptionKey : @"cancel request" }]);
                NSLog(@"[completion][%@] cancel request did called", requestIDKey);
            }];
        }
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

- (NSOperation<JFTOperationProtocol> *)operationWithElement:(id<JFTOperationRequestElement>)element {
    NSAssert([NSOperationQueue currentQueue] == self.dataQueue, @"must call in dataQueue");
    
    NSString *cacheKey = [element cacheKey];
    
    NSOperation<JFTOperationProtocol> *operation = [self cachedOperation:cacheKey];
    if (!operation || operation.error || operation.cancelled) {
        operation = [self createOperationWithElement:element];
        [self.cacheKeyToOperationsMapTable setObject:operation forKey:cacheKey];
        __weak typeof(operation) weakOperation = operation;
        __weak typeof(self) weakSelf = self;
        operation.completionBlock = ^{
            [weakSelf didFinishOperation:weakOperation];
        };
        [self.requestQueue addOperation:operation];
    } else {
        NSLog(@"[completion] 任务成功复用 - %@", self.cacheKeyToOperationsMapTable);
    }
    
    return operation;
}

- (NSOperation<JFTOperationProtocol> *)cachedOperation:(NSString *)cacheKey {
    NSAssert([NSOperationQueue currentQueue] == self.dataQueue, @"must call in dataQueue");
    return [self.cacheKeyToOperationsMapTable objectForKey:cacheKey];
}

- (void)createOperationIfNeededWithElement:(id<JFTOperationRequestElement>)element requestID:(JFTOperationRequestID)requestID {
    NSAssert([NSOperationQueue currentQueue] == self.dataQueue, @"must call in dataQueue");
    NSOperation<JFTOperationProtocol> *operation = [self operationWithElement:element];
    if (!operation) {
        NSParameterAssert(operation);
    } else {
        [self.requestIdToOperationsMapTable setObject:operation forKey:@(requestID)];
    }
    NSLog(@"[completion][%@] create operation %@", @(requestID), operation);
    if (operation.isFinished || operation.isCancelled) {
        NSLog(@"[completion][%@] 该任务已经完成，无需执行直接回调", @(requestID));
        [self executeCompletions:operation];
    }
}

- (__kindof NSOperation *)createOperationWithElement:(id<JFTOperationRequestElement>)element {
    NSAssert(NO, @"子类必须覆写");
    return nil;
}

- (void)didFinishOperation:(NSOperation<JFTOperationProtocol> *)operation {
    __weak typeof(self) weakSelf = self;
    [self.dataQueue addOperationWithBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf executeCompletions:operation];
    }];
}

- (void)executeCompletions:(NSOperation<JFTOperationProtocol> *)operation {
    NSSet<NSNumber *> *requestIDSetForOperation = [self requestIDSetForOperation:operation];
    [self.completions enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, JFTOperationCompletion  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([requestIDSetForOperation containsObject:key]) {
            #if DEBUG || DETA
            if ([_cancelledRequest containsObject:key]) {
                NSAssert(NO, @"重复回调");
            }
            [_finishedRequest addObject:key];
            #endif
            
            [self.outQueue addOperationWithBlock:^{
                obj(operation, key.intValue, [operation error]);
                NSLog(@"[completion][%@] finish request", key);
            }];
        }
    }];
    [self.completions removeObjectsForKeys:requestIDSetForOperation.allObjects];
}

- (NSSet<NSNumber *> *)requestIDSetForOperation:(NSOperation<JFTOperationProtocol> *)operation {
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
