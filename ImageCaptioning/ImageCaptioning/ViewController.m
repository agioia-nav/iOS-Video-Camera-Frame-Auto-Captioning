//
//  ViewController.m
//  ImageCaptioning
//
//  Created by Antonio Gioia on 04/01/16.
//  Copyright © 2016 MyCompany. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *caption;
@property (weak, nonatomic) IBOutlet UIImageView *cameraView;
@property(nonatomic,strong)AVCaptureSession* session;
@property(atomic)int count;
@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	if (!self.session)
	{
		[self setupCaptureSession];
	}
	else
	{
		[self.session startRunning];
	}
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - Private

// Create and configure a capture session and start it running
- (void)setupCaptureSession
{
	NSError *error = nil;
 
	// Create the session
	AVCaptureSession *session = [[AVCaptureSession alloc] init];
 
	// Configure the session to produce lower resolution video frames, if your
	// processing algorithm can cope. We'll specify medium quality for the
	// chosen device.
	session.sessionPreset = AVCaptureSessionPresetMedium;
 
	// Find a suitable AVCaptureDevice
	AVCaptureDevice *device = [AVCaptureDevice
							   defaultDeviceWithMediaType:AVMediaTypeVideo];
	
	[device lockForConfiguration:nil];
	[device setActiveVideoMaxFrameDuration:CMTimeMake(1, 10)];
	[device setActiveVideoMinFrameDuration:CMTimeMake(1, 10)];
	[device unlockForConfiguration];
	
	// Create a device input with the device and add it to the session.
	AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
																		error:&error];
	if (!input) {
		// Handling the error appropriately.
	}
	[session addInput:input];
 
	// Create a VideoDataOutput and add it to the session
	AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
	[session addOutput:output];
 
	// Configure your output.
	dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
	[output setSampleBufferDelegate:self queue:queue];
	
 
	// Specify the pixel format
	output.videoSettings =
	[NSDictionary dictionaryWithObject:
	 [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
								forKey:(id)kCVPixelBufferPixelFormatTypeKey];
	
	AVCaptureConnection *videoConnection = nil;
	for (AVCaptureConnection *connection in [output connections]) {
		for (AVCaptureInputPort *port in [connection inputPorts]) {
			if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
				videoConnection = connection;
				break;
			}
		}
		if (videoConnection) {
			break;
		}
	}
	[videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
	
 
	// Start the session running to start the flow of data
	[session startRunning];
 
	// Assign session to an ivar.
	[self setSession:session];
}

// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
	   fromConnection:(AVCaptureConnection *)connection
{
	// Create a UIImage from the sample buffer data
	UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
	
	
	if (self.count == 0)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			
			self.count++;
			NSData *data = UIImageJPEGRepresentation(image, 1.f);
			self.cameraView.image = image;
			
			
			[self sendImage:data completionBlock:^(NSString* response) {
				self.caption.text = response;
				self.count = 0;
			}];
		});
	}
	
}


- (void)sendImage:(NSData *)imageData completionBlock:(void (^) (NSString* caption))block
{
	//create request
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	
	//Set Params
	[request setHTTPShouldHandleCookies:NO];
	[request setTimeoutInterval:60];
	[request setHTTPMethod:@"POST"];
	
	//Create boundary, it can be anything
	NSString *boundary = @"------VohpleBoundary4QuqLuM1cE5lMwCy";
	
	// set Content-Type in HTTP header
	NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
	[request setValue:contentType forHTTPHeaderField: @"Content-Type"];
	
	// post body
	NSMutableData *body = [NSMutableData data];
	
	NSString *FileParamConstant = @"file";
	
	
	
	//Assuming data is not nil we add this to the multipart form
	if (imageData)
	{
		[body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"image.jpg\"\r\n", FileParamConstant] dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:[@"Content-Type:image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:imageData];
		[body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	//Close off the request with the boundary
	[body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	
	// setting the body of the post to the request
	[request setHTTPBody:body];
	
	// set URL
	[request setURL:[NSURL URLWithString:@"http://192.168.1.248:8080/Neuraltalk/rest/image/upload"]];
	
	[NSURLConnection sendAsynchronousRequest:request
									   queue:[NSOperationQueue mainQueue]
						   completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
							   
							   NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
							   
							   if (data)
							   {
								   NSDictionary* json = [NSJSONSerialization
														 JSONObjectWithData:data
														 options:kNilOptions
														 error:&error];
								   
								   if ([httpResponse statusCode] == 200) {
									
									    block([json objectForKey:@"caption"]);
								   }
							   }
							  
							   
						   }];

}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
	// Get a CMSampleBuffer's Core Video image buffer for the media data
	CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	// Lock the base address of the pixel buffer
	CVPixelBufferLockBaseAddress(imageBuffer, 0);
 
	// Get the number of bytes per row for the pixel buffer
	void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
 
	// Get the number of bytes per row for the pixel buffer
	size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
	// Get the pixel buffer width and height
	size_t width = CVPixelBufferGetWidth(imageBuffer);
	size_t height = CVPixelBufferGetHeight(imageBuffer);
 
	// Create a device-dependent RGB color space
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
 
	// Create a bitmap graphics context with the sample buffer data
	CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
												 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
	// Create a Quartz image from the pixel data in the bitmap graphics context
	CGImageRef quartzImage = CGBitmapContextCreateImage(context);
	// Unlock the pixel buffer
	CVPixelBufferUnlockBaseAddress(imageBuffer,0);
 
	// Free up the context and color space
	CGContextRelease(context);
	CGColorSpaceRelease(colorSpace);
 
	// Create an image object from the Quartz image
	UIImage *image = [UIImage imageWithCGImage:quartzImage];
 
	// Release the Quartz image
	CGImageRelease(quartzImage);
 
	return (image);
}

@end
