//
//  CropViewController.h
//  CropIDCardDemo
//
//  Created by 范东 on 17/3/9.
//  Copyright © 2017年 fandong.me. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^tapCropImageBlock)(UIImage *finalImage);

@interface CropViewController : UIViewController


/**
 设置裁剪最终图片的回调

 @param block block对象
 */
- (void)setTapCropImageBlock:(tapCropImageBlock)block;

@end
