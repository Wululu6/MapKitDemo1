//
//  SearchViewController.h
//  MapKitTest
//
//  Created by apple on 2019/7/29.
//  Copyright © 2019 apple. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AMapSearchKit/AMapSearchAPI.h>

NS_ASSUME_NONNULL_BEGIN

@interface SearchViewController : UIViewController

@property (nonatomic, strong) NSString *city;

@property (nonatomic, strong) NSArray *roundArray;

@property (nonatomic, copy) void(^selectPositionBlock)(AMapTip *Location);

@end

NS_ASSUME_NONNULL_END
