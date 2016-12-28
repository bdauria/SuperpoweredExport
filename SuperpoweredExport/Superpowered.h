//
//  Superpowered.h
//  Superpowered
//
//  Created by Bruno on 13.12.16.
//  Copyright © 2016 Bubo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Superpowered : NSObject

- (void)onPlayPause:(id)sender;
- (IBAction)onCrossFader:(id)sender;
- (IBAction)onFxOff:(id)sender;
- (IBAction)onFxValue:(id)sender;
- (IBAction)onFxSelect:(id)sender;

@end
