//
//  JFTAtlasRenderElement.m
//  JFTOperationPool
//
//  Created by jft0m on 2021/5/10.
//

#import "JFTAtlasRenderElement.h"

@interface JFTAtlasRenderElement ()
@property (nonatomic) NSNumber *num;
@end

@implementation JFTAtlasRenderElement

- (instancetype)initWithNumber:(NSNumber *)num {
    if (self = [super init]) {
        _num = num;
    }
    return self;
}

- (NSString *)cacheKey {
    return self.num.stringValue;
}

@end

