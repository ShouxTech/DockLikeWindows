//
//  Bridging-Header.h
//  DockLikeWindows
//
//  Created by CriShoux on 2024-03-02.
//

#import <AppKit/AppKit.h>
#import <Cocoa/Cocoa.h>

OSStatus setApplicationFrontmost(NSRunningApplication *application);

// https://stackoverflow.com/a/74914146
AXError _AXUIElementGetWindow(AXUIElementRef element, uint32_t *identifier);

@interface NSWindow (Private)
- (BOOL)_isNonactivatingPanel;
@end
