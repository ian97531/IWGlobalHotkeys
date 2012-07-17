//
//  IWHotkey.m
//  
//
//  Created by Ian White on 7/12/12.
//  Copyright (c) 2012 Ian White.
//

#import "IWGlobalHotkey.h"

#define IWGLOBALHOTKEYS_MODIFIERS [NSArray arrayWithObjects:IWGLOBALHOTKEY_COMMAND, IWGLOBALHOTKEY_CONTROL, IWGLOBALHOTKEY_OPTION, IWGLOBALHOTKEY_SHIFT, nil]


NSString *osTypeToFourCharCode(OSType inType);
OSType fourCharCodeToOSType(NSString* inCode);
OSStatus HotKeyHandler(EventHandlerCallRef nextHandler,EventRef theEvent, void *userData);


static int _IWGLOBALHOTKEYS_COUNTER;
static NSMutableDictionary *_IWGLOBALHOTKEYS_INVOCATIONS;
static NSMutableArray *_IWGLOBALHOTKEYS_REUSABLE_SIGNATURE_QUEUE;


@interface IWGlobalHotkey ()

- (EventHotKeyID)hotKeyIDWithInvocation:(NSInvocation *)invocation;
- (void)releaseHotKeyID:(EventHotKeyID)hotKeyID;

+ (int)keyCodeFromString:(NSString *)key;
+ (NSString *)stringFromKeyCode:(int)keyCode;

@end


@implementation IWGlobalHotkey

@synthesize key = _key;
@synthesize modifiers = _modifiers;


+ (IWGlobalHotkey *)globalHotKeyWithKey:(NSString *)key modifiers:(NSArray *)modifiers target:(id)target action:(SEL)selector
{
    return [[IWGlobalHotkey alloc] initWithKey:key modifiers:modifiers target:target action:selector];
}


- (id)initWithKey:(NSString *)key modifiers:(NSArray *)modifiers target:(id)target action:(SEL)selector
{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _IWGLOBALHOTKEYS_COUNTER = 0;
        _IWGLOBALHOTKEYS_INVOCATIONS = [NSMutableDictionary dictionaryWithCapacity:10];
        _IWGLOBALHOTKEYS_REUSABLE_SIGNATURE_QUEUE = [NSMutableArray arrayWithCapacity:10];
    });
    
    self = [super init];
    if (self) {
        _allModifiers = IWGLOBALHOTKEYS_MODIFIERS;
        self.key = key;
        self.modifiers = modifiers;
        [self setTarget:target action:selector];
        
        _target = target;
        _action = selector;
        
    }
    return self;
}


- (void)setKey:(NSString *)key
{
    int keyCode = [IWGlobalHotkey keyCodeFromString:key];
    
    if (keyCode != NSNotFound) {
        _key = key;
        _keyCode = keyCode;
    }
    #ifdef DEBUG
    else {
        NSLog(@"Unable to set hot key to %@. Keycode not found.", key);
    }
    #endif
}

- (void)setModifiers:(NSArray *)modifiers
{
    
    int modifierCode = 0;
    
    for (NSNumber *modifier in modifiers) {
        if ([_allModifiers indexOfObject:modifier] != NSNotFound) {
            modifierCode += [modifier intValue];
        }
        else {
            #ifdef DEBUG
            NSLog(@"Unable to set hot key modifiers to %@. Unknown modifier: %@", modifiers, modifier);
            #endif
            return;
        }
    }
    
    _modifiers = modifiers;
    _modifierCode = modifierCode;
    
}



- (BOOL)setTarget:(id)target action:(SEL)selector
{
    // Sanity check the values passed in.
    if (!target || !selector) {
        #ifdef DEBUG
        NSLog(@"Unable to set the target and action for the hot key (%@) because one or both are nil.", [self symbolicCommand]);
        #endif
        return NO;
    }
    
    // Create the invocation
    NSMethodSignature *methodSignature = [[target class] instanceMethodSignatureForSelector:selector];
    
    // We'll get a nil value here if the selector does not exist for the target.
    if (!methodSignature) {
        #ifdef DEBUG
        NSLog(@"Unable to set the target and action for the hot key (%@) because the specified selector does not exist for the target.", [self symbolicCommand]);
        #endif
        return NO;
    }
    
    // If we get to this point, we can create the invocation object and save it for later.
    NSInvocation *theInvocation = [NSInvocation invocationWithMethodSignature:methodSignature];
    [theInvocation setTarget:target];
    [theInvocation setSelector:selector];
    
    _target = target;
    _action = selector;
    _invocation = theInvocation;
    
    return YES;
    
}



- (BOOL)installHotKey
{

    if (_key && _modifiers && _modifierCode && _invocation) {
        
        // If our hotkey is already assigned, we should unassign it first so we don't end up with two hot keys.
        if (_hotKeyRef) {
            [self removeHotKey];
        }
        
        // Get a hot key ID and register the associated method invocation
        _hotKeyID = [self hotKeyIDWithInvocation:_invocation];
        
        // Register the hot key
        EventTypeSpec eventType;
        eventType.eventClass=kEventClassKeyboard;
        eventType.eventKind=kEventHotKeyPressed;
        InstallApplicationEventHandler(&HotKeyHandler, 1, &eventType, (__bridge_retained void *) _invocation, NULL);
        OSStatus error = RegisterEventHotKey(_keyCode, _modifierCode, _hotKeyID, GetApplicationEventTarget(), 0, &_hotKeyRef);
        
        return error ? NO : YES;
    }
    else {
        #ifdef DEBUG
        if (!_key) NSLog(@"Unable to install the hotkey (%@) because it's missing a key", [self symbolicCommand]);
        if (!_modifiers || !_modifierCode) NSLog(@"Unable to install the hotkey (%@) because it's missing it's modifier key(s).", [self symbolicCommand]);
        if (!_invocation) NSLog(@"Unable to install the hotkey (%@) because no valid target and action to call back to have been specified.", [self symbolicCommand]);
        #endif
        return NO;
    }
    
    
}




- (BOOL)removeHotKey
{
    // Make sure we have a hot key registered to remove.
    if (_hotKeyRef) {
        
        OSStatus error = UnregisterEventHotKey(_hotKeyRef);
        
        if(!error){
            // If ther was no error, get rid of the key ref, and release the hot key ID
            // so that it can recycled by another hot key.
            _hotKeyRef = nil;
            [self releaseHotKeyID:_hotKeyID];
            return YES;
        }
        #ifdef DEBUG
        else {
            NSLog(@"There was an error unregistering your GlobalHotKey %@", [self symbolicCommand]);
        }
        #endif
    }
    
    return NO;
}



- (BOOL)installed
{
    return (_hotKeyRef != nil);
}



- (NSString *)description
{
    
    NSString *isInstalled = (self.installed) ? @"Installed" : @"Not Installed";
    
    return [NSString stringWithFormat:@"Global Hotkey %@ (%@)", [self symbolicCommand], isInstalled];
}




- (NSString *)symbolicCommand
{
    NSArray *modifierPrecidence = [NSArray arrayWithObjects:IWGLOBALHOTKEY_CONTROL, IWGLOBALHOTKEY_OPTION, IWGLOBALHOTKEY_SHIFT, IWGLOBALHOTKEY_COMMAND, nil];
    NSDictionary *symbols = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"^", @"⌥", @"⇧", @"⌘", nil] 
                                                        forKeys:modifierPrecidence];
    
    NSString *symbolString = @"";
    
    if (_modifiers) {
        for (int i = 0; i < modifierPrecidence.count; i++) {
            if ([_modifiers indexOfObject:[modifierPrecidence objectAtIndex:i]] != NSNotFound) {
                symbolString = [symbolString stringByAppendingString:[symbols objectForKey:[modifierPrecidence objectAtIndex:i]]];
            }
        }
    }
    
    if (_key) {
        symbolString = [symbolString stringByAppendingString:_key];
    }
    
    return symbolString;
}



- (NSString *)stringCommand
{
    NSArray *modifierPrecidence = [NSArray arrayWithObjects:IWGLOBALHOTKEY_CONTROL, IWGLOBALHOTKEY_OPTION, IWGLOBALHOTKEY_SHIFT, IWGLOBALHOTKEY_COMMAND, nil];
    NSDictionary *words = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Control", @"Option", @"Shift", @"Command", nil] 
                                                      forKeys:modifierPrecidence];
    
    NSString *wordString = @"";
    
    if (_modifiers) {
        for (int i = 0; i < modifierPrecidence.count; i++) {
            if ([_modifiers indexOfObject:[modifierPrecidence objectAtIndex:i]] != NSNotFound) {
                wordString = [wordString stringByAppendingString:[words objectForKey:[modifierPrecidence objectAtIndex:i]]];
                wordString = [wordString stringByAppendingString:@"-"];
            }
        }
    }
    
    if (_key) {
        wordString = [wordString stringByAppendingString:_key];
    }
    
    
    return wordString;
}


- (EventHotKeyID)hotKeyIDWithInvocation:(NSInvocation *)invocation
{
    EventHotKeyID hotKeyID;
    
    __block int theID;
    __block OSType sig;
    dispatch_queue_t cacheQueue = dispatch_queue_create("com.elemental.IWGLOBALHOTKEY", NULL);
    dispatch_sync(cacheQueue, ^{
        
        if (_IWGLOBALHOTKEYS_REUSABLE_SIGNATURE_QUEUE.count) {
            
            theID = [[_IWGLOBALHOTKEYS_REUSABLE_SIGNATURE_QUEUE objectAtIndex:0] intValue];
            [_IWGLOBALHOTKEYS_REUSABLE_SIGNATURE_QUEUE removeObjectAtIndex:0];
            
        }
        else {
            theID = ++_IWGLOBALHOTKEYS_COUNTER;
        };
        
        if (theID < 9999) {
            sig = fourCharCodeToOSType([NSString stringWithFormat:@"%04i", theID]);
            [_IWGLOBALHOTKEYS_INVOCATIONS setObject:invocation forKey:osTypeToFourCharCode(sig)];
        }
        #ifdef DEBUG
        else {
            
            NSLog(@"The maximum number of 9999 hotkeys have already been installed. Ignoring hotkey install request.");
        }
        #endif
        
    });
    
    hotKeyID.signature = sig;
    hotKeyID.id = theID;
    
    return hotKeyID;

}


- (void)releaseHotKeyID:(EventHotKeyID)hotKeyID
{
    dispatch_queue_t cacheQueue = dispatch_queue_create("com.elemental.IWGLOBALHOTKEY", NULL);
    dispatch_sync(cacheQueue, ^{
    
        [_IWGLOBALHOTKEYS_INVOCATIONS removeObjectForKey:osTypeToFourCharCode(hotKeyID.signature)];
        [_IWGLOBALHOTKEYS_REUSABLE_SIGNATURE_QUEUE addObject:[NSNumber numberWithInt:hotKeyID.id]];
        
    });
}


// Call back that initially handles all hot key events and invokes the proper invocation for the hotkey
OSStatus HotKeyHandler(EventHandlerCallRef nextHandler,EventRef theEvent, void *userData) {
    
    // Get the hot key id from the key press event
    EventHotKeyID hotKeyID;
    GetEventParameter(theEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(hotKeyID), NULL, &hotKeyID);
    
    // Locate the invocation we have stored for that particular hotkey
    __block NSInvocation *theInvocation;
    dispatch_queue_t cacheQueue = dispatch_queue_create("com.elemental.IWGLOBALHOTKEY", NULL);
    dispatch_sync(cacheQueue, ^{
        theInvocation = [_IWGLOBALHOTKEYS_INVOCATIONS objectForKey:osTypeToFourCharCode(hotKeyID.signature)];
    });
    
    // Invoke the invocation if we found one.
    if (theInvocation) {
        [theInvocation invoke];
    }
    #ifdef DEBUG
    else {
        NSLog(@"No invocation found for hot key id %i", hotKeyID.id);
    }
    #endif
    
    return 0;
}


// Convert an OSType into a 4 character string
NSString *osTypeToFourCharCode(OSType inType)
{
    char code[5];
    memcpy(code,&inType,sizeof(inType));
    code[4] = 0;
    return [NSString stringWithCString:code encoding:NSASCIIStringEncoding];
}

// Convert a 4 character string into an OSType
OSType fourCharCodeToOSType(NSString* inCode)
{
    OSType rval = 0;
    memcpy(&rval,[inCode cStringUsingEncoding:NSASCIIStringEncoding],sizeof(rval));
    return rval;
}


// Convert a string into it's corresponding key code.
+ (int)keyCodeFromString:(NSString *)key
{
    const char *keyString = [[key lowercaseString] cStringUsingEncoding:NSASCIIStringEncoding];
    if (strcmp(keyString, "a") == 0) return 0;
    if (strcmp(keyString, "s") == 0) return 1;
    if (strcmp(keyString, "d") == 0) return 2;
    if (strcmp(keyString, "f") == 0) return 3;
    if (strcmp(keyString, "h") == 0) return 4;
    if (strcmp(keyString, "g") == 0) return 5;
    if (strcmp(keyString, "z") == 0) return 6;
    if (strcmp(keyString, "x") == 0) return 7;
    if (strcmp(keyString, "c") == 0) return 8;
    if (strcmp(keyString, "v") == 0) return 9;
    if (strcmp(keyString, "b") == 0) return 11;
    if (strcmp(keyString, "q") == 0) return 12;
    if (strcmp(keyString, "w") == 0) return 13;
    if (strcmp(keyString, "e") == 0) return 14;
    if (strcmp(keyString, "r") == 0) return 15;
    if (strcmp(keyString, "y") == 0) return 16;
    if (strcmp(keyString, "t") == 0) return 17;
    if (strcmp(keyString, "1") == 0) return 18;
    if (strcmp(keyString, "2") == 0) return 19;
    if (strcmp(keyString, "3") == 0) return 20;
    if (strcmp(keyString, "4") == 0) return 21;
    if (strcmp(keyString, "6") == 0) return 22;
    if (strcmp(keyString, "5") == 0) return 23;
    if (strcmp(keyString, "=") == 0) return 24;
    if (strcmp(keyString, "9") == 0) return 25;
    if (strcmp(keyString, "7") == 0) return 26;
    if (strcmp(keyString, "-") == 0) return 27;
    if (strcmp(keyString, "8") == 0) return 28;
    if (strcmp(keyString, "0") == 0) return 29;
    if (strcmp(keyString, "]") == 0) return 30;
    if (strcmp(keyString, "o") == 0) return 31;
    if (strcmp(keyString, "u") == 0) return 32;
    if (strcmp(keyString, "[") == 0) return 33;
    if (strcmp(keyString, "i") == 0) return 34;
    if (strcmp(keyString, "p") == 0) return 35;
    if (strcmp(keyString, "RETURN") == 0) return 36;
    if (strcmp(keyString, "l") == 0) return 37;
    if (strcmp(keyString, "j") == 0) return 38;
    if (strcmp(keyString, "'") == 0) return 39;
    if (strcmp(keyString, "k") == 0) return 40;
    if (strcmp(keyString, ";") == 0) return 41;
    if (strcmp(keyString, "\\") == 0) return 42;
    if (strcmp(keyString, ",") == 0) return 43;
    if (strcmp(keyString, "/") == 0) return 44;
    if (strcmp(keyString, "n") == 0) return 45;
    if (strcmp(keyString, "m") == 0) return 46;
    if (strcmp(keyString, ".") == 0) return 47;
    if (strcmp(keyString, "TAB") == 0) return 48;
    if (strcmp(keyString, "SPACE") == 0) return 49;
    if (strcmp(keyString, "`") == 0) return 50;
    if (strcmp(keyString, "DELETE") == 0) return 51;
    if (strcmp(keyString, "ENTER") == 0) return 52;
    if (strcmp(keyString, "ESCAPE") == 0) return 53;
    if (strcmp(keyString, ".") == 0) return 65;
    if (strcmp(keyString, "*") == 0) return 67;
    if (strcmp(keyString, "+") == 0) return 69;
    if (strcmp(keyString, "CLEAR") == 0) return 71;
    if (strcmp(keyString, "/") == 0) return 75;
    if (strcmp(keyString, "ENTER") == 0) return 76; 
    if (strcmp(keyString, "=") == 0) return 78;
    if (strcmp(keyString, "=") == 0) return 81;
    if (strcmp(keyString, "0") == 0) return 82;
    if (strcmp(keyString, "1") == 0) return 83;
    if (strcmp(keyString, "2") == 0) return 84;
    if (strcmp(keyString, "3") == 0) return 85;
    if (strcmp(keyString, "4") == 0) return 86;
    if (strcmp(keyString, "5") == 0) return 87;
    if (strcmp(keyString, "6") == 0) return 88;
    if (strcmp(keyString, "7") == 0) return 89;
    if (strcmp(keyString, "8") == 0) return 91;
    if (strcmp(keyString, "9") == 0) return 92;
    if (strcmp(keyString, "F5") == 0) return 96;
    if (strcmp(keyString, "F6") == 0) return 97;
    if (strcmp(keyString, "F7") == 0) return 98;
    if (strcmp(keyString, "F3") == 0) return 99;
    if (strcmp(keyString, "F8") == 0) return 100;
    if (strcmp(keyString, "F9") == 0) return 101;
    if (strcmp(keyString, "F11") == 0) return 103;
    if (strcmp(keyString, "F13") == 0) return 105;
    if (strcmp(keyString, "F14") == 0) return 107;
    if (strcmp(keyString, "F10") == 0) return 109;
    if (strcmp(keyString, "F12") == 0) return 111;
    if (strcmp(keyString, "F15") == 0) return 113;
    if (strcmp(keyString, "HELP") == 0) return 114;
    if (strcmp(keyString, "HOME") == 0) return 115;
    if (strcmp(keyString, "PGUP") == 0) return 116;
    if (strcmp(keyString, "DELETE") == 0) return 117;
    if (strcmp(keyString, "F4") == 0) return 118;
    if (strcmp(keyString, "END") == 0) return 119;
    if (strcmp(keyString, "F2") == 0) return 120;
    if (strcmp(keyString, "PGDN") == 0) return 121;
    if (strcmp(keyString, "F1") == 0) return 122;
    if (strcmp(keyString, "LEFT") == 0) return 123;
    if (strcmp(keyString, "RIGHT") == 0) return 124;
    if (strcmp(keyString, "DOWN") == 0) return 125;
    if (strcmp(keyString, "UP") == 0) return 126;
    
    #ifdef DEBUG
    NSLog(@"Unknown keycode for string: %@", key);
    #endif
    
    return NSNotFound;
}


// Convert a key code into the string value it represents (lower-case)
+ (NSString *)stringFromKeyCode:(int)keyCode
{
    switch (keyCode) {
        case 0: return @"a";
        case 1: return @"s";
        case 2: return @"d";
        case 3: return @"f";
        case 4: return @"h";
        case 5: return @"g";
        case 6: return @"z";
        case 7: return @"x";
        case 8: return @"c";
        case 9: return @"v";
        case 11: return @"b";
        case 12: return @"q";
        case 13: return @"w";
        case 14: return @"e";
        case 15: return @"r";
        case 16: return @"y";
        case 17: return @"t";
        case 18: return @"1";
        case 19: return @"2";
        case 20: return @"3";
        case 21: return @"4";
        case 22: return @"6";
        case 23: return @"5";
        case 24: return @"=";
        case 25: return @"9";
        case 26: return @"7";
        case 27: return @"-";
        case 28: return @"8";
        case 29: return @"0";
        case 30: return @"]";
        case 31: return @"o";
        case 32: return @"u";
        case 33: return @"[";
        case 34: return @"i";
        case 35: return @"p";
        case 36: return @"RETURN";
        case 37: return @"l";
        case 38: return @"j";
        case 39: return @"'";
        case 40: return @"k";
        case 41: return @";";
        case 42: return @"\\";
        case 43: return @",";
        case 44: return @"/";
        case 45: return @"n";
        case 46: return @"m";
        case 47: return @".";
        case 48: return @"TAB";
        case 49: return @"SPACE";
        case 50: return @"`";
        case 51: return @"DELETE";
        case 52: return @"ENTER";
        case 53: return @"ESCAPE";
        case 65: return @".";
        case 67: return @"*";
        case 69: return @"+";
        case 71: return @"CLEAR";
        case 75: return @"/";
        case 76: return @"ENTER";
        case 78: return @"-";
        case 81: return @"=";
        case 82: return @"0";
        case 83: return @"1";
        case 84: return @"2";
        case 85: return @"3";
        case 86: return @"4";
        case 87: return @"5";
        case 88: return @"6";
        case 89: return @"7";
        case 91: return @"8";
        case 92: return @"9";
        case 96: return @"F5";
        case 97: return @"F6";
        case 98: return @"F7";
        case 99: return @"F3";
        case 100: return @"F8";
        case 101: return @"F9";
        case 103: return @"F11";
        case 105: return @"F13";
        case 107: return @"F14";
        case 109: return @"F10";
        case 111: return @"F12";
        case 113: return @"F15";
        case 114: return @"HELP";
        case 115: return @"HOME";
        case 116: return @"PGUP";
        case 117: return @"DELETE";
        case 118: return @"F4";
        case 119: return @"END";
        case 120: return @"F2";
        case 121: return @"PGDN";
        case 122: return @"F1";
        case 123: return @"LEFT";
        case 124: return @"RIGHT";
        case 125: return @"DOWN";
        case 126: return @"UP";
        default:
            #ifdef DEBUG
            NSLog(@"Unknown string for keycode: %i", keyCode);
            #endif
            return @"";
    }
}

@end
