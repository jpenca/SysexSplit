//
//  AppDelegate.h
//  Sysex Split
//
//  Created by Jakob Penca on 16/12/13.
//  Copyright (c) 2013 Jakob Penca. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (nonatomic, strong) NSMutableArray *messages;
@property (unsafe_unretained) IBOutlet NSButton *clearButton;
@property (unsafe_unretained) IBOutlet NSButton *combineButton;
@property (unsafe_unretained) IBOutlet NSButton *splitButton;
@property (unsafe_unretained) IBOutlet NSTextField *Label;
@end
