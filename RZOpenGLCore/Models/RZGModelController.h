//
//  RZGModelController.h
//  RZOpenGLCoreDevelopment
//
//  Created by John Stricker on 4/17/14.
//  Copyright (c) 2014 John Stricker. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RZGOpenGLManager.h"

@class RZGModel;
@class RZGCommand;

@interface RZGModelController : NSObject

- (void)addModel:(RZGModel *)model;
- (void)addCommandToAllModels:(RZGCommand *)command;
- (void)updateWithTime:(CFTimeInterval)time;
- (void)draw;

@end
