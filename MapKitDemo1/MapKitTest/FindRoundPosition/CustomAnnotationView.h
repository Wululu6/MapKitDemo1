//
//  CustomAnnotationView.h
//  CustomAnnotationDemo
//
//  Created by songjian on 13-3-11.
//  Copyright (c) 2013年 songjian. All rights reserved.
//

#import <MAMapKit/MAMapKit.h>

#import "CustomCalloutView.h"

@protocol CustomAnnotationDelegate <NSObject>

- (void)pushNaviDriveControllerBy:(CLLocationCoordinate2D)coorinate;

@end

@interface CustomAnnotationView : MAAnnotationView

@property (nonatomic, copy) NSString *name;

@property (nonatomic, strong) UIImage *portrait;

@property (nonatomic, strong) CustomCalloutView *calloutView;

///经纬度
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;

@property (nonatomic, assign) BOOL selectAnnotation;

// 进入直播代理
@property (nonatomic, weak) id<CustomAnnotationDelegate>delegate;

@end
