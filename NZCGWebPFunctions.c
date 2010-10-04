/*
 *  NZCGWebPFunctions.c
 *  Weppy
 *
 *  Created by Nick Zitzmann on 10/3/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#include "NZCGWebPFunctions.h"
#include <stdio.h>
#include "webpimg.h"

CGImageRef NZCGImageCreateUsingWebPData(CFDataRef webPData)
{
	uint8 *y = NULL, *u = NULL, *v = NULL;
	int32_t width, height;
	
	// Step 1: Decode the data.
	if (WebPDecode(CFDataGetBytePtr(webPData), CFDataGetLength(webPData), &y, &u, &v, &width, &height) == webp_success)
	{
		const int32_t depth = 32;
		const int wordsPerLine = (width*depth+31)/32;
		size_t pixelBytesLength = 4*height*wordsPerLine;	// Google's documentation is incorrect here; the length has to be quadrupled or we'll have an overrun
		uint32 *pixelBytes = malloc(pixelBytesLength);
		CFDataRef pixelData;
		CGDataProviderRef dataProvider;
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		CGImageRef theImage;
		
		// Step 2: Convert the YUV data into RGB.
		YUV420toRGBA(y, u, v, wordsPerLine, width, height, pixelBytes);
		
		// Step 3: Convert the RGB data into a CGImageRef.
		pixelData = CFDataCreateWithBytesNoCopy(NULL, (const UInt8 *)pixelBytes, pixelBytesLength, NULL);
		dataProvider = CGDataProviderCreateWithCFData(pixelData);
		theImage = CGImageCreate(width,
								 height,
								 8,		// each component is one byte or 8 bits large
								 32,	// our data has four components
								 wordsPerLine*4,	// there are 32 bits or 4 bytes in a word
								 colorSpace,
								 kCGBitmapByteOrder32Host,	// our data is in host-endian format
								 dataProvider,
								 NULL,	// we don't care about decode arrays
								 true,	// sure, why not interpolate?
								 kCGRenderingIntentDefault);
		
		// Finally, clean up memory.
		CGColorSpaceRelease(colorSpace);
		CGDataProviderRelease(dataProvider);
		CFRelease(pixelData);
		free(y);
		return theImage;
	}
	fprintf(stderr, "NZCGWebPFunctions: The data provided is not in WebP format.\n");
	return NULL;
}
