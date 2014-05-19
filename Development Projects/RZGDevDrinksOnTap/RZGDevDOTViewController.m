//
//  RZGDevDOTViewController.m
//  RZGDevDrinksOnTap
//
//  Created by John Stricker on 4/27/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

#import "RZGDevDOTViewController.h"
#import "RZTwitterData.h"
#import "RZTweetData.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import "RZGBMFontHeaders.h"

static const float kRZSecondsPerTweetRequest = 6.0f;
static const float kRZSecondsBetweenDisplayedTweets = 10.0f;
static const float kRZFadeDuration = 0.2f;
static NSString * const kRZHashtagToSearchFor = @"#drinksontap";
static NSString * const kRZTwitterSearchString = @"https://api.twitter.com/1.1/search/tweets.json";

@interface RZGDevDOTViewController ()<NSURLConnectionDataDelegate>

@property (strong, nonatomic) RZTwitterData *twitterData;
@property (assign, nonatomic) double timeSinceLastTwitterCheck;
@property (assign, nonatomic) double timeCurrentTweetIsOnScreen;
@property (strong, nonatomic) ACAccount *twitterAccount;
@property (assign, nonatomic) BOOL requestInProgress;
@property (strong, nonatomic) NSURLConnection *streamingConnection;
@property (strong, nonatomic) NSMutableData *recievedData;
@property (assign, nonatomic) BOOL firstRun;
@property (strong, nonatomic) RZGBMFontModel *tweetPromptModel;
@property (strong, nonatomic) RZGBMFontModel *tweetTextModel;
@property (strong, nonatomic) RZGBMFontModel *tweetNameModel;
@property (strong, nonatomic) RZGModel *tweetPicModel;
@property (strong, nonatomic) RZGModel *dotModel;
@property (strong, nonatomic) RZGModel *dotModel2;
@property (assign, nonatomic) GLKVector3 dotModelOffScreenPos;
@property (assign, nonatomic) GLKVector3 dotModelOnScreenPos;
@property (assign, nonatomic) GLKVector3 dotModelRotationConst;
@property (assign, nonatomic) GLKVector3 promptOffScreenPos;
@property (assign, nonatomic) GLKVector3 promptOnScreenPos;
@property (assign, nonatomic) GLKVector3 tweetPicOffScreenPos;
@property (assign, nonatomic) GLKVector3 tweetPicOnScreenPos;
@property (assign, nonatomic) GLKVector3 tweetNameOffScreenPos;
@property (assign, nonatomic) GLKVector3 tweetNameOnScreenPos;
@property (assign, nonatomic) GLKVector3 tweetTextOffScreenPos;
@property (assign, nonatomic) GLKVector3 tweetTextOnScreenPos;
@property (assign, nonatomic) BOOL tweetOnScreen;
@end

@implementation RZGDevDOTViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.glmgr = [[RZGOpenGLManager alloc] initWithView:self.glkView ScreenSize:self.view.bounds.size PerspectiveInRadians:GLKMathDegreesToRadians(45.0f) NearZ:0.1f FarZ:100.0f];
    [self.glmgr setClearColor:GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f)];
    
    self.firstRun = YES;
    self.timeSinceLastTwitterCheck = 0.0;
    self.timeCurrentTweetIsOnScreen = 0.0;
    self.twitterData = [[RZTwitterData alloc] init];
    self.requestInProgress = YES;
    [self setupAccount];
    
    [self setupTweetModels];
    
    self.dotModel = [[RZGModel alloc] initWithModelFileName:@"dotMarshmellow" UseDefaultSettingsInManager:self.glmgr];
    self.dotModel.shadowMax = 0.5f;
    
    self.dotModelOnScreenPos = GLKVector3Make(0.0f, 0.15f, -2.0f);
    self.dotModelOffScreenPos = GLKVector3Make(self.dotModelOnScreenPos.x, 2.0f,self.dotModelOnScreenPos.z);
    self.dotModel.prs.position = self.dotModelOffScreenPos;
    
    self.dotModelRotationConst = GLKVector3Make(0.0f, -0.15f, 0.0f);

    [self.dotModel setTexture0Id:[RZGAssetManager loadTexture:@"dotImages2" ofType:@"png" shouldLoadWithMipMapping:YES]];
    [self.modelController addModel:self.dotModel];

    [self bringInDotModelAndPromptAfterDelay:1.0f];
}

- (void)setupTweetModels
{
    [self.glmgr loadBitmapFontShaderAndSettings];
    
    RZGBMFontData *goldFontData = [[RZGBMFontData alloc] initWithFontFile:@"dotRedFont"];
    int goldTextureId = [RZGAssetManager loadTexture:@"dotRedFont" ofType:@"png" shouldLoadWithMipMapping:YES];
    
    RZGBMFontData *whiteFontData = [[RZGBMFontData alloc] initWithFontFile:@"whiteHn"];
    int whiteTextureId = [RZGAssetManager loadTexture:@"whiteHn" ofType:@"png" shouldLoadWithMipMapping:YES];
    
    self.tweetPromptModel = [[RZGBMFontModel alloc] initWithName:@"promptText" BMfontData:whiteFontData UseGLManager:self.glmgr];
    [self.tweetPromptModel setTexture0Id:whiteTextureId];
    self.tweetPromptModel.centerHorizontal = YES;
    self.tweetPromptModel.centerVertical = YES;
    [self.tweetPromptModel setupWithCharMax:50];
    [self.tweetPromptModel updateWithText:[NSString stringWithFormat:@"tweet %@~to see your tweet here!",kRZHashtagToSearchFor]];
    
    self.promptOnScreenPos = GLKVector3Make(0.0f, -0.5f, -2.0f);
    self.promptOffScreenPos = GLKVector3Make(0.0f, -2.0f, -2.0f);
    self.tweetPromptModel.prs.position = self.promptOffScreenPos;
    
    self.tweetTextModel = [[RZGBMFontModel alloc] initWithName:@"tweetText" BMfontData:goldFontData UseGLManager:self.glmgr];
    [self.tweetTextModel setTexture0Id:goldTextureId];
    [self.tweetTextModel setupWithCharMax:200];
    self.tweetTextModel.isHidden = YES;
    self.tweetTextModel.prs.sxyz = 1.0f;
    self.tweetTextModel.maxWidth = 2.4f;
    self.tweetTextOnScreenPos = GLKVector3Make(-0.95f, 0.075f, -2.0f);
    self.tweetTextOffScreenPos = GLKVector3Make(1.5f, self.tweetTextOnScreenPos.y, self.tweetTextOnScreenPos.z);
    self.tweetTextModel.prs.position = self.tweetTextOffScreenPos;
    
    self.tweetNameModel = [[RZGBMFontModel alloc] initWithName:@"tweetNameModel" BMfontData:whiteFontData UseGLManager:self.glmgr];
    [self.tweetNameModel setTexture0Id:whiteTextureId];
    [self.tweetNameModel setupWithCharMax:200];
    self.tweetNameModel.isHidden = YES;
    self.tweetNameModel.prs.sxyz = 1.2f;
    self.tweetNameOnScreenPos = GLKVector3Make(-1.4f, 0.25f, -2.0f);
    self.tweetNameOffScreenPos = GLKVector3Make(self.tweetNameOnScreenPos.x, 1.0f, self.tweetNameOnScreenPos.z);
    self.tweetNameModel.prs.position = self.tweetNameOffScreenPos;
    
    self.tweetPicModel = [[RZGModel alloc] initWithModelFileName:@"quad" UseDefaultSettingsInManager:self.glmgr];
    self.tweetPicModel.prs.px = -6.0f;
    self.tweetPicModel.prs.pz = -10.0f;
    self.tweetPicModel.isHidden = YES;
    self.tweetPicModel.prs.py = -2.4f;
    self.tweetPicOnScreenPos = GLKVector3Make(-6.0f, 0.0f, -10.0f);
    self.tweetPicOffScreenPos = GLKVector3Make(-10.0f, self.tweetPicOnScreenPos.y, self.tweetPicOnScreenPos.z);
    self.tweetPicModel.prs.position = self.tweetPicOffScreenPos;
    
    [self.modelController addModel:self.tweetPromptModel];
    [self.modelController addModel:self.tweetTextModel];
    [self.modelController addModel:self.tweetNameModel];
    [self.modelController addModel:self.tweetPicModel];
}

- (void)bringInDotModelAndPromptAfterDelay:(CGFloat)delay
{
    self.dotModel.prs.position = self.dotModelOffScreenPos;
    self.dotModel.isHidden = NO;
    [self.dotModel.prs removeRotationConstant];
    [self.dotModel addCommand:[RZGCommand commandWithEnum:kRZGCommand_moveTo Target:GLKVector4MakeWithVec3(self.dotModelOnScreenPos) Duration:1.0f IsAbsolute:YES Delay:delay]];
    [self.dotModel addCommand:[RZGCommand commandWithEnum:kRZGCommand_setConstantRotation Target:GLKVector4MakeWithVec3(self.dotModelRotationConst) Duration:0.0f IsAbsolute:YES Delay:delay+2.0f]];
    
    self.tweetPromptModel.prs.position = self.promptOffScreenPos;
    [self.tweetPromptModel addCommand:[RZGCommand commandWithEnum:kRZGCommand_moveTo Target:GLKVector4MakeWithVec3(self.promptOnScreenPos) Duration:1.0f IsAbsolute:YES Delay:delay]];
}

- (void)hideDotModelAndPrompt
{
    [self.dotModel addCommand:[RZGCommand commandWithEnum:kRZGCommand_moveTo Target:GLKVector4MakeWithVec3(self.dotModelOffScreenPos) Duration:1.0f IsAbsolute:YES Delay:0.0f]];
    [self.tweetPromptModel addCommand:[RZGCommand commandWithEnum:kRZGCommand_moveTo Target:GLKVector4MakeWithVec3(self.promptOffScreenPos) Duration:1.0f IsAbsolute:YES Delay:0.0f]];
}

- (void)showTweetAfterDelay:(GLfloat)delay
{
    self.tweetPicModel.prs.position = self.tweetPicOffScreenPos;
    self.tweetPicModel.isHidden = NO;
    self.tweetTextModel.prs.position = self.tweetTextOffScreenPos;
    self.tweetTextModel.isHidden = NO;
    self.tweetNameModel.prs.position = self.tweetNameOffScreenPos;
    self.tweetNameModel.isHidden = NO;
    
    [self.tweetPicModel addCommand:[RZGCommand commandWithEnum:kRZGCommand_moveTo Target:GLKVector4MakeWithVec3(self.tweetPicOnScreenPos) Duration:1.0f IsAbsolute:YES Delay:delay]];
    [self.tweetNameModel addCommand:[RZGCommand commandWithEnum:kRZGCommand_moveTo Target:GLKVector4MakeWithVec3(self.tweetNameOnScreenPos) Duration:1.0f IsAbsolute:YES Delay:delay]];
    [self.tweetTextModel addCommand:[RZGCommand commandWithEnum:kRZGCommand_moveTo Target:GLKVector4MakeWithVec3(self.tweetTextOnScreenPos) Duration:1.0f IsAbsolute:YES Delay:delay]];
}

- (void)hideTweet
{
    [self.tweetPicModel addCommand:[RZGCommand commandWithEnum:kRZGCommand_moveTo Target:GLKVector4MakeWithVec3(self.tweetPicOffScreenPos) Duration:1.0f IsAbsolute:YES Delay:0.0f]];
    [self.tweetNameModel addCommand:[RZGCommand commandWithEnum:kRZGCommand_moveTo Target:GLKVector4MakeWithVec3(self.tweetNameOffScreenPos) Duration:1.0f IsAbsolute:YES Delay:0.0f]];
    [self.tweetTextModel addCommand:[RZGCommand commandWithEnum:kRZGCommand_moveTo Target:GLKVector4MakeWithVec3(self.tweetTextOffScreenPos) Duration:1.0f IsAbsolute:YES Delay:0.0f]];
}


- (void)setupAccount
{
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    [accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error){
        if (granted) {
            
            NSArray *accounts = [accountStore accountsWithAccountType:accountType];
            
            // Check if the users has setup at least one Twitter account
            
            if (accounts.count > 0) {
                self.twitterAccount = [accounts objectAtIndex:0];
                [self startStreamForHashtag:@"twitter" withMinIntString:@"0"];
            }
        }
    }];
}

- (void)startStreamForHashtag:(NSString*)hashTag withMinIntString:(NSString*)minIntString
{
    self.requestInProgress = YES;
    
    NSDictionary *params = @{@"q" : hashTag, @"since_id":minIntString, @"include_rts" : @"0", @"resultType" : @"recent"};
    
    SLRequest *twitterInfoRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:kRZTwitterSearchString] parameters:params];
    [twitterInfoRequest setAccount:self.twitterAccount];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.streamingConnection = [NSURLConnection connectionWithRequest:[twitterInfoRequest preparedURLRequest] delegate:self];
        [self.streamingConnection start];
    });
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if(data) {
        
        if(!self.recievedData) {
            self.recievedData = [NSMutableData data];
        }
        
        [self.recievedData appendData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if(self.recievedData)
    {
        NSError *error;
        NSDictionary *dataDict = [NSJSONSerialization JSONObjectWithData:self.recievedData options:NSJSONReadingMutableLeaves error:&error];
        
        if(dataDict) {
            [self generateTweetsFromDictionary:dataDict];
        }
    }
    self.recievedData = nil;
    self.requestInProgress = NO;
}

- (void)generateTweetsFromDictionary:(NSDictionary *)dataDict
{
    NSDictionary *metaData = dataDict[@"search_metadata"];
    
    NSString *maxInt = [NSString stringWithFormat:@"%@",[metaData[@"max_id"] stringValue]];
    if(maxInt) {
        self.twitterData.lastMaxIdIntAsString = maxInt;
    }
    
    if (self.firstRun) {
        self.firstRun = NO;
    }
    else {
        NSArray *statuses = dataDict[@"statuses"];
        
        for (NSDictionary *status in statuses) {
            
        //    NSLog(@"%@ - %@", [status objectForKey:@"text"], [[status objectForKey:@"user"] objectForKey:@"screen_name"]);
            NSDictionary *userDict = [status objectForKey:@"user"];
            
            NSString *name = userDict[@"name"];
            NSString *screenName = userDict[@"screen_name"];
            NSString *text = status[@"text"];
            NSString *imageURL = userDict[@"profile_image_url"];
            imageURL = [imageURL stringByReplacingOccurrencesOfString:@"_normal" withString:@"_bigger"];
            
            [self.twitterData.loadedTweets addObject:[RZTweetData tweetDataWithName:name screenName:screenName statusText:text profileImageURLString:imageURL]];
        }
    }
}

- (void)loadNextTweetAfterDelay:(double)delay
{
    RZTweetData *tweet = [self.twitterData nextTweet];
    
    if(tweet) {
        self.tweetOnScreen = YES;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.tweetPicModel setTexture0Id:[RZGAssetManager loadTextureFromUrl:[NSURL URLWithString:tweet.profileImageUrlString] shouldLoadWithMipMapping:NO]];
            [self.tweetTextModel updateWithText:tweet.statusText];
            [self.tweetNameModel updateWithText:tweet.screenName];
        });
    }
}

- (void)fadePromptToAlpha:(GLfloat)alpha WithDelay:(GLfloat)delay
{
    [self.tweetPromptModel addCommand:[[RZGCommand alloc] initWithCommandEnum:kRZGCommand_alpha Target:GLKVector4MakeWith1f(alpha) Duration:kRZFadeDuration IsAbsolute:YES Delay:delay]];
}

- (void)fadeTweetToAlpha:(GLfloat)alpha WithDelay:(GLfloat)delay
{
    [self.tweetPicModel addCommand:[[RZGCommand alloc] initWithCommandEnum:kRZGCommand_alpha Target:GLKVector4MakeWith1f(alpha) Duration:kRZFadeDuration IsAbsolute:YES Delay:delay]];
    [self.tweetNameModel addCommand:[[RZGCommand alloc] initWithCommandEnum:kRZGCommand_alpha Target:GLKVector4MakeWith1f(alpha) Duration:kRZFadeDuration IsAbsolute:YES Delay:delay]];
    [self.tweetTextModel addCommand:[[RZGCommand alloc] initWithCommandEnum:kRZGCommand_alpha Target:GLKVector4MakeWith1f(alpha) Duration:kRZFadeDuration IsAbsolute:YES Delay:delay]];
}

- (void)update
{
    [super update];
    
    self.timeSinceLastTwitterCheck += self.timeSinceLastUpdate;
    if(self.timeSinceLastTwitterCheck >= kRZSecondsPerTweetRequest){
        self.timeSinceLastTwitterCheck = 0.0;
        [self startStreamForHashtag:kRZHashtagToSearchFor withMinIntString:self.twitterData.lastMaxIdIntAsString];
    }
    
    self.timeCurrentTweetIsOnScreen += self.timeSinceLastUpdate;
    if(self.timeCurrentTweetIsOnScreen >= kRZSecondsBetweenDisplayedTweets){
        self.timeCurrentTweetIsOnScreen = 0.0;
        if([self.twitterData.loadedTweets count] > 0) {
            if(self.tweetOnScreen) {
                [self hideTweet];
            }
            else {
                [self hideDotModelAndPrompt];
            }
            [self loadNextTweetAfterDelay:1.0f];
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.75f * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
              [self showTweetAfterDelay:0.0f];
            });
           
        }
        else if(self.tweetOnScreen)
        {
            [self hideTweet];
            self.tweetOnScreen = NO;
            [self bringInDotModelAndPromptAfterDelay:1.0f];
        }
    }
    
}


@end
