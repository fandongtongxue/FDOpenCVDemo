//
//  CropViewController.m
//  CropIDCardDemo
//
//  Created by 范东 on 17/3/9.
//  Copyright © 2017年 fandong.me. All rights reserved.
//

#import "CropViewController.h"
#import "MMCropView.h"
#import "MMOpenCVHelper.h"
#import "UIImageView+ContentFrame.h"
#include <vector>

@interface CropViewController ()<UIImagePickerControllerDelegate,UINavigationControllerDelegate>

@property (strong ,nonatomic) UIImagePickerController *imagePickerController;

@property (nonatomic, strong) UIImageView *sourceImageView;
@property (nonatomic, strong) MMCropView *cropView;
@property (nonatomic, copy) tapCropImageBlock tapCropImageBlock;
@property (nonatomic, strong) UIImage *sourceImage;
@property (nonatomic, strong) UIView *backView;

@end

@implementation CropViewController

#pragma mark - Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    [self selectPhoto];
}

#pragma mark - UI

- (void)initOperationButton{
    
    UIView *backView = [[UIView alloc]initWithFrame:CGRectMake(0, self.view.bounds.size.height - 50, self.view.bounds.size.width, 50)];
    backView.backgroundColor = [UIColor blackColor];
    backView.alpha = 0.5;
    [self.view addSubview:backView];
    self.backView = backView;
    
    UIButton *retakeBtn = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 50, 50)];
    [retakeBtn setTitle:@"重拍" forState:UIControlStateNormal];
    [retakeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [retakeBtn addTarget:self action:@selector(retakePhoto) forControlEvents:UIControlEventTouchUpInside];
    [backView addSubview:retakeBtn];
    
    UIButton *confimBtn = [[UIButton alloc]initWithFrame:CGRectMake(self.view.bounds.size.width - 50, 0, 50, 50)];
    [confimBtn setTitle:@"确定" forState:UIControlStateNormal];
    [confimBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [confimBtn addTarget:self action:@selector(dismissVC) forControlEvents:UIControlEventTouchUpInside];
    [backView addSubview:confimBtn];
}

- (void)initSourceImageView{
    _sourceImageView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 64, self.view.bounds.size.width, self.view.bounds.size.height - 64)];
    _sourceImageView.contentMode = UIViewContentModeScaleAspectFit;
    _sourceImageView.image = _sourceImage;
    _sourceImageView.clipsToBounds = YES;
    _sourceImageView.hidden = YES;
    [self.view addSubview:_sourceImageView];
}

#pragma mark - Action
- (void)cropImage:(UIButton *)sender{
    if([_cropView frameEdited]){
        //Thanks To stackOverflow
        CGFloat scaleFactor =  [_sourceImageView contentScale];
        CGPoint ptBottomLeft = [_cropView coordinatesForPoint:1 withScaleFactor:scaleFactor];
        CGPoint ptBottomRight = [_cropView coordinatesForPoint:2 withScaleFactor:scaleFactor];
        CGPoint ptTopRight = [_cropView coordinatesForPoint:3 withScaleFactor:scaleFactor];
        CGPoint ptTopLeft = [_cropView coordinatesForPoint:4 withScaleFactor:scaleFactor];
        CGFloat w1 = sqrt( pow(ptBottomRight.x - ptBottomLeft.x , 2) + pow(ptBottomRight.x - ptBottomLeft.x, 2));
        CGFloat w2 = sqrt( pow(ptTopRight.x - ptTopLeft.x , 2) + pow(ptTopRight.x - ptTopLeft.x, 2));
        CGFloat h1 = sqrt( pow(ptTopRight.y - ptBottomRight.y , 2) + pow(ptTopRight.y - ptBottomRight.y, 2));
        CGFloat h2 = sqrt( pow(ptTopLeft.y - ptBottomLeft.y , 2) + pow(ptTopLeft.y - ptBottomLeft.y, 2));
        CGFloat maxWidth = (w1 < w2) ? w1 : w2;
        CGFloat maxHeight = (h1 < h2) ? h1 : h2;
        cv::Point2f src[4], dst[4];
        src[0].x = ptTopLeft.x;
        src[0].y = ptTopLeft.y;
        src[1].x = ptTopRight.x;
        src[1].y = ptTopRight.y;
        src[2].x = ptBottomRight.x;
        src[2].y = ptBottomRight.y;
        src[3].x = ptBottomLeft.x;
        src[3].y = ptBottomLeft.y;
        dst[0].x = 0;
        dst[0].y = 0;
        dst[1].x = maxWidth - 1;
        dst[1].y = 0;
        dst[2].x = maxWidth - 1;
        dst[2].y = maxHeight - 1;
        dst[3].x = 0;
        dst[3].y = maxHeight - 1;
        cv::Mat undistorted = cv::Mat( cvSize(maxWidth,maxHeight), CV_8UC4);
        cv::Mat original = [MMOpenCVHelper cvMatFromUIImage:_sourceImage];
        NSLog(@"%f %f %f %f",ptBottomLeft.x,ptBottomRight.x,ptTopRight.x,ptTopLeft.x);
        cv::warpPerspective(original, undistorted, cv::getPerspectiveTransform(src, dst), cvSize(maxWidth, maxHeight));
        [UIView transitionWithView:_sourceImageView duration:0.25 options:UIViewAnimationOptionTransitionNone animations:^{
            _sourceImageView.image=[MMOpenCVHelper UIImageFromCVMat:undistorted];
            _sourceImageView.hidden = NO;
            self.backView.hidden = NO;
            //For gray image
//         _sourceImageView.image = [MMOpenCVHelper UIImageFromCVMat:grayImage];
        } completion:^(BOOL finished) {
            _cropView.hidden=YES;
        }];
        original.release();
        undistorted.release();
        sender.enabled = NO;
        [self initOperationButton];
    }
    else{
        NSLog(@"Invalid Rect");
    }
}

- (void)dismissVC{
    if (_tapCropImageBlock) {
        _tapCropImageBlock(_sourceImageView.image);
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)retakePhoto{
    NSLog(@"重新选取图片");
    _sourceImageView.image = nil;
    self.backView.hidden = YES;
    [self selectPhoto];
}

#pragma mark OpenCV
- (void)detectEdges{
    cv::Mat original = [MMOpenCVHelper cvMatFromUIImage:_sourceImageView.image];
    CGSize targetSize = _sourceImageView.contentSize;
    cv::resize(original, original, cvSize(targetSize.width, targetSize.height));
    std::vector<std::vector<cv::Point>>squares;
    std::vector<cv::Point> largest_square;
    find_squares(original, squares);
    find_largest_square(squares, largest_square);
    if (largest_square.size() == 4)
    {
        // Manually sorting points, needs major improvement. Sorry.
        NSMutableArray *points = [NSMutableArray array];
        NSMutableDictionary *sortedPoints = [NSMutableDictionary dictionary];
        for (int i = 0; i < 4; i++){
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithCGPoint:CGPointMake(largest_square[i].x, largest_square[i].y)], @"point" , [NSNumber numberWithInt:(largest_square[i].x + largest_square[i].y)], @"value", nil];
            [points addObject:dict];
        }
        int min = [[points valueForKeyPath:@"@min.value"] intValue];
        int max = [[points valueForKeyPath:@"@max.value"] intValue];
        int minIndex = 0;
        int maxIndex = 0;
        int missingIndexOne = 0;
        int missingIndexTwo = 0;
        for (int i = 0; i < 4; i++){
            NSDictionary *dict = [points objectAtIndex:i];
            
            if ([[dict objectForKey:@"value"] intValue] == min){
                [sortedPoints setObject:[dict objectForKey:@"point"] forKey:@"0"];
                minIndex = i;
                continue;
            }
            if ([[dict objectForKey:@"value"] intValue] == max){
                [sortedPoints setObject:[dict objectForKey:@"point"] forKey:@"2"];
                maxIndex = i;
                continue;
            }
            NSLog(@"MSSSING %i", i);
            missingIndexOne = i;
        }
        for (int i = 0; i < 4; i++){
            if (missingIndexOne != i && minIndex != i && maxIndex != i){
                missingIndexTwo = i;
            }
        }
        if (largest_square[missingIndexOne].x < largest_square[missingIndexTwo].x){
            //2nd Point Found
            [sortedPoints setObject:[[points objectAtIndex:missingIndexOne] objectForKey:@"point"] forKey:@"3"];
            [sortedPoints setObject:[[points objectAtIndex:missingIndexTwo] objectForKey:@"point"] forKey:@"1"];
        }
        else{
            //4rd Point Found
            [sortedPoints setObject:[[points objectAtIndex:missingIndexOne] objectForKey:@"point"] forKey:@"1"];
            [sortedPoints setObject:[[points objectAtIndex:missingIndexTwo] objectForKey:@"point"] forKey:@"3"];
        }
        [_cropView topLeftCornerToCGPoint:[(NSValue *)[sortedPoints objectForKey:@"0"] CGPointValue]];
        [_cropView topRightCornerToCGPoint:[(NSValue *)[sortedPoints objectForKey:@"1"] CGPointValue]];
        [_cropView bottomRightCornerToCGPoint:[(NSValue *)[sortedPoints objectForKey:@"2"] CGPointValue]];
        [_cropView bottomLeftCornerToCGPoint:[(NSValue *)[sortedPoints objectForKey:@"3"] CGPointValue]];
        NSLog(@"%@ Sorted Points",sortedPoints);
    }
    else{
        
    }
    original.release();
}

#pragma mark - find_squares find_largest_square angle
// http://stackoverflow.com/questions/8667818/opencv-c-obj-c-detecting-a-sheet-of-paper-square-detection
void find_squares(cv::Mat& image, std::vector<std::vector<cv::Point>>&squares) {
    // blur will enhance edge detection
    cv::Mat blurred(image);
    //    medianBlur(image, blurred, 9);
    GaussianBlur(image, blurred, cvSize(11,11), 0);//change from median blur to gaussian for more accuracy of square detection
    cv::Mat gray0(blurred.size(), CV_8U), gray;
    std::vector<std::vector<cv::Point> > contours;
    // find squares in every color plane of the image
    for (int c = 0; c < 3; c++){
        int ch[] = {c, 0};
        mixChannels(&blurred, 1, &gray0, 1, ch, 1);
        // try several threshold levels
        const int threshold_level = 2;
        for (int l = 0; l < threshold_level; l++)
        {
            // Use Canny instead of zero threshold level!
            // Canny helps to catch squares with gradient shading
            if (l == 0){
                Canny(gray0, gray, 10, 20, 3); //
                //                Canny(gray0, gray, 0, 50, 5);
                
                // Dilate helps to remove potential holes between edge segments
                dilate(gray, gray, cv::Mat(), cv::Point(-1,-1));
            }
            else{
                gray = gray0 >= (l+1) * 255 / threshold_level;
            }
            // Find contours and store them in a list
            findContours(gray, contours, CV_RETR_LIST, CV_CHAIN_APPROX_SIMPLE);
            // Test contours
            std::vector<cv::Point> approx;
            for (size_t i = 0; i < contours.size(); i++){
                // approximate contour with accuracy proportional
                // to the contour perimeter
                approxPolyDP(cv::Mat(contours[i]), approx, arcLength(cv::Mat(contours[i]), true)*0.02, true);
                // Note: absolute value of an area is used because
                // area may be positive or negative - in accordance with the
                // contour orientation
                if (approx.size() == 4 &&
                    fabs(contourArea(cv::Mat(approx))) > 1000 &&
                    isContourConvex(cv::Mat(approx))){
                    double maxCosine = 0;
                    for (int j = 2; j < 5; j++){
                        double cosine = fabs(angle(approx[j%4], approx[j-2], approx[j-1]));
                        maxCosine = MAX(maxCosine, cosine);
                    }
                    if (maxCosine < 0.3)
                        squares.push_back(approx);
                }
            }
        }
    }
}

void find_largest_square(const std::vector<std::vector<cv::Point> >& squares, std::vector<cv::Point>& biggest_square){
    if (!squares.size()){
        // no squares detected
        return;
    }
    int max_width = 0;
    int max_height = 0;
    int max_square_idx = 0;
    for (size_t i = 0; i < squares.size(); i++){
        // Convert a set of 4 unordered Points into a meaningful cv::Rect structure.
        cv::Rect rectangle = boundingRect(cv::Mat(squares[i]));
        //        cout << "find_largest_square: #" << i << " rectangle x:" << rectangle.x << " y:" << rectangle.y << " " << rectangle.width << "x" << rectangle.height << endl;
        // Store the index position of the biggest square found
        if ((rectangle.width >= max_width) && (rectangle.height >= max_height))
        {
            max_width = rectangle.width;
            max_height = rectangle.height;
            max_square_idx = i;
        }
    }
    biggest_square = squares[max_square_idx];
}

double angle( cv::Point pt1, cv::Point pt2, cv::Point pt0 ) {
    double dx1 = pt1.x - pt0.x;
    double dy1 = pt1.y - pt0.y;
    double dx2 = pt2.x - pt0.x;
    double dy2 = pt2.y - pt0.y;
    return (dx1*dx2 + dy1*dy2)/sqrt((dx1*dx1 + dy1*dy1)*(dx2*dx2 + dy2*dy2) + 1e-10);
}

- (void)setTapCropImageBlock:(tapCropImageBlock)block{
    _tapCropImageBlock = block;
}

#pragma mark - Photo
- (void)selectPhoto{
    UIAlertController *alert = [[UIAlertController alloc]init];
    [alert addAction:[UIAlertAction actionWithTitle:@"拍照" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"拍照");
        _imagePickerController = [[UIImagePickerController alloc]init];
        _imagePickerController.delegate = self;
        _imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
        _imagePickerController.allowsEditing = NO;
        _imagePickerController.mediaTypes = [NSArray arrayWithObjects:(NSString *)kUTTypeImage, nil];
        [self presentViewController:_imagePickerController animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"从相册中选取" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"从相册中选取");
        _imagePickerController = [[UIImagePickerController alloc]init];
        _imagePickerController.delegate = self;
        _imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        _imagePickerController.allowsEditing = NO;
        _imagePickerController.mediaTypes = [NSArray arrayWithObjects:(NSString *)kUTTypeImage, nil];
        [self presentViewController:_imagePickerController animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"用户取消选择图片");
        self.backView.hidden = YES;
        [self presentViewController:alert animated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [_imagePickerController dismissViewControllerAnimated:YES completion:nil];
    [_imagePickerController removeFromParentViewController];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    [_imagePickerController dismissViewControllerAnimated:YES completion:nil];
    [_imagePickerController removeFromParentViewController];
    _sourceImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    [self initSourceImageView];
    CGRect cropFrame = CGRectMake(_sourceImageView.contentFrame.origin.x, _sourceImageView.contentFrame.origin.y + 64, _sourceImageView.contentFrame.size.width, _sourceImageView.contentFrame.size.height);
    _cropView = [[MMCropView alloc]initWithFrame:cropFrame];
    _cropView.hidden = YES;
    [self.view addSubview:_cropView];
    [self.view bringSubviewToFront:_cropView];
    [self detectEdges];
    [self performSelector:@selector(cropImage:) withObject:nil afterDelay:0.25];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
