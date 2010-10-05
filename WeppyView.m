//
//  WeppyView.m
//  Weppy
//
//  Created by Nick Zitzmann on 10/4/10.
//  Copyright __MyCompanyName__ 2010. All rights reserved.
//

#import "WeppyView.h"
#import <QuartzCore/QuartzCore.h>
#import "NZCGWebPFunctions.h"

@interface WeppyView (Internal)
- (id)_initWithArguments:(NSDictionary *)arguments;
@end

@implementation WeppyView

// WebPlugInViewFactory protocol
// The principal class of the plug-in bundle must implement this protocol.

+ (NSView *)plugInViewWithArguments:(NSDictionary *)newArguments
{
    return [[[self alloc] _initWithArguments:newArguments] autorelease];
}


- (void)dealloc
{
	[_downloadedData release];
	[super dealloc];
}


- (void)drawRect:(NSRect)dirtyRect
{
	// Normally we let CoreAnimation do all the compositing for us, but if there's a print job going on, we need to composite it manually.
	if ([NSPrintOperation currentOperation])
	{
		CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], self.bounds, (CGImageRef)self.layer.contents);
	}
}


// WebPlugIn informal protocol


- (void)webPlugInMainResourceDidFailWithError:(NSError *)error
{
	NSBundle *webCoreBundle = [NSBundle bundleWithPath:@"/System/Library/Frameworks/WebKit.framework/Frameworks/WebCore.framework"];
	NSString *missingImagePath = [webCoreBundle pathForImageResource:@"missingImage"];
	CGImageSourceRef missingImageSource = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:missingImagePath], (CFDictionaryRef)[NSDictionary dictionary]);
	CGImageRef missingImage = CGImageSourceCreateImageAtIndex(missingImageSource, 0UL, (CFDictionaryRef)[NSDictionary dictionary]);
	
	self.layer.contents = (id)missingImage;
	self.layer.contentsGravity = kCAGravityCenter;	// so the image doesn't get upscaled
	CGImageRelease(missingImage);
	CFRelease(missingImageSource);
	[_downloadedData release];
	_downloadedData = nil;
}


- (void)webPlugInMainResourceDidFinishLoading
{
	CGImageRef image = NZCGImageCreateUsingWebPData((CFDataRef)_downloadedData);
	
	if (image)
	{
		self.layer.contents = (id)image;
		self.layer.contentsGravity = kCAGravityResize;
	}
	else
		[self webPlugInMainResourceDidFailWithError:nil];	// if we couldn't decode the data, then draw the fail image
}


- (void)webPlugInMainResourceDidReceiveData:(NSData *)data
{
	if (!_downloadedData)
		_downloadedData = [[NSMutableData alloc] init];
	[_downloadedData appendData:data];
}


- (void)webPlugInMainResourceDidReceiveResponse:(NSURLResponse *)response
{
	// We don't particularly care, but I've heard that this method has to be here anyway.
}


#pragma mark -


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self webPlugInMainResourceDidFailWithError:error];
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[self webPlugInMainResourceDidReceiveData:data];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[self webPlugInMainResourceDidFinishLoading];
}

@end

@implementation WeppyView (Internal)

- (id)_initWithArguments:(NSDictionary *)newArguments
{
    if (!(self = [super initWithFrame:NSZeroRect]))
        return nil;
	
	NSURL *baseURL = [newArguments objectForKey:WebPlugInBaseURLKey];
	NSDictionary *attributes = [newArguments objectForKey:WebPlugInAttributesKey];
	BOOL shouldLoadMainResource = ([newArguments objectForKey:@"WebPlugInShouldLoadMainResourceKey"] ? [[newArguments objectForKey:@"WebPlugInShouldLoadMainResourceKey"] boolValue] : NO);
	
	if (shouldLoadMainResource)
	{
		NSURL *fullURL = [NSURL URLWithString:[attributes objectForKey:@"src"] relativeToURL:baseURL];
		
		[NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:fullURL] delegate:self];
	}
	
	self.layer = [CALayer layer];
	self.wantsLayer = YES;
    return self;
}

@end
