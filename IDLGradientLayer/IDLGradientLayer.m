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

#define M_TWOPI (2.0f * M_PI)

typedef struct
{
    CGFloat r;
    CGFloat g;
    CGFloat b;
    CGFloat a;
} IDLGradientLayerColorComponents;

typedef struct
{
    IDLGradientLayerColorComponents start;
    IDLGradientLayerColorComponents delta;
} IDLGradientLayerSegmentComponents;

typedef struct
{
    CGFloat start;
    CGFloat finish;
    CGFloat delta;
} IDLGradientLayerSegmentLookup;

NS_INLINE NSString *NSStringFromIDLGradientLayerColorComponents(IDLGradientLayerColorComponents components)
{
    return [NSString stringWithFormat:@"{r:%f,g:%f,b:%f,a:%f}",components.r,components.g,components.b,components.a];
}

NS_INLINE NSString *NSStringFromIDLGradientLayerSegmentLookup(IDLGradientLayerSegmentLookup lookup)
{
    return [NSString stringWithFormat:@"{s:%f,f:%f}",lookup.start,lookup.finish];
}

@interface IDLGradientLayerSegment : NSObject

@property CGColorRef startColorRef;
@property CGColorRef finishColorRef;
@property CGFloat startAngle;
@property CGFloat finishAngle;

@property IDLGradientLayerSegmentComponents components;
@property IDLGradientLayerSegmentLookup lookup;

@property BOOL interpolateColors;

@property NSInteger index;

@end

@implementation IDLGradientLayerSegment

-(NSString *)description
{
    return [NSString stringWithFormat:@"Segment(%li)[start:%f, finish:%f, i:%i (%@ -> %@)]",self.index,self.startAngle,self.finishAngle, self.interpolateColors, NSStringFromIDLGradientLayerColorComponents(self.components.start), NSStringFromIDLGradientLayerColorComponents(self.components.delta)];
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
        segment.startAngle = location * M_TWOPI;
        segment.finishAngle = nextLocation * M_TWOPI;
        segment.startColorRef = color;
        segment.finishColorRef = nextColor;
        
        
        //NSLog(@"index:%i - s:%f, f:%f", (int)index,location,nextLocation);
        
        segment.interpolateColors = !colorsMatch;
        
        IDLGradientLayerColorComponents startColorComponents = [self getComponentsFromColorRef:color];
        IDLGradientLayerColorComponents finishColorComponents = [self getComponentsFromColorRef:nextColor];
        finishColorComponents.r = finishColorComponents.r - startColorComponents.r;
        finishColorComponents.g = finishColorComponents.g - startColorComponents.g;
        finishColorComponents.b = finishColorComponents.b - startColorComponents.b;
        finishColorComponents.a = finishColorComponents.a - startColorComponents.a;
        segment.components = (IDLGradientLayerSegmentComponents){startColorComponents,finishColorComponents};
        segment.lookup = (IDLGradientLayerSegmentLookup){segment.startAngle, segment.finishAngle, (segment.finishAngle - segment.startAngle)};
        
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
    
    CGPoint center = self.center;
    
    // normalize the custom rotation
    CGFloat rotation = _rotation;
    //NSLog(@"supplied rotation: %f",rotation);
    if (rotation < 0.0f || rotation > M_TWOPI) {
        double intpart;
        rotation = modf(rotation/M_TWOPI, &intpart) * M_TWOPI;
        if (rotation < 0.0f) {
            rotation += M_TWOPI;
        }
    }
    //NSLog(@"normalized rotation: %f",rotation);
    
    CGContextClearRect(context, self.bounds);
    
    // normalize the context frame
    CGRect contextFrame = CGContextGetClipBoundingBox(context);
    NSLog(@"frame: %@",NSStringFromCGRect(contextFrame));
    contextFrame.size.width = ceil(CGRectGetMaxX(contextFrame)) - floor(CGRectGetMinX(contextFrame));
    contextFrame.size.height = ceil(CGRectGetMaxY(contextFrame)) - floor(CGRectGetMinY(contextFrame));
    contextFrame.origin.x = floor(contextFrame.origin.x);
    contextFrame.origin.y = floor(contextFrame.origin.y);
    NSLog(@"normalized frame: %@",NSStringFromCGRect(contextFrame));
    
    int dim = contextFrame.size.width * contextFrame.size.height;
    CFMutableDataRef bitmapData = CFDataCreateMutable(NULL, 0);
    CFDataSetLength(bitmapData, dim * 4);
    
    generateBitmap(CFDataGetMutableBytePtr(bitmapData), segments, contextFrame, center, rotation);
    
    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData(bitmapData);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef imageRef = CGImageCreate(contextFrame.size.width, contextFrame.size.height, 8, 32, contextFrame.size.width * 4, colorSpace, kCGImageAlphaLast, dataProvider, NULL, 0, kCGRenderingIntentDefault);
    CGContextDrawImage(context, contextFrame, imageRef);
}

void generateBitmap(UInt8 *bitmap, NSArray *segments, CGRect frame, CGPoint center, CGFloat rotation)
{
    NSUInteger segmentCount = segments.count;
    IDLGradientLayerSegmentLookup segmentLookup[segmentCount];
    IDLGradientLayerSegmentComponents segmentComponents[segmentCount];
    
    IDLGradientLayerSegment *segment = nil;
    for (NSInteger i = 0; i < segmentCount; i++) {
        segment = [segments objectAtIndex:i];
        segmentLookup[i] = [segment lookup];
        segmentComponents[i] = [segment components];
        
        //NSLog(@"%i: %@",i,NSStringFromIDLGradientLayerSegmentLookup(segmentLookup[i]));
    }
    int offsetX = frame.origin.x;
    int offsetY = frame.origin.y;
    int width = frame.size.width;
    int height = frame.size.height;
    
    CGFloat angle;
    CGPoint point;
    
    center.x = round(center.x);
    center.y = round(center.y);
    
    int segmentIndex = 0;
    
#ifdef DEBUG
    NSUInteger missCount = 0, hitCount = 0;
#endif
    
    int i = 0;
    int s,so;
    
    for (int y = 0; y < height; y++)
    {
        for (int x = 0; x < width; x++)
        {
            point.x = -(x + offsetX) + center.x;
            point.y = (y + offsetY) + center.y;
            
            angle = atan2(point.y, point.x) + M_PI - rotation;
            
            if (angle < 0.0f) angle += M_PI * 2.0f;
            
            if (segmentCount > 1) {
                for (s = 0; s < segmentCount; s++) {
                    so = (s + segmentIndex) % segmentCount;
                    if (segmentLookup[so].start <= angle && angle <= segmentLookup[so].finish) {
                        segmentIndex = so;
#ifdef DEBUG
                        hitCount++;
#endif
                        break;
#ifdef DEBUG
                    } else {
                        missCount++;
#endif
                    }
                }
            }
            
            CGFloat position = (angle - segmentLookup[segmentIndex].start)/segmentLookup[segmentIndex].delta;
            
            
            if (abs(point.y) < 2) {
                //NSLog(@"\tp:{%f,%f},\ta:%f (%f),\ti:%i",point.x,point.y,angle,position,lastSegmentIndex);
            }
            
            IDLGradientLayerSegmentComponents components = segmentComponents[segmentIndex];
            
            bitmap[i] =   (components.start.r + position * components.delta.r) * 0xff;
            bitmap[i+1] = (components.start.g + position * components.delta.g) * 0xff;
            bitmap[i+2] = (components.start.b + position * components.delta.b) * 0xff;
            bitmap[i+3] = (components.start.a + position * components.delta.a) * 0xff;
            
            i += 4;
        }
        //NSLog(@" \t");
    }
    
#ifdef DEBUG
    NSLog(@"hit count: %lu",hitCount);
    NSLog(@"miss count: %lu",missCount);
#endif
    
}

@end
