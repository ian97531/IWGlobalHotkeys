//
//  IWHotkey.h
//  
//
//  Created by Ian White on 7/12/12.
//  Copyright (c) 2012 Ian White.
//

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

#define IWGLOBALHOTKEY_COMMAND [NSNumber numberWithInt:cmdKey]
#define IWGLOBALHOTKEY_OPTION [NSNumber numberWithInt:optionKey]
#define IWGLOBALHOTKEY_SHIFT [NSNumber numberWithInt:shiftKey]
#define IWGLOBALHOTKEY_CONTROL [NSNumber numberWithInt:controlKey]

@interface IWGlobalHotkey : NSObject
{
    EventHotKeyRef _hotKeyRef;
    EventHotKeyID _hotKeyID;
    
    int _keyCode;
    int _modifierCode;
    
    id _target;
    SEL _action;
    NSInvocation *_invocation;
    
    NSString *_key;
    NSArray *_modifiers;
    NSArray *_allModifiers;
}

@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSArray *modifiers;
@property (nonatomic, readonly) BOOL installed;

+ (IWGlobalHotkey *)globalHotKeyWithKey:(NSString *)key modifiers:(NSArray *)modifiers target:(id)target action:(SEL)selector;
- (id)initWithKey:(NSString *)key modifiers:(NSArray *)modifiers target:(id)target action:(SEL)selector;

- (void)setKey:(NSString *)key;
- (void)setModifiers:(NSArray *)modifiers;
- (BOOL)setTarget:(id)target action:(SEL)selector;

- (BOOL)installHotKey;
- (BOOL)removeHotKey;
- (BOOL)installed;
- (NSString *)description;
- (NSString *)symbolicCommand;
- (NSString *)stringCommand;



@end
