//
//  JFTAtlasRenderElementOperation.h
//  JFTOperationPool
//
//  Created by jft0m on 2021/5/10.
//

#import <Foundation/Foundation.h>
#import "JFTAtlasRenderElement.h"

NS_ASSUME_NONNULL_BEGIN

@interface JFTAtlasRenderElementOperation : NSOperation
- (instancetype)initWithElement:(JFTAtlasRenderElement *)element;
@end

NS_ASSUME_NONNULL_END
