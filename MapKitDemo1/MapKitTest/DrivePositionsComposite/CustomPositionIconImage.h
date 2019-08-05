//
//  CustomPositionIconImage.h
//  MapKitTest
//
//  Created by apple on 2019/8/2.
//  Copyright © 2019 apple. All rights reserved.
//

#import <MAMapKit/MAMapKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomPositionIconImage : MAAnnotationView

@property (nonatomic, copy) NSString *name;

@property (nonatomic, strong) UIImage *portrait;

///经纬度
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;

@end

NS_ASSUME_NONNULL_END
