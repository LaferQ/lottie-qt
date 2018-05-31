//
//  LOTPolystarAnimator.m
//  Lottie
//
//  Created by brandon_withrow on 7/27/17.
//  Copyright © 2017 Airbnb. All rights reserved.
//

#import "LOTPolystarAnimator.h"
#import "LOTPointInterpolator.h"
#import "LOTNumberInterpolator.h"
#import "LOTBezierPath.h"
#import "CGGeometry+LOTAdditions.h"

#include <QSharedPointer>

const CGFloat kPOLYSTAR_MAGIC_NUMBER = .47829f;

@implementation LOTPolystarAnimator {
  QSharedPointer<LOTNumberInterpolator> _outerRadiusInterpolator;
  QSharedPointer<LOTNumberInterpolator> _innerRadiusInterpolator;
  QSharedPointer<LOTNumberInterpolator> _outerRoundnessInterpolator;
  QSharedPointer<LOTNumberInterpolator> _innerRoundnessInterpolator;
  QSharedPointer<LOTPointInterpolator> _positionInterpolator;
  QSharedPointer<LOTNumberInterpolator> _pointsInterpolator;
  QSharedPointer<LOTNumberInterpolator> _rotationInterpolator;
}

- (instancetype _Nonnull)initWithInputNode:(LOTAnimatorNode *_Nullable)inputNode
                             shapeStar:(LOTShapeStar *_Nonnull)shapeStar {
  self = [super initWithInputNode:inputNode keyName:shapeStar.keyname];
  if (self) {
    _outerRadiusInterpolator = _outerRadiusInterpolator.create(shapeStar.outerRadius.keyframes);
    _innerRadiusInterpolator = _innerRadiusInterpolator.create(shapeStar.innerRadius.keyframes);
    _outerRoundnessInterpolator = _outerRoundnessInterpolator.create(shapeStar.outerRoundness.keyframes);
    _innerRoundnessInterpolator = _innerRoundnessInterpolator.create(shapeStar.innerRoundness.keyframes);
    _pointsInterpolator = _pointsInterpolator.create(shapeStar.numberOfPoints.keyframes);
    _rotationInterpolator = _rotationInterpolator.create(shapeStar.rotation.keyframes);
    _positionInterpolator = _positionInterpolator.create(shapeStar.position.keyframes);
  }
  return self;
}

- (QMap<QString, QSharedPointer<LOTValueInterpolator>>)valueInterpolators {
    QMap<QString, QSharedPointer<LOTValueInterpolator>> map;
    map.insert("Points", _pointsInterpolator);
    map.insert("Position", _positionInterpolator);
    map.insert("Rotation", _rotationInterpolator);
    map.insert("Inner Radius", _innerRadiusInterpolator);
    map.insert("Outer Radius", _outerRadiusInterpolator);
    map.insert("Inner Roundness", _innerRoundnessInterpolator);
    map.insert("Outer Roundness", _outerRoundnessInterpolator);
    return map;
}

- (BOOL)needsUpdateForFrame:(NSNumber *)frame {
  return (_outerRadiusInterpolator->hasUpdateForFrame(frame.floatValue) ||
          _innerRadiusInterpolator->hasUpdateForFrame(frame.floatValue) ||
          _outerRoundnessInterpolator->hasUpdateForFrame(frame.floatValue) ||
          _innerRoundnessInterpolator->hasUpdateForFrame(frame.floatValue) ||
          _pointsInterpolator->hasUpdateForFrame(frame.floatValue) ||
          _rotationInterpolator->hasUpdateForFrame(frame.floatValue) ||
          _positionInterpolator->hasUpdateForFrame(frame.floatValue));
}

- (void)performLocalUpdate {
  CGFloat outerRadius = _outerRadiusInterpolator->floatValueForFrame(self.currentFrame.floatValue);
  CGFloat innerRadius = _innerRadiusInterpolator->floatValueForFrame(self.currentFrame.floatValue);
  CGFloat outerRoundness = _outerRoundnessInterpolator->floatValueForFrame(self.currentFrame.floatValue) / 100.f;
  CGFloat innerRoundness = _innerRoundnessInterpolator->floatValueForFrame(self.currentFrame.floatValue)/ 100.f;
  CGFloat points = _pointsInterpolator->floatValueForFrame(self.currentFrame.floatValue);
  CGFloat rotation = _rotationInterpolator->floatValueForFrame(self.currentFrame.floatValue);
  CGPoint position = _positionInterpolator->pointValueForFrame(self.currentFrame.floatValue).toCGPoint();
  LOTBezierPath *path = [[LOTBezierPath alloc] init];
  path.cacheLengths = self.pathShouldCacheLengths;
  CGFloat currentAngle = LOT_DegreesToRadians(rotation - 90);
  CGFloat anglePerPoint = (CGFloat)((2 * M_PI) / points);
  CGFloat halfAnglePerPoint = anglePerPoint / 2.0f;
  CGFloat partialPointAmount = points - floor(points);
  if (partialPointAmount != 0) {
    currentAngle += halfAnglePerPoint * (1.f - partialPointAmount);
  }

  CGFloat x;
  CGFloat y;
  CGFloat previousX;
  CGFloat previousY;
  CGFloat partialPointRadius = 0;
  if (partialPointAmount != 0) {
    partialPointRadius = innerRadius + partialPointAmount * (outerRadius - innerRadius);
    x = (CGFloat) (partialPointRadius * cosf(currentAngle));
    y = (CGFloat) (partialPointRadius * sinf(currentAngle));
    [path LOT_moveToPoint:CGPointMake(x, y)];
    currentAngle += anglePerPoint * partialPointAmount / 2.f;
  } else {
    x = (float) (outerRadius * cosf(currentAngle));
    y = (float) (outerRadius * sinf(currentAngle));
    [path LOT_moveToPoint:CGPointMake(x, y)];
    currentAngle += halfAnglePerPoint;
  }

  // True means the line will go to outer radius. False means inner radius.
  BOOL longSegment = false;
  CGFloat numPoints = ceil(points) * 2;
  for (int i = 0; i < numPoints; i++) {
    CGFloat radius = longSegment ? outerRadius : innerRadius;
    CGFloat dTheta = halfAnglePerPoint;
    if (partialPointRadius != 0 && i == numPoints - 2) {
      dTheta = anglePerPoint * partialPointAmount / 2.f;
    }
    if (partialPointRadius != 0 && i == numPoints - 1) {
      radius = partialPointRadius;
    }
    previousX = x;
    previousY = y;
    x = (CGFloat) (radius * cosf(currentAngle));
    y = (CGFloat) (radius * sinf(currentAngle));

    if (innerRoundness == 0 && outerRoundness == 0) {
      [path LOT_addLineToPoint:CGPointMake(x, y)];
    } else {
      CGFloat cp1Theta = (CGFloat) (atan2f(previousY, previousX) - M_PI / 2.f);
      CGFloat cp1Dx = (CGFloat) cosf(cp1Theta);
      CGFloat cp1Dy = (CGFloat) sinf(cp1Theta);
      
      CGFloat cp2Theta = (CGFloat) (atan2f(y, x) - M_PI / 2.f);
      CGFloat cp2Dx = (CGFloat) cosf(cp2Theta);
      CGFloat cp2Dy = (CGFloat) sinf(cp2Theta);
      
      CGFloat cp1Roundedness = longSegment ? innerRoundness : outerRoundness;
      CGFloat cp2Roundedness = longSegment ? outerRoundness : innerRoundness;
      CGFloat cp1Radius = longSegment ? innerRadius : outerRadius;
      CGFloat cp2Radius = longSegment ? outerRadius : innerRadius;
      
      CGFloat cp1x = cp1Radius * cp1Roundedness * kPOLYSTAR_MAGIC_NUMBER * cp1Dx;
      CGFloat cp1y = cp1Radius * cp1Roundedness * kPOLYSTAR_MAGIC_NUMBER * cp1Dy;
      CGFloat cp2x = cp2Radius * cp2Roundedness * kPOLYSTAR_MAGIC_NUMBER * cp2Dx;
      CGFloat cp2y = cp2Radius * cp2Roundedness * kPOLYSTAR_MAGIC_NUMBER * cp2Dy;
      if (partialPointAmount != 0) {
        if (i == 0) {
          cp1x *= partialPointAmount;
          cp1y *= partialPointAmount;
        } else if (i == numPoints - 1) {
          cp2x *= partialPointAmount;
          cp2y *= partialPointAmount;
        }
      }
      [path LOT_addCurveToPoint:CGPointMake(x, y)
                  controlPoint1:CGPointMake(previousX - cp1x, previousY - cp1y)
                  controlPoint2:CGPointMake(x + cp2x, y + cp2y)];
    }
    currentAngle += dTheta;
    longSegment = !longSegment;
  }
  [path LOT_closePath];
  [path LOT_applyTransform:CGAffineTransformMakeTranslation(position.x, position.y)];
  self.localPath = path;
}

@end
