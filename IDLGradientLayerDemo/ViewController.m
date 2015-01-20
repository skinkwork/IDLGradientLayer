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

@property (nonatomic, weak) IDLGradientLayer *gradientLayer;

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
    
    [self performSelector:@selector(animateTest) withObject:nil afterDelay:4.0f];
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.gradientLayer.frame = self.view.bounds;
    //[self.gradientLayer updateLayer];
    //[self.gradientLayer setNeedsDisplay];
}

-(void)drawGradient
{
    IDLGradientLayer *layer = self.gradientLayer;
    if (layer == nil) {
        layer = [IDLGradientLayer layer];
        self.gradientLayer = layer;
    }
    CGRect frame = self.view.bounds;
    /*/
    frame.size.width = 200;
    frame.size.height = 100;
    frame.origin.x = 100;
    frame.origin.y = 100;
    //*/
    layer.scale = [UIScreen mainScreen].scale;
    layer.frame = frame;
    layer.rotation = M_PI_2;
    layer.colors = @[
                     (__bridge NSObject *)[UIColor redColor].CGColor,
                     (__bridge NSObject *)[UIColor purpleColor].CGColor,
                     (__bridge NSObject *)[UIColor blackColor].CGColor,
                     (__bridge NSObject *)[UIColor colorWithWhite:0.5f alpha:1.0f].CGColor,
                     (__bridge NSObject *)[UIColor yellowColor].CGColor,
                     (__bridge NSObject *)[UIColor greenColor].CGColor,
                     (__bridge NSObject *)[UIColor blueColor].CGColor,
                     //(__bridge NSObject *)[UIColor redColor].CGColor
                     ];
    //layer.locations =  @[@(0.2f),@(0.5f),@(0.8f)];
    layer.offset = CGPointMake(40.0f, 40.0f);
    layer.innerRadius = @(50.0f);
    layer.outerRadius = @(100.0f);
    
    [self.view.layer addSublayer:layer];
    
}

-(void)animateTest
{
    NSLog(@"animate test");
    self.gradientLayer.rotation = 0.0f;
}

@end
