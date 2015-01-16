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

#define IDL_GRADIENTLAYER_DEBUG     1

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

-(id)init
{
    self = [super init];
    if (self) {
        [self configure];
    }
    return self;
}

-(void)configure
{
    self.offset = CGPointZero;
}

- (BOOL)needsDisplayOnBoundsChange
{
    return YES;
}

-(void)updateLayer
{
    CGImageRef imageRef = [self drawGradient];
    self.contents = (__bridge id)imageRef;
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

-(CGFloat)scale
{
    CGFloat scale = _scale;
    if (scale <= 0.0f) scale = 1.0f;
    return scale;
}

- (CGImageRef)drawGradient
{
    NSArray *segments = [self buildSegments];
    
    NSUInteger segmentCount = segments.count;
    
#ifdef IDL_GRADIENTLAYER_DEBUG
    NSLog(@"segments: \n%@",segments);
#endif
    
    if (segmentCount == 0) return nil;
    
    CGFloat innerRadiusSquared = -1.0f;
    CGFloat outerRadiusSquared = -1.0f;
    if (self.innerRadius != nil) innerRadiusSquared = pow(self.innerRadius.floatValue, 2.0f);
    if (self.outerRadius != nil) outerRadiusSquared = pow(self.outerRadius.floatValue, 2.0f);
    if (outerRadiusSquared == 0.0f) return nil;
    
    CGPoint center;
    
    // normalize the custom rotation
    CGFloat rotation = _rotation;
    if (rotation < 0.0f || rotation > M_TWOPI) {
        double intpart;
        rotation = modf(rotation/M_TWOPI, &intpart) * M_TWOPI;
        if (rotation < 0.0f) {
            rotation += M_TWOPI;
        }
    }
    
    // bounds
    CGRect bounds = self.bounds;
    center.x = round(CGRectGetMidX(bounds) + self.offset.x);
    center.y = round(CGRectGetMidY(bounds) + self.offset.y);
    bounds.size.width = ceil(CGRectGetMaxX(bounds));
    bounds.size.height = ceil(CGRectGetMaxY(bounds));
    
    CGFloat scale = self.scale;
    
    CGSize imageSize = CGSizeMake(ceil(bounds.size.width*scale), ceil(bounds.size.height*scale));
    
    
    int dim = imageSize.width * imageSize.height;
    CFMutableDataRef bitmapData = CFDataCreateMutable(NULL, 0);
    CFDataSetLength(bitmapData, dim * 4);
    
#ifdef IDL_GRADIENTLAYER_DEBUG
    NSLog(@"scale: %f",scale);
    NSLog(@"size: %@",NSStringFromCGSize(imageSize));
    NSLog(@"center: %@",NSStringFromCGPoint(center));
#endif
    
    generateBitmap(CFDataGetMutableBytePtr(bitmapData), segments, scale, imageSize, center, rotation, innerRadiusSquared, outerRadiusSquared);
    
    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData(bitmapData);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef imageRef = CGImageCreate(imageSize.width, imageSize.height, 8, 32, imageSize.width * 4, colorSpace, kCGImageAlphaLast, dataProvider, NULL, 0, kCGRenderingIntentDefault);
    
    return imageRef;
}

void generateBitmap(UInt8 *bitmap, NSArray *segments, CGFloat scale, CGSize size, CGPoint center, CGFloat rotation, CGFloat innerRadiusSquared, CGFloat outerRadiusSquared)
{
    
    NSUInteger segmentCount = segments.count;
    IDLGradientLayerSegmentLookup segmentLookup[segmentCount];
    IDLGradientLayerSegmentComponents segmentComponents[segmentCount];
    
    IDLGradientLayerSegment *segment = nil;
    for (NSInteger i = 0; i < segmentCount; i++) {
        segment = [segments objectAtIndex:i];
        segmentLookup[i] = [segment lookup];
        segmentComponents[i] = [segment components];
    }
    int centerX = round(center.x);
    int centerY = round(center.y);
    int width = size.width;
    int height = size.height;
    
    CGFloat angle, distanceSquared;
    CGPoint point;
    
    int segmentIndex = 0;
    
    BOOL measureInnerRadius = (innerRadiusSquared > 0.0f);
    BOOL measureOuterRadius = (outerRadiusSquared > 0.0f);
    
    BOOL blankPixel;
    
#ifdef IDL_GRADIENTLAYER_DEBUG
    NSInteger missCount = 0, hitCount = 0;
#endif
    
    int i = 0;
    int s,so;
    
    for (int y = 0; y < height; y++)
    {
        for (int x = 0; x < width; x++)
        {
            point.x = -(((CGFloat)x/scale) - centerX);
            point.y = -(((CGFloat)y/scale) - centerY);
            
            blankPixel = NO;
            
            if (measureInnerRadius || measureOuterRadius) {
                distanceSquared = pow(point.x, 2.0f) + pow(point.y, 2.0f);
                if ((measureInnerRadius && distanceSquared < innerRadiusSquared) ||
                    (measureOuterRadius && distanceSquared > outerRadiusSquared)) {
                    blankPixel = YES;
                }
            }
            if (!blankPixel) {
                
                angle = atan2(point.y, point.x) + M_PI - rotation;
                
                if (angle < 0.0f) angle += M_PI * 2.0f;
                
                if (segmentCount > 1) {
                    for (s = 0; s < segmentCount; s++) {
                        so = (s + segmentIndex) % segmentCount;
                        if (segmentLookup[so].start <= angle && angle <= segmentLookup[so].finish) {
                            segmentIndex = so;
#ifdef IDL_GRADIENTLAYER_DEBUG
                            // only record perfect hits
                            if (s==0) hitCount++;
#endif
                            break;
#ifdef IDL_GRADIENTLAYER_DEBUG
                        } else {
                            missCount++;
#endif
                        }
                    }
                } else {
                    hitCount++;
                }
                
                CGFloat position = (angle - segmentLookup[segmentIndex].start)/segmentLookup[segmentIndex].delta;
                
                IDLGradientLayerSegmentComponents components = segmentComponents[segmentIndex];
                
                bitmap[i] =   (components.start.r + position * components.delta.r) * 0xff;
                bitmap[i+1] = (components.start.g + position * components.delta.g) * 0xff;
                bitmap[i+2] = (components.start.b + position * components.delta.b) * 0xff;
                bitmap[i+3] = (components.start.a + position * components.delta.a) * 0xff;
            } else {
                bitmap[i] = bitmap[i+1] = bitmap[i+2] = bitmap[i+3] = 0x0;
            }
            i += 4;
        }
        //NSLog(@" \t");
    }
    
#ifdef IDL_GRADIENTLAYER_DEBUG
    NSLog(@"hit count: %li",hitCount);
    NSLog(@"miss count: %li",missCount);
    NSLog(@"score: %li",(hitCount-missCount));
#endif
    
}

@end
