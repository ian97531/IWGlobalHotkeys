//
//  EMTLAppDelegate.h
//  IWGlobalHotkeys
//
//  Created by Ian White on 7/13/12.
//  Copyright (c) 2012 Never Ending Radical Developer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IWGlobalHotkey;

@interface EMTLAppDelegate : NSObject <NSApplicationDelegate>
{
    IWGlobalHotkey *_hotKey1;
    IWGlobalHotkey *_hotKey2;
    IWGlobalHotkey *_hotKey3;
    
}

@property (assign) IBOutlet NSWindow *window;

- (void)aMethodCallback;
- (void)anotherMethodCallback;
- (void)thirdMethodCallback;

@end
