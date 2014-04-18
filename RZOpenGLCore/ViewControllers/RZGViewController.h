//
//  RZGViewController.h
//  RZGLCoreDevelopemnt
//
//  Created by John Stricker on 4/17/14.
//  Copyright (c) 2014 John Stricker. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RZGOpenGLManager.h"
#import "RZGModelController.h"

@interface RZGViewController : UIViewController

@property (strong, nonatomic) RZGOpenGLManager *glmgr;
@property (strong, nonatomic) RZGModelController *modelController;
@property (strong, nonatomic) GLKView *glkView;
@property (assign, nonatomic, readonly) CFTimeInterval timeSinceLastUpdate;
@property (assign, nonatomic, readonly) BOOL isPaused;
@property (assign, nonatomic) BOOL paused;

@end
