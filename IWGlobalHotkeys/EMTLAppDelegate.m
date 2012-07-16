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
        NSLog(@"Installing the %@ hotkey", _hotKey1.stringCommand);
    }
    
    if([_hotKey2 installHotKey]) {
        NSLog(@"Installing the %@ hotkey", _hotKey2.stringCommand);
    }
    
    if ([_hotKey3 installHotKey]) {
        NSLog(@"Installing the %@ hotkey", _hotKey3.stringCommand);
    }
    
}

- (void)aMethodCallback
{
    NSLog(@"You pushed %@", _hotKey1.symbolicCommand);
    if (_hotKey2.installed) {
        NSLog(@"Removing the %@ hotkey", _hotKey2.stringCommand);
        [_hotKey2 removeHotKey];
        NSLog(@"%@", _hotKey2);
    }
    else {
        NSLog(@"Installing the %@ hotkey", _hotKey2.stringCommand);
        [_hotKey2 installHotKey];
        NSLog(@"%@", _hotKey2);
    }
    
}

- (void)anotherMethodCallback
{
    NSLog(@"You pushed %@", _hotKey2.symbolicCommand);
}

- (void)thirdMethodCallback
{
    NSLog(@"You pushed %@", _hotKey3.stringCommand);
}

@end
