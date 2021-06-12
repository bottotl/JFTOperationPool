//
//  JFTAtlasRenderElementOperation.h
//  JFTOperationPool
//
//  Created by jft0m on 2021/5/10.
//

#import <Foundation/Foundation.h>
#import "JFTAtlasRenderElement.h"
#import "JFTOperationProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface JFTAtlasRenderElementOperation : NSOperation <JFTOperationProtocol>
- (instancetype)initWithElement:(JFTAtlasRenderElement *)element;
@property (nonatomic, nullable) NSError *error;
@end

NS_ASSUME_NONNULL_END
