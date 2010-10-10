//
//  WeppyView.m
//  Weppy
//
//  Created by Nick Zitzmann on 10/4/10.
//  Copyright __MyCompanyName__ 2010. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
		// Draw the image using CoreAnimation:
		self.layer.contents = (id)image;
		self.layer.contentsGravity = kCAGravityResize;	// here we want the image to get upscaled or downscaled if necessary
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
		
		[NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:fullURL] delegate:self];	// we don't need to retain this because NSURLConnection retains its delegate
	}
	
	// This plugin does all of its drawing using CoreAnimation (well, except when printing):
	self.layer = [CALayer layer];
	self.wantsLayer = YES;
    return self;
}

@end
