//
//  AMView.h
//  ArduinoSerial
//
//  Created by Chris Rorden on 11/13/12.
//
//

#import <Cocoa/Cocoa.h>

@interface AMView : NSView

typedef struct   {
    int timepoints, lines, selectedTimepoint;
    float verticalScale;
    bool blackBackground, enabled;
    float * data;
} GraphStruct;

- (void)savePDFFromFileName:(NSString *)fname;
- (void)savePDF;
- (void)saveTab;
//-(void) changeData: (int) timepoints SelectedTimepoint: (int) selectedTimepoint Lines: (int) lines VerticalScale: (float) verticalScale Data: (float*) data;
-(void) updateData: (GraphStruct) graph;
-(void) enable: (bool) on;



@end
