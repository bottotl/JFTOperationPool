//
//  JFTAtlasRenderElement.h
//  JFTOperationPool
//
//  Created by jft0m on 2021/5/10.
//

#import <Foundation/Foundation.h>
#import "JFTOperationRequestElement.h"

NS_ASSUME_NONNULL_BEGIN

@interface JFTAtlasRenderElement : NSObject <JFTOperationRequestElement>
- (instancetype)initWithNumber:(NSNumber *)num;
@end

NS_ASSUME_NONNULL_END
