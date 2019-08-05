//
//  CustomPositionIconImage.m
//  MapKitTest
//
//  Created by apple on 2019/8/2.
//  Copyright © 2019 apple. All rights reserved.
//

#import "CustomPositionIconImage.h"

#define kWidth  40.f
#define kHeight 40.f

#define kHoriMargin 0.f
#define kVertMargin 0.f

#define kPortraitWidth  40.f
#define kPortraitHeight 40.f

@interface CustomPositionIconImage ()

@property (nonatomic, strong) UIImageView *portraitImageView;

@end

@implementation CustomPositionIconImage

@synthesize portraitImageView  = _portraitImageView;

- (UIImage *)portrait {
    return self.portraitImageView.image;
}

- (void)setPortrait:(UIImage *)portrait {
    self.portraitImageView.image = portrait;
}

#pragma mark - Life Cycle

- (id)initWithAnnotation:(id<MAAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    
    if (self) {
        self.bounds = CGRectMake(0.f, 0.f, kWidth, kHeight);
        
        //self.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:1.0];
        
        /* Create portrait image view and add to view hierarchy. */
        self.portraitImageView = [[UIImageView alloc] initWithFrame:CGRectMake(kHoriMargin, kVertMargin, kPortraitWidth, kPortraitHeight)];
        [self addSubview:self.portraitImageView];
        
        
        //创建动画
        CAKeyframeAnimation * keyAnimaion = [CAKeyframeAnimation animation];
        keyAnimaion.keyPath = @"transform.rotation";
        keyAnimaion.values = @[@(-1 / 180.0 * M_PI),@(1 /180.0 * M_PI),@(-1/ 180.0 * M_PI)];//度数转弧度
        
        keyAnimaion.removedOnCompletion = NO;
        keyAnimaion.fillMode = kCAFillModeForwards;
        keyAnimaion.duration = 0.8;
        keyAnimaion.repeatCount = 1;
        [self.portraitImageView.layer addAnimation:keyAnimaion forKey:nil];
    }
    return self;
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
