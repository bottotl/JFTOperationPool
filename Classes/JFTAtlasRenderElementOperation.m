//
//  JFTAtlasRenderElementOperation.m
//  JFTOperationPool
//
//  Created by jft0m on 2021/5/10.
//

#import "JFTAtlasRenderElementOperation.h"

@interface JFTAtlasRenderElementOperation ()
@property (nonatomic) JFTAtlasRenderElement *element;
@end

@implementation JFTAtlasRenderElementOperation

- (instancetype)initWithElement:(JFTAtlasRenderElement *)element {
    if (self = [super init]) {
        _element = element;
    }
    return self;
}

- (void)main {
    if ([self isCancelled]) {
        return;
    }
    NSLog(@"start render %@", self.element.cacheKey);
    [NSThread sleepForTimeInterval:0.5];
    NSLog(@"end render %@", self.element.cacheKey);
}

@end
