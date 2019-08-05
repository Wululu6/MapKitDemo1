//
//  CustomCalloutView.m
//  Category_demo2D
//
//  Created by xiaoming han on 13-5-22.
//  Copyright (c) 2013年 songjian. All rights reserved.
//

#import "CustomCalloutView.h"
#import <QuartzCore/QuartzCore.h>

#define kArrorHeight    10

@implementation CustomCalloutView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

#pragma mark - draw rect

- (void)drawRect:(CGRect)rect
{
    
    [self drawInContext:UIGraphicsGetCurrentContext()];
    
    self.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.layer.shadowOpacity = 1.0;
    self.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
    
}

- (void)drawInContext:(CGContextRef)context
{
    
    CGContextSetLineWidth(context, 2.0);
    CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:0.8].CGColor);
    
    [self getDrawPath:context];
    CGContextFillPath(context);
    
}

- (void)getDrawPath:(CGContextRef)context
{
    CGRect rrect = self.bounds;
    CGFloat radius = 6.0;
    CGFloat minx = CGRectGetMinX(rrect),
    midx = CGRectGetMidX(rrect),
    maxx = CGRectGetMaxX(rrect);
    CGFloat miny = CGRectGetMinY(rrect),
    maxy = CGRectGetMaxY(rrect)-kArrorHeight;
    
    CGContextMoveToPoint(context, midx+kArrorHeight, maxy);
    CGContextAddLineToPoint(context,midx, maxy+kArrorHeight);
    CGContextAddLineToPoint(context,midx-kArrorHeight, maxy);
    
    CGContextAddArcToPoint(context, minx, maxy, minx, miny, radius);
    CGContextAddArcToPoint(context, minx, minx, maxx, miny, radius);
    CGContextAddArcToPoint(context, maxx, miny, maxx, maxx, radius);
    CGContextAddArcToPoint(context, maxx, maxy, midx, maxy, radius);
    CGContextClosePath(context);
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
