//
//  JFTAtlasRenderOperationPool.m
//  JFTOperationPool
//
//  Created by jft0m on 2021/5/10.
//

#import "JFTAtlasRenderOperationPool.h"
#import "JFTAtlasRenderElement.h"
#import "JFTAtlasRenderElementOperation.h"

@implementation JFTAtlasRenderOperationPool

- (__kindof NSOperation *)createOperationWithElement:(id<JFTOperationRequestElement>)element {
    if (![element isMemberOfClass:JFTAtlasRenderElement.class]) {
        return nil;
    }
    JFTAtlasRenderElement *atlasElement = (JFTAtlasRenderElement *)element;
    return [[JFTAtlasRenderElementOperation alloc] initWithElement:atlasElement];
}

@end
