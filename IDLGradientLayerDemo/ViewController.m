//
//  ViewController.m
//  IDLGradientLayerDemo
//
//  Created by Trystan Pfluger on 9/01/2015.
//  Copyright (c) 2015 Idlepixel. All rights reserved.
//

#import "ViewController.h"
#import "IDLGradientLayer.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self drawGradient];
}

-(void)drawGradient
{
    IDLGradientLayer *layer = [IDLGradientLayer layer];
    layer.frame = self.view.bounds;
    layer.rotation = 0.0f;
    layer.colors = @[
                     (__bridge NSObject *)[UIColor redColor].CGColor,
                     (__bridge NSObject *)[UIColor whiteColor].CGColor,
                     (__bridge NSObject *)[UIColor blackColor].CGColor,
                     (__bridge NSObject *)[UIColor colorWithWhite:0.5f alpha:1.0f].CGColor,
                     (__bridge NSObject *)[UIColor yellowColor].CGColor,
                     (__bridge NSObject *)[UIColor greenColor].CGColor,
                     (__bridge NSObject *)[UIColor blueColor].CGColor];
    //layer.locations =  @[@(0.2f),@(0.5f),@(0.8f)];
    layer.center = CGPointMake(100.0f, 100.0f);
    
    [self.view.layer addSublayer:layer];
    
    /*/
    int radius = 100;
    
    CAShapeLayer *arc = [CAShapeLayer layer];
    arc.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(100, 50) radius:radius startAngle:60.0 endAngle:0.0 clockwise:YES].CGPath;
    
    arc.position = CGPointMake(CGRectGetMidX(self.view.frame)-radius,
                               CGRectGetMidY(self.view.frame)-radius);
    
    arc.fillColor = [UIColor clearColor].CGColor;
    arc.strokeColor = [UIColor purpleColor].CGColor;
    arc.lineWidth = 15;
    CABasicAnimation *drawAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    drawAnimation.duration            = 5.0; // "animate over 10 seconds or so.."
    drawAnimation.repeatCount         = 1.0;  // Animate only once..
    drawAnimation.removedOnCompletion = NO;   // Remain stroked after the animation..
    drawAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
    drawAnimation.toValue   = [NSNumber numberWithFloat:10.0f];
    drawAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    [arc addAnimation:drawAnimation forKey:@"drawCircleAnimation"];
    
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = self.view.frame;
    gradientLayer.colors = @[(__bridge id)[UIColor redColor].CGColor,(__bridge id)[UIColor blueColor].CGColor ];
    gradientLayer.startPoint = CGPointMake(0,0.5);
    gradientLayer.endPoint = CGPointMake(1,0.5);
    
    [self.view.layer addSublayer:gradientLayer];
    //Using arc as a mask instead of adding it as a sublayer.
    //[self.view.layer addSublayer:arc];
    //gradientLayer.mask = arc;
     
     //*/
}

@end
