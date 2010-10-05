//
//  WeppyView.h
//  Weppy
//
//  Created by Nick Zitzmann on 10/4/10.
//  Copyright __MyCompanyName__ 2010. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface WeppyView : NSView <WebPlugInViewFactory>
{
	NSMutableData *_downloadedData;
}

@end
