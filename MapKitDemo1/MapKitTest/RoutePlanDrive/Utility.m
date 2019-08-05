//
//  Utility.m
//  iOS_3D_ClickOverlay
//
//  Created by yi chen on 14-7-8.
//  Copyright (c) 2014年 yi chen. All rights reserved.
//

#import "Utility.h"


/*!
 判断polyline是否在点point附近
 @param polyline  输入polyline
 @param point     输入点point
 @param threshold 判断距离门限
 @return 若polyline在point附近返回YES，否则NO
 */
BOOL MAPisMAPolylineNearPointAtDistanceThreshold(MAPolyline *polyline, MAMapPoint point, double threshold)
{
    for (int i = 1; i<polyline.pointCount; i++)
    {
        double distance = MAPdistanceBetweenPointAndLineFromPointAtoPointB(point, polyline.points[i-1], polyline.points[i]);
        if (distance < threshold)
        {
            return YES;
        }
    }
    
    return NO;
}

/*!
 判断点是否在overlay的图形中
 @param overlay 指定的overlay
 @param point   指定的点
 @param mapPointDistance 提供overlay的线宽（需换算到MAMapPoint坐标系）
 @return 若点在overlay中，返回YES，否则NO
 */
BOOL MAPisOverlayWithLineWidthContainsPoint(id<MAOverlay> overlay, double mapPointDistance, MAMapPoint mapPoint)
{
    /* 将point转换为经纬度和MapPoint. */
    CLLocationCoordinate2D coordinate = MACoordinateForMapPoint(mapPoint);
    
    /* 判断point是否在overlay内*/
    if([overlay isKindOfClass:[MACircle class]])
    {
        return MACircleContainsCoordinate(coordinate, ((MACircle *)overlay).coordinate, ((MACircle *)overlay).radius);
    }
    else if ([overlay isKindOfClass:[MAPolygon class]])
    {
        return MAPolygonContainsPoint(mapPoint, ((MAPolygon *)overlay).points, ((MAPolygon *)overlay).pointCount);
    }
    else if ([overlay isKindOfClass:[MAPolyline class]])
    {
        /*响应距离门限. */
        double distanceThreshold = mapPointDistance * 1;
        
        return MAPisMAPolylineNearPointAtDistanceThreshold((MAPolyline *)overlay, mapPoint, distanceThreshold);
    }
    
    return NO;
}

#pragma mark - math

/*!
 计算点P到线段AB的距离
 @param pointP 点P
 @param pointA 线段起点A
 @param pointB 线段终点B
 @return 点P到线段AB的距离
 */
double MAPdistanceBetweenPointAndLineFromPointAtoPointB(MAMapPoint pointP, MAMapPoint pointA, MAMapPoint pointB)
{
    MAMapPoint vectorAP = MAPvectorFromPointToPoint(pointA, pointP);//AP
    MAMapPoint vectorPB = MAPvectorFromPointToPoint(pointP, pointB);//PB
    MAMapPoint vectorAB = MAPvectorFromPointToPoint(pointA, pointB);//AB
    
    double ABxAP = MAPvectorAMutiplyVectorB(vectorAB, vectorAP);
    
    /* 若点p到线段AB的垂足在延长线上，返回点P到线段端点的距离. */
    if ( ABxAP < 0)
    {
        return sqrt(MAPsquareLengthOfVector(vectorAP));
    }
    
    if (MAPvectorAMutiplyVectorB(vectorPB, vectorAB) < 0)
    {
        return sqrt(MAPsquareLengthOfVector(vectorPB));
    }
    
    /*点P在线段AB上的垂足为C，计算向量PC的长度，即为点P到线段AB的距离. */
    double coefficient  = ABxAP / MAPsquareLengthOfVector(vectorAB);
    MAMapPoint vectorAC = MAMapPointMake(vectorAB.x * coefficient, vectorAB.y * coefficient);
    MAMapPoint vectorCP = MAMapPointMake(vectorAP.x - vectorAC.x , vectorAP.y - vectorAC.y);
    
    return sqrt(MAPsquareLengthOfVector(vectorCP));
}

/*!
 计算点到点的向量
 @param fromPoint 向量起点
 @param toPoint   向量终点
 @return 向量
 */
MAMapPoint MAPvectorFromPointToPoint(MAMapPoint fromPoint, MAMapPoint toPoint)
{
    return MAMapPointMake(toPoint.x - fromPoint.x, toPoint.y - fromPoint.y);
}

/*!
 计算向量长度的平方
 @param vector 向量
 @return 长度的平方
 */
double MAPsquareLengthOfVector(MAMapPoint vector)
{
    return vector.x * vector.x + vector.y * vector.y;
}

/*!
 计算向量的点积
 @param a 向量A
 @param b 向量B
 @return 向量A 点乘 向量B
 */
double MAPvectorAMutiplyVectorB(MAMapPoint a, MAMapPoint b)
{
    return a.x * b.x + a.y * b.y;
}

