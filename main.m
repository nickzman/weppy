//
//  main.m
//  Weppy
//
//  Created by Nick Zitzmann on 10/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import <WebKit/npapi.h>
#import <WebKit/npfunctions.h>
#import <WebKit/npruntime.h>

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import "NZCGWebPFunctions.h"

// Browser function table
static NPNetscapeFuncs* browser;

// Structure for per-instance storage
typedef struct PluginObject
{
    NPP npp;
    
    NPWindow window;
	
	CALayer *caLayer;
	NSMutableData *streamedData;
	CGImageRef theImage;
	NPBool drawCentered;
} PluginObject;

NPError NPP_New(NPMIMEType pluginType, NPP instance, uint16_t mode, int16_t argc, char* argn[], char* argv[], NPSavedData* saved);
NPError NPP_Destroy(NPP instance, NPSavedData** save);
NPError NPP_SetWindow(NPP instance, NPWindow* window);
NPError NPP_NewStream(NPP instance, NPMIMEType type, NPStream* stream, NPBool seekable, uint16_t* stype);
NPError NPP_DestroyStream(NPP instance, NPStream* stream, NPReason reason);
int32 NPP_WriteReady(NPP instance, NPStream* stream);
int32 NPP_Write(NPP instance, NPStream* stream, int32 offset, int32 len, void* buffer);
void NPP_StreamAsFile(NPP instance, NPStream* stream, const char* fname);
void NPP_Print(NPP instance, NPPrint* platformPrint);
int16_t NPP_HandleEvent(NPP instance, void* event);
void NPP_URLNotify(NPP instance, const char* URL, NPReason reason, void* notifyData);
NPError NPP_GetValue(NPP instance, NPPVariable variable, void *value);
NPError NPP_SetValue(NPP instance, NPNVariable variable, void *value);

//#pragma export on
// Mach-o entry points
NPError NP_Initialize(NPNetscapeFuncs *browserFuncs);
NPError NP_GetEntryPoints(NPPluginFuncs *pluginFuncs);
void NP_Shutdown(void);
//#pragma export off

NPError NP_Initialize(NPNetscapeFuncs* browserFuncs)
{
    browser = browserFuncs;
    return NPERR_NO_ERROR;
}


NPError NP_GetEntryPoints(NPPluginFuncs* pluginFuncs)
{
    pluginFuncs->version = 11;
    pluginFuncs->size = sizeof(pluginFuncs);
    pluginFuncs->newp = NPP_New;
    pluginFuncs->destroy = NPP_Destroy;
    pluginFuncs->setwindow = NPP_SetWindow;
    pluginFuncs->newstream = NPP_NewStream;
    pluginFuncs->destroystream = NPP_DestroyStream;
    pluginFuncs->asfile = NPP_StreamAsFile;
    pluginFuncs->writeready = NPP_WriteReady;
    pluginFuncs->write = (NPP_WriteProcPtr)NPP_Write;
    pluginFuncs->print = NPP_Print;
    pluginFuncs->event = NPP_HandleEvent;
    pluginFuncs->urlnotify = NPP_URLNotify;
    pluginFuncs->getvalue = NPP_GetValue;
    pluginFuncs->setvalue = NPP_SetValue;
    
    return NPERR_NO_ERROR;
}


void NP_Shutdown(void)
{
	
}


NPError NPP_New(NPMIMEType pluginType, NPP instance, uint16_t mode, int16_t argc, char* argn[], char* argv[], NPSavedData* saved)
{
    // Create per-instance storage
    PluginObject *obj = (PluginObject *)malloc(sizeof(PluginObject));
	NPBool supportsCoreGraphics;
	NPBool supportsCoreAnimation = FALSE;
	NPBool supportsCocoa;
	
    bzero(obj, sizeof(PluginObject));
    
    obj->npp = instance;
    instance->pdata = obj;
    
    // Ask the browser if it supports the CoreGraphics drawing model
    if (browser->getvalue(instance, NPNVsupportsCoreGraphicsBool, &supportsCoreGraphics) != NPERR_NO_ERROR)
        supportsCoreGraphics = FALSE;
#ifdef __LP64__
	if (browser->getvalue(instance, NPNVsupportsCoreAnimationBool, &supportsCoreAnimation) != NPERR_NO_ERROR)
		supportsCoreAnimation = FALSE;
#endif
    if (!supportsCoreGraphics && !supportsCoreAnimation)	// we don't support QuickDraw, sorry
        return NPERR_INCOMPATIBLE_VERSION_ERROR;
    
	// Prefer CoreAnimation over CoreGraphics when choosing drawing models.
#ifdef __LP64__
	if (supportsCoreAnimation)
	{
		browser->setvalue(instance, NPNVpluginDrawingModel, (void *)NPDrawingModelCoreAnimation);
		obj->caLayer = [[CALayer alloc] init];
	}
	else
#endif
	{
		browser->setvalue(instance, NPNVpluginDrawingModel, (void *)NPDrawingModelCoreGraphics);
	}
	
#ifdef __LP64__
    // If the browser supports the Cocoa event model, enable it.
    if (browser->getvalue(instance, NPNVsupportsCocoaBool, &supportsCocoa) != NPERR_NO_ERROR)
        supportsCocoa = FALSE;
    
    if (!supportsCocoa)
        return NPERR_INCOMPATIBLE_VERSION_ERROR;
    
    browser->setvalue(instance, NPPVpluginEventModel, (void *)NPEventModelCocoa);
#else
	supportsCocoa = FALSE;
#endif
    
    return NPERR_NO_ERROR;
}


NPError NPP_Destroy(NPP instance, NPSavedData** save)
{
    // Free per-instance storage
    PluginObject *obj = instance->pdata;
    
	[obj->caLayer release];
	[obj->streamedData release];
	if (obj->theImage)
		CGImageRelease(obj->theImage);
    
    free(obj);
    
    return NPERR_NO_ERROR;
}


NPError NPP_SetWindow(NPP instance, NPWindow* window)
{
    PluginObject *obj = instance->pdata;
	
	/*if (window->window)
	{
		NP_CGContext *npcontext = window->window;
		CGContextRef context = npcontext->context;
		
		obj->boundingBox = CGContextGetClipBoundingBox(context);
	}*/
    obj->window = *window;
    return NPERR_NO_ERROR;
}


NPError NPP_NewStream(NPP instance, NPMIMEType type, NPStream* stream, NPBool seekable, uint16_t* stype)
{
	PluginObject *obj = instance->pdata;
	
	*stype = NP_NORMAL;
	[obj->streamedData release];
	obj->streamedData = [[NSMutableData alloc] init];
    return NPERR_NO_ERROR;
}


NPError NPP_DestroyStream(NPP instance, NPStream* stream, NPReason reason)
{
	PluginObject *obj = instance->pdata;
	
	if (reason == NPRES_DONE)
	{
		obj->theImage = NZCGImageCreateUsingWebPData((CFDataRef)obj->streamedData);
		
		if (obj->theImage)
		{
			obj->caLayer.contentsGravity = kCAGravityResizeAspect;
			obj->caLayer.contents = (id)obj->theImage;
		}
	}
	
	if (reason != NPRES_DONE || obj->theImage == NULL)
	{
		// If we couldn't load the image for some reason, then display a broken image:
		NSBundle *webCoreBundle = [NSBundle bundleWithPath:@"/System/Library/Frameworks/WebKit.framework/Frameworks/WebCore.framework"];
		NSString *missingImagePath = [webCoreBundle pathForImageResource:@"missingImage"];
		CGImageSourceRef missingImageSource = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:missingImagePath], (CFDictionaryRef)[NSDictionary dictionary]);
		CGImageRef missingImage = CGImageSourceCreateImageAtIndex(missingImageSource, 0UL, (CFDictionaryRef)[NSDictionary dictionary]);
		
		obj->caLayer.contentsGravity = kCAGravityCenter;
		obj->caLayer.contents = (id)missingImage;
		obj->theImage = missingImage;
		obj->drawCentered = TRUE;
		CFRelease(missingImageSource);
	}
	
	if (!obj->caLayer)	// don't invalidate if CoreAnimation is being used because Safari will clear the screen if we're running in a background task, which is not what we want
	{
		NPRect invalidateRect;
		
		invalidateRect.left = 0;
		invalidateRect.top = 0;
		invalidateRect.right = obj->window.width;
		invalidateRect.bottom = obj->window.height;
		browser->invalidaterect(obj->npp, &invalidateRect);
	}
	return NPERR_NO_ERROR;
}

int32 NPP_WriteReady(NPP instance, NPStream* stream)
{
    return INT_MAX;	// bring it on!
}

int32 NPP_Write(NPP instance, NPStream* stream, int32 offset, int32 len, void* buffer)
{
	PluginObject *obj = instance->pdata;
	
	[obj->streamedData appendBytes:buffer length:len];
    return len;
}

void NPP_StreamAsFile(NPP instance, NPStream* stream, const char* fname)
{
}

void NPP_Print(NPP instance, NPPrint* platformPrint)
{
	
}


static void DrawUsingCoreGraphics(PluginObject *obj, CGContextRef cgContext)
{
	NSGraphicsContext *oldContext = [[NSGraphicsContext currentContext] retain];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithGraphicsPort:cgContext flipped:YES];
	CGRect boundingBox = CGContextGetClipBoundingBox(cgContext);
	CGSize imageSize = CGSizeMake(CGImageGetWidth(obj->theImage), CGImageGetHeight(obj->theImage));
	
	[NSGraphicsContext setCurrentContext:context];
	// Draw the background:
	[[NSColor whiteColor] set];
	NSRectFillUsingOperation(boundingBox, NSCompositeSourceOver);
	// Flip the context so the image draws right side up:
	CGContextTranslateCTM(cgContext, 0, imageSize.height);
	CGContextScaleCTM(cgContext, 1.0, -1.0);
	if (obj->theImage)
	{
		if (obj->drawCentered)
			CGContextDrawImage(cgContext, CGRectMake(obj->window.width/2.0-imageSize.width/2.0, obj->window.height/2.0-imageSize.height/2.0, imageSize.width, imageSize.height), obj->theImage);
		else
			CGContextDrawImage(cgContext, CGRectMake(0.0, 0.0, imageSize.width, imageSize.height), obj->theImage);
	}
	[NSGraphicsContext setCurrentContext:oldContext];
}


int16_t NPP_HandleEvent(NPP instance, void* event)
{
	PluginObject *obj = instance->pdata;
#ifdef __LP64__
    NPCocoaEvent *cocoaEvent = event;
    
    switch(cocoaEvent->type)
	{
		case NPCocoaEventDrawRect:
			if (!obj->caLayer)
			{
				DrawUsingCoreGraphics(obj, cocoaEvent->data.draw.context);
				return 1;
			}
			break;
		default:
			break;
	}
#else
	EventRecord *carbonEvent = event;
	
	if (carbonEvent->what == updateEvt)
	{
		NP_CGContext *npcontext = obj->window.window;
		CGContextRef context = npcontext->context;
		
		DrawUsingCoreGraphics(obj, context);
	}
#endif
	return 0;
}

void NPP_URLNotify(NPP instance, const char* url, NPReason reason, void* notifyData)
{
	
}

NPError NPP_GetValue(NPP instance, NPPVariable variable, void *value)
{
#ifdef __LP64__
	PluginObject *obj = instance->pdata;
	
	if (variable == NPPVpluginCoreAnimationLayer)
	{
		*((CALayer **)value) = [obj->caLayer retain];
		return NPERR_NO_ERROR;
	}
#endif
    return NPERR_GENERIC_ERROR;
}

NPError NPP_SetValue(NPP instance, NPNVariable variable, void *value)
{
    return NPERR_GENERIC_ERROR;
}
