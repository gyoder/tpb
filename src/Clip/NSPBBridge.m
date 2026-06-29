// Simple bridge to objective_c code
// https://nathancraddock.com/blog/writing-to-the-clipboard-the-hard-way/
#import <Cocoa/Cocoa.h>
NSPasteboard *pboard;

void initPB() { pboard = [NSPasteboard generalPasteboard]; }

void sendPB(const char *text) {
  [pboard clearContents];
  [pboard setString:[NSString stringWithUTF8String:text]
            forType:NSPasteboardTypeString];
}
