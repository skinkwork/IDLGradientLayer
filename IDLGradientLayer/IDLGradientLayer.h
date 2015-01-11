//
//  IDLGradientLayer.h
//  IDLGradientLayerDemo
//
//  Created by Trystan Pfluger on 9/01/2015.
//  Copyright (c) 2015 Idlepixel. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface IDLGradientLayer : CALayer

@property(copy) NSArray *colors;
@property(copy) NSArray *locations;
@property CGPoint center;
@property CGFloat radius;
@property CGFloat rotation;

@property (nonatomic, strong) NSNumber *innerRadius;
@property (nonatomic, strong) NSNumber *outerRadius;

@end
