//
//  EMTLAppDelegate.m
//  IWGlobalHotkeys
//
//  Created by Ian White on 7/13/12.
//  Copyright (c) 2012 Never Ending Radical Developer. All rights reserved.
//

#import "EMTLAppDelegate.h"
#import "IWGlobalHotkey.h"

@implementation EMTLAppDelegate

@synthesize window = _window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _hotKey1 = [IWGlobalHotkey globalHotKeyWithKey:@"B" 
                                         modifiers:[NSArray arrayWithObjects:IWGLOBALHOTKEY_COMMAND, IWGLOBALHOTKEY_OPTION, nil] 
                                            target:self 
                                            action:@selector(aMethodCallback)];
    
    _hotKey2 = [IWGlobalHotkey globalHotKeyWithKey:@"4" 
                                         modifiers:[NSArray arrayWithObjects:IWGLOBALHOTKEY_COMMAND, nil] 
                                            target:self 
                                            action:@selector(anotherMethodCallback)];
    
    _hotKey3 = [IWGlobalHotkey globalHotKeyWithKey:@"4" 
                                         modifiers:[NSArray arrayWithObjects:IWGLOBALHOTKEY_CONTROL, nil] 
                                            target:self 
                                            action:@selector(thirdMethodCallback)];
    
    if ([_hotKey1 installHotKey]) {
        NSLog(@"Installing the command-option-B hotkey");
    }
    
    if([_hotKey2 installHotKey]) {
        NSLog(@"Installing the command-4 hotkey");
    }
    
    if ([_hotKey3 installHotKey]) {
        NSLog(@"Installing the control-4 hotkey");
    }
    
}

- (void)aMethodCallback
{
    NSLog(@"You pushed command-option-B");
    if (_hotKey2.installed) {
        NSLog(@"Removing the command-4 hotkey");
        [_hotKey2 removeHotKey];
    }
    else {
        NSLog(@"Installing the command-4 hotkey");
        [_hotKey2 installHotKey];
    }
    
}

- (void)anotherMethodCallback
{
    NSLog(@"You pushed command-4");
}

- (void)thirdMethodCallback
{
    NSLog(@"You pushed control-4");
}

@end
