//
//  IDLGradientLayer.m
//  IDLGradientLayerDemo
//
//  Created by Trystan Pfluger on 9/01/2015.
//  Copyright (c) 2015 Idlepixel. All rights reserved.
//

#import "IDLGradientLayer.h"
#import <objc/runtime.h>

#import <UIKit/UIKit.h>

@interface IDLGradientLayerSegment : NSObject

@property CGColorRef startColorRef;
@property CGColorRef finishColorRef;
@property CGFloat startAngle;
@property CGFloat finishAngle;
@property CGFloat subdivisionCount;
@property CGFloat subdivisionWidth;

@property BOOL interpolateColors;

@property NSInteger index;

@end

@implementation IDLGradientLayerSegment

-(NSString *)description
{
    return [NSString stringWithFormat:@"Segment(%li)[start:%f, finish:%f, subd:(%f:%f), i:%i]",self.index,self.startAngle,self.finishAngle,self.subdivisionCount,self.subdivisionWidth, self.interpolateColors];
}

@end

@implementation IDLGradientLayer

+ (NSSet *)customPropertyKeys
{
    static NSMutableSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unsigned int count;
        objc_property_t *properties = class_copyPropertyList(self, &count);
        set = [[NSMutableSet alloc] initWithCapacity:count];
        for (int i = 0; i < count; ++i) {
            [set addObject:@(property_getName(properties[i]))];
        }
        free(properties);
    });
    return set;
}

+ (BOOL)needsDisplayForKey:(NSString *)key
{
    return [[self customPropertyKeys] containsObject:key] || [super needsDisplayForKey:key];
}

- (id)initWithLayer:(id)layer
{
    if (self = [super initWithLayer:layer]) {
        for (NSString *key in [self.class customPropertyKeys]) {
            [self setValue:[layer valueForKey:key] forKey:key];
        }
    }
    return self;
}

- (BOOL)needsDisplayOnBoundsChange
{
    return YES;
}

- (void)drawInContext:(CGContextRef)gc
{
    [self moveOriginToCenterInContext:gc];
    [self drawGradientInContext:gc];
}

- (void)moveOriginToCenterInContext:(CGContextRef)gc
{
    CGRect bounds = self.bounds;
    CGContextTranslateCTM(gc, CGRectGetMidX(bounds), CGRectGetMidY(bounds));
}

- (NSArray *)buildSegments
{
    NSArray *colors = self.colors;
    NSArray *locations = self.locations;
    if (colors.count > 0) {
        NSMutableArray *segments = [NSMutableArray array];
        IDLGradientLayerSegment *segment = nil;
        
        CGColorRef color = (__bridge CGColorRef)[colors firstObject];
        CGColorRef nextColor = nil;
        
        CGFloat location = [(NSNumber *)[locations firstObject] floatValue];
        CGFloat nextLocation = 0.0f;
        
        NSUInteger total = colors.count;
        
        for (NSInteger i = 0; i < total; i++) {
            if (i > 0) {
                color = nextColor;
                location = nextLocation;
            }
            NSInteger nextIndex = i + 1;
            nextColor = (__bridge CGColorRef)[colors objectAtIndex:MIN(nextIndex, total-1)];
            
            if (nextIndex >= total) {
                nextLocation = 1.0f;
            } else if (nextIndex < locations.count) {
                nextLocation = [(NSNumber *)[locations objectAtIndex:nextIndex] floatValue];
            } else {
                CGFloat remainingCount = total - nextIndex;
                CGFloat remainingSpread = 1.0f - location;
                nextLocation = location + (remainingSpread/remainingCount);
            }
            location = MAX(0.0f, MIN(location, 1.0f));
            nextLocation = MAX(location, MIN(nextLocation, 1.0f));
            
            if (i == 0 && location > 0.0f) {
                segment = [self buildSegment:-1 location:0.0f nextLocation:location color:color nextColor:color];
                if (segment) [segments addObject:segment];
            }
            
            segment = [self buildSegment:i location:location nextLocation:nextLocation color:color nextColor:nextColor];
            if (segment) [segments addObject:segment];
            
            
        }
        
        return [NSArray arrayWithArray:segments];
    }
    return nil;
}

#define kLevelOfDetail  0.05f

-(IDLGradientLayerSegment *)buildSegment:(NSInteger)index
                           location:(CGFloat)location
                           nextLocation:(CGFloat)nextLocation
                           color:(CGColorRef)color
                           nextColor:(CGColorRef)nextColor
{
    IDLGradientLayerSegment *segment = [IDLGradientLayerSegment new];
    segment.index = index;
    segment.startAngle = location * M_PI * 2.0f + _rotation;
    segment.finishAngle = nextLocation * M_PI * 2.0f + _rotation;
    segment.startColorRef = color;
    segment.finishColorRef = nextColor;
    
    CGFloat subdivisionCount = ceil((segment.finishAngle - segment.startAngle)/kLevelOfDetail);
    segment.subdivisionWidth = (segment.finishAngle - segment.startAngle)/subdivisionCount;
    segment.subdivisionCount = subdivisionCount;
    
    if (!CGColorEqualToColor(color, nextColor)) {
        segment.interpolateColors = CGColorSpaceGetModel(CGColorGetColorSpace(color)) == CGColorSpaceGetModel(CGColorGetColorSpace(nextColor));
    } else {
        segment.interpolateColors = NO;
    }
    
    return segment;
}

-(void)drawSliverInContext:(CGContextRef)gc start:(CGFloat)start finish:(CGFloat)finish radius:(CGFloat)radius center:(CGPoint)center colorRef:(CGColorRef)colorRef
{
    CGFloat startPointX = cos(start) * radius + center.x;
    CGFloat startPointY = sin(start) * radius + center.y;
    
    CGFloat finishPointX = cos(finish) * radius + center.x;
    CGFloat finishPointY = sin(finish) * radius + center.y;
    
    CGContextBeginPath(gc);
    
    CGContextMoveToPoint(gc, center.x, center.y);
    CGContextAddLineToPoint(gc, startPointX, startPointY);
    CGContextAddLineToPoint(gc, finishPointX, finishPointY);
    CGContextAddLineToPoint(gc, center.x, center.y);
    
    //CGContextAddLineToPoint(gc, 25.0f, 25.0f);
    
    CGContextSetFillColorWithColor(gc, colorRef);
    
    CGContextFillPath(gc);
}

- (void)drawGradientInContext:(CGContextRef)gc
{
    
    NSArray *segments = [self buildSegments];
    
    NSLog(@"segments: \n%@",segments);
    
    
    if (segments.count == 0) return;
    
    NSInteger counter = 0;
    
    CGPoint center = CGPointZero;
    CGFloat radius = 100.0f;
    
    CGContextClearRect(gc, self.bounds);
    CGContextSetInterpolationQuality(gc, kCGInterpolationHigh);
    CGContextSetBlendMode(gc, kCGBlendModeLighten);
    
    CGFloat sliverStart, sliverFinish, sliverWidth;
    
    BOOL interpolate;
    
    NSUInteger componentsCount;
    
    CGColorRef colorRef = nil;
    
    for (IDLGradientLayerSegment *segment in segments) {
        CGFloat sliverCount = segment.subdivisionCount;
        if (sliverCount > 0.0f) {
            
            sliverWidth = segment.subdivisionWidth;
            sliverStart = segment.startAngle;
            
            interpolate = segment.interpolateColors;
            
            colorRef = segment.startColorRef;
            
            if (interpolate) {
                componentsCount = CGColorGetNumberOfComponents(colorRef);
            } else {
                componentsCount = 0;
            }
            CGFloat *components;
            CGFloat componentDeltas[componentsCount];
            
            CGColorSpaceRef colorSpaceRef = CGColorGetColorSpace(colorRef);
            
            if (interpolate) {
                components = (CGFloat *)CGColorGetComponents(colorRef);
                CGFloat *finishComponents = (CGFloat *)CGColorGetComponents(segment.finishColorRef);
                for (NSInteger c = 0; c < componentsCount; c++) {
                    componentDeltas[c] = (finishComponents[c]-components[c])/sliverCount;
                    //NSLog(@"c[%li]: %f, (%f > %f)",c,componentDeltas[c],components[c],finishComponents[c]);
                }
            } else {
                components = nil;
            }
            
            do {
                counter++;
                sliverFinish = MIN(sliverStart+sliverWidth, segment.finishAngle);
                
                if (counter % 3 == 0)
                {
                    
                [self drawSliverInContext:gc start:sliverStart finish:sliverFinish radius:radius center:center colorRef:colorRef];
                }
                sliverStart = sliverFinish;
                
                if (interpolate) {
                    CGColorRelease(colorRef);
                    colorRef = nil;
                    for (NSInteger c = 0; c < componentsCount; c++) {
                        components[c] = components[c] + componentDeltas[c];
                    }
                    NSLog(@"%f, %f, %f",components[0],components[1],components[2]);
                    colorRef = CGColorCreate(colorSpaceRef, components);
                }
                
            } while (sliverStart < segment.finishAngle);
            
            
        }
    }
    
    NSLog(@"sliver count: %li",counter);
    
}

@end
