//
//  Impl.m
//  DockLikeWindows
//
//  Created by CriShoux on 2024-03-03.
//

#import <Foundation/Foundation.h>
#import "Bridging-Header.h"

OSStatus setApplicationFrontmost(NSRunningApplication *application) {
    if (!application || application.processIdentifier == -1) { return procNotFound; }
    
    ProcessSerialNumber process;
    OSStatus error = GetProcessForPID(application.processIdentifier, &process);
    if (error) {
        return error;
    }

    return SetFrontProcessWithOptions(&process, kSetFrontProcessFrontWindowOnly);
}
