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

typedef struct
{
    CGFloat r;
    CGFloat g;
    CGFloat b;
    CGFloat a;
} IDLGradientLayerColorComponents;

NS_INLINE NSString *NSStringFromIDLGradientLayerColorComponents(IDLGradientLayerColorComponents components)
{
    return [NSString stringWithFormat:@"{r:%f,g:%f,b:%f,a:%f}",components.r,components.g,components.b,components.a];
}

typedef struct
{
    CGFloat start;
    CGFloat finish;
} IDLGradientLayerSegmentLookup;

NS_INLINE NSString *NSStringFromIDLGradientLayerSegmentLookup(IDLGradientLayerSegmentLookup lookup)
{
    return [NSString stringWithFormat:@"{s:%f,f:%f}",lookup.start,lookup.finish];
}

@interface IDLGradientLayerSegment : NSObject

@property CGColorRef startColorRef;
@property CGColorRef finishColorRef;
@property CGFloat startAngle;
@property CGFloat finishAngle;

@property IDLGradientLayerColorComponents startColorComponents;
@property IDLGradientLayerColorComponents finishColorComponents;

@property BOOL interpolateColors;

@property NSInteger index;

@end

@implementation IDLGradientLayerSegment

-(NSString *)description
{
    return [NSString stringWithFormat:@"Segment(%li)[start:%f, finish:%f, i:%i (%@ -> %@)]",self.index,self.startAngle,self.finishAngle, self.interpolateColors, NSStringFromIDLGradientLayerColorComponents(self.startColorComponents), NSStringFromIDLGradientLayerColorComponents(self.finishColorComponents)];
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

- (void)drawInContext:(CGContextRef)context
{
    NSLog(@"frame: %@",NSStringFromCGRect(CGContextGetClipBoundingBox(context)));
    [self moveOriginToCenterInContext:context];
    [self drawGradientInContext:context];
}

- (void)moveOriginToCenterInContext:(CGContextRef)context
{
    CGRect bounds = self.bounds;
    CGContextTranslateCTM(context, CGRectGetMidX(bounds), CGRectGetMidY(bounds));
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
            
            //NSLog(@"i:%i, ni:%i",i,nextIndex);
            
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
    BOOL colorsMatch =CGColorEqualToColor(color, nextColor);
    
    IDLGradientLayerSegment *segment = nil;
    
    if (!colorsMatch || location != nextLocation) {
        
        segment = [IDLGradientLayerSegment new];
        segment.index = index;
        segment.startAngle = location * M_PI * 2.0f + _rotation;
        segment.finishAngle = nextLocation * M_PI * 2.0f + _rotation;
        segment.startColorRef = color;
        segment.finishColorRef = nextColor;
        
        
        //NSLog(@"index:%i - s:%f, f:%f", (int)index,location,nextLocation);
        
        segment.interpolateColors = !colorsMatch;
        
        segment.startColorComponents = [self getComponentsFromColorRef:color];
        segment.finishColorComponents = [self getComponentsFromColorRef:nextColor];
        
        //NSLog(@"number of components: %i", (int)CGColorGetNumberOfComponents(color));
    }
    return segment;
}

- (IDLGradientLayerColorComponents)getComponentsFromColorRef:(CGColorRef)colorRef
{
    NSUInteger numberOfComponents = CGColorGetNumberOfComponents(colorRef);
    CGFloat *colorRefComponents = (CGFloat *)CGColorGetComponents(colorRef);
    
    IDLGradientLayerColorComponents components;
    
    if (numberOfComponents == 4) {
        components = (IDLGradientLayerColorComponents){
            colorRefComponents[0],
            colorRefComponents[1],
            colorRefComponents[2],
            colorRefComponents[3]};
    } else if (numberOfComponents == 2) {
        components = (IDLGradientLayerColorComponents){
            colorRefComponents[0],
            colorRefComponents[0],
            colorRefComponents[0],
            colorRefComponents[1]};
    } else {
        components = (IDLGradientLayerColorComponents){
            0.0f,
            0.0f,
            0.0f,
            0.0f};
    }
    return components;
}

- (void)drawGradientInContext:(CGContextRef)context
{
    
    NSArray *segments = [self buildSegments];
    
    NSUInteger segmentCount = segments.count;
    
    NSLog(@"segments: \n%@",segments);
    
    if (segmentCount == 0) return;
    
    IDLGradientLayerSegmentLookup segmentLookup[segmentCount];
    IDLGradientLayerSegment *segment;
    for (NSInteger i = 0; i < segmentCount; i++) {
        segment = [segments objectAtIndex:i];
        segmentLookup[i] = (IDLGradientLayerSegmentLookup){segment.startAngle, segment.finishAngle};
        NSLog(@"%i: %@",i,NSStringFromIDLGradientLayerSegmentLookup(segmentLookup[i]));
    }
    
    NSInteger counter = 0;
    
    CGPoint center = CGPointZero;
    CGFloat radius = 100.0f;
    
    CGContextClearRect(context, self.bounds);
    
    BOOL interpolate;
    
    NSUInteger componentsCount;
    
    
    CGRect contextFrame = CGContextGetClipBoundingBox(context);
    
    NSLog(@"frame: %@",NSStringFromCGRect(contextFrame));
    
    
    /*
    
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
    */
}

@end
