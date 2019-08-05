//
//  CustomAnnotationView.m
//  CustomAnnotationDemo
//
//  Created by songjian on 13-3-11.
//  Copyright (c) 2013年 songjian. All rights reserved.
//

#import "CustomAnnotationView.h"

#import "CustomCalloutView.h"

#define kWidth  40.f
#define kHeight 40.f

#define kHoriMargin 5.f
#define kVertMargin 5.f

#define kPortraitWidth  30.f
#define kPortraitHeight 30.f

#define kCalloutWidth   120.0
#define kCalloutHeight  70.0

@interface CustomAnnotationView ()

@property (nonatomic, strong) UIImageView *portraitImageView;
@property (nonatomic, strong) UILabel *nameLabel;
// 导航按钮
@property (nonatomic, strong) UIButton *naviButton;

@end

@implementation CustomAnnotationView

@synthesize calloutView;
@synthesize portraitImageView   = _portraitImageView;
@synthesize nameLabel           = _nameLabel;


#pragma mark - Handle Action
- (void)btnAction {
    
    CLLocationCoordinate2D coorinate = [self.annotation coordinate];
    
    NSLog(@"coordinate = {%f, %f}", coorinate.latitude, coorinate.longitude);
    // 进入导航页
    if (_delegate && [_delegate respondsToSelector:@selector(pushNaviDriveControllerBy:)]) {
        [_delegate pushNaviDriveControllerBy:coorinate];
    }
    
}


#pragma mark - Override
- (NSString *)name {
    return self.nameLabel.text;
}


- (void)setName:(NSString *)name
{
    self.nameLabel.text = name;
}


- (UIImage *)portrait
{
    return self.portraitImageView.image;
}


- (void)setPortrait:(UIImage *)portrait
{
    self.portraitImageView.image = portrait;
}


- (void)setSelected:(BOOL)selected {
    [self setSelected:selected animated:NO];
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    
    if (self.selected == selected)
    {
        return;
    }
    
    NSLog(@"selected == %d",selected);
    
    if (selected)
    {
        if (self.calloutView == nil)
        {
            /* Construct custom callout. */
            self.calloutView = [[CustomCalloutView alloc] initWithFrame:CGRectMake(0, 0, kCalloutWidth, kCalloutHeight)];
            self.calloutView.center = CGPointMake(CGRectGetWidth(self.bounds) / 2.f + self.calloutOffset.x,
                                                  -CGRectGetHeight(self.calloutView.bounds) / 2.f + self.calloutOffset.y);
            
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
            btn.frame = CGRectMake(10, 10, 40, 40);
            //[btn setTitle:@"Test" forState:UIControlStateNormal];
            [btn setImage:[UIImage imageNamed:@"navi"] forState:UIControlStateNormal];
            [btn setTitleColor:[UIColor redColor] forState:UIControlStateHighlighted];
            [btn setBackgroundColor:[UIColor whiteColor]];
            [btn addTarget:self action:@selector(btnAction) forControlEvents:UIControlEventTouchUpInside];
            self.naviButton = btn;
            
            [self.calloutView addSubview:btn];
            
            UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(60, 10, 120, 30)];
            name.backgroundColor = [UIColor clearColor];
            name.textColor = [UIColor whiteColor];
            name.text = @"去导航!";
            [self.calloutView addSubview:name];
        }
        
        [self addSubview:self.calloutView];
    } else {
        
        if (self.calloutView != nil) {
            NSLog(@"selectAnnotation == %d",self.selectAnnotation);
//            [self addSubview:self.calloutView];
//            [self bringSubviewToFront:self.calloutView];
//            self.calloutView.center = CGPointMake(CGRectGetWidth(self.bounds) / 2.f + self.calloutOffset.x,
//                                                  -CGRectGetHeight(self.calloutView.bounds) / 2.f + self.calloutOffset.y);
        }
        
        if (self.selectAnnotation == YES) {
            selected = YES;
        } else {
            selected = NO;
        }
        
        //[self.calloutView removeFromSuperview];
        
    }
    
    [super setSelected:selected animated:animated];
    
}



- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    BOOL inside = [super pointInside:point withEvent:event];
    /* Points that lie outside the receiver’s bounds are never reported as hits,
     even if they actually lie within one of the receiver’s subviews.
     This can occur if the current view’s clipsToBounds property is set to NO and the affected subview extends beyond the view’s bounds.
     */
    NSLog(@"selectedselected == %d",self.selected);
    if (!inside && self.selected && self.calloutView != nil)
    {
        inside = [self.calloutView pointInside:[self convertPoint:point toView:self.calloutView] withEvent:event];
    }
    
    return inside;
}



#pragma mark - Life Cycle

- (id)initWithAnnotation:(id<MAAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    
    if (self) {
        self.bounds = CGRectMake(0.f, 0.f, kWidth, kHeight);
        
        self.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:1.0];
        
        /* Create portrait image view and add to view hierarchy. */
        self.portraitImageView = [[UIImageView alloc] initWithFrame:CGRectMake(kHoriMargin, kVertMargin, kPortraitWidth, kPortraitHeight)];
        [self addSubview:self.portraitImageView];
        
        
        //创建动画
        CAKeyframeAnimation * keyAnimaion = [CAKeyframeAnimation animation];
        keyAnimaion.keyPath = @"transform.rotation";
        keyAnimaion.values = @[@(-10 / 180.0 * M_PI),@(10 /180.0 * M_PI),@(-10/ 180.0 * M_PI)];//度数转弧度
        
        keyAnimaion.removedOnCompletion = NO;
        keyAnimaion.fillMode = kCAFillModeForwards;
        keyAnimaion.duration = 0.8;
        keyAnimaion.repeatCount = 1;
        [self.portraitImageView.layer addAnimation:keyAnimaion forKey:nil];
        
        
        /* Create name label. */
//        self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(kPortraitWidth + kHoriMargin,
//                                                                   kVertMargin,
//                                                                   kWidth - kPortraitWidth - kHoriMargin,
//                                                                   kHeight - 2 * kVertMargin)];
//        self.nameLabel.backgroundColor  = [UIColor clearColor];
//        self.nameLabel.textAlignment    = NSTextAlignmentCenter;
//        self.nameLabel.textColor        = [UIColor whiteColor];
//        self.nameLabel.font             = [UIFont systemFontOfSize:17.f];
//        [self addSubview:self.nameLabel];
        
    }
    
    return self;
}

- (void)dealloc {
    
}

//- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
//    //     1.判断当前控件能否接收事件
//    if (self.userInteractionEnabled == NO || self.hidden == YES || self.alpha <= 0.01) return nil;
//    // 2. 判断点在不在当前控件
//    if ([self pointInside:point withEvent:event] == NO) return nil;
//    // 3.从后往前遍历自己的子控件
//    NSInteger count = self.subviews.count;
//    for (NSInteger i = 0; i < count; i++) {
//        UIView *childView = self.subviews[i];
//        // 把当前控件上的坐标系转换成子控件上的坐标系
//        CGPoint childP = [self convertPoint:point toView:childView];
//        UIView *fitView = [childView hitTest:childP withEvent:event];
//        if (fitView) { // 寻找到最合适的view
//            return fitView;
//        }
//    }
//    // 循环结束,表示没有比自己更合适的view
//    return self;
//}

@end
