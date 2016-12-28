//
//  Superpowered.m
//  Superpowered
//
//  Created by Bruno on 13.12.16.
//  Copyright © 2016 Bubo. All rights reserved.
//

#import "Superpowered.h"
#import "SuperpoweredAdvancedAudioPlayer.h"
#import "SuperpoweredIOSAudioIO.h"
#import <stdlib.h>

#define HEADROOM_DECIBEL 3.0f
static const float headroom = powf(10.0f, -HEADROOM_DECIBEL * 0.025);


@implementation Superpowered {
SuperpoweredAdvancedAudioPlayer *playerA, *playerB;
SuperpoweredIOSAudioIO *output;
unsigned char activeFx;
float *stereoBuffer, crossValue, volA, volB;
unsigned int lastSamplerate;
}

void playerEventCallbackA(void *clientData, SuperpoweredAdvancedAudioPlayerEvent event, void *value) {
    if (event == SuperpoweredAdvancedAudioPlayerEvent_LoadSuccess) {
        Superpowered *self = (__bridge Superpowered *)clientData;
        self->playerA->setBpm(126.0f);
        self->playerA->setFirstBeatMs(353);
        self->playerA->setPosition(self->playerA->firstBeatMs, false, false);
    };
}

void playerEventCallbackB(void *clientData, SuperpoweredAdvancedAudioPlayerEvent event, void *value) {
    if (event == SuperpoweredAdvancedAudioPlayerEvent_LoadSuccess) {
        Superpowered *self = (__bridge Superpowered *)clientData;
        self->playerB->setBpm(123.0f);
        self->playerB->setFirstBeatMs(40);
        self->playerB->setPosition(self->playerB->firstBeatMs, false, false);
    };
}

// This is where the Superpowered magic happens.
static bool audioProcessing(void *clientdata, float **buffers, unsigned int inputChannels, unsigned int outputChannels, unsigned int numberOfSamples, unsigned int samplerate, uint64_t hostTime) {
    __unsafe_unretained Superpowered *self = (__bridge Superpowered *)clientdata;
    if (samplerate != self->lastSamplerate) { // Has samplerate changed?
        self->lastSamplerate = samplerate;
        self->playerA->setSamplerate(samplerate);
        self->playerB->setSamplerate(samplerate);
    };
    
    bool masterIsA = (self->crossValue <= 0.5f);
    float masterBpm = masterIsA ? self->playerA->currentBpm : self->playerB->currentBpm; // Players will sync to this tempo.
    double msElapsedSinceLastBeatA = self->playerA->msElapsedSinceLastBeat; // When playerB needs it, playerA has already stepped this value, so save it now.
    
    bool silence = !self->playerA->process(self->stereoBuffer, false, numberOfSamples, self->volA, masterBpm, self->playerB->msElapsedSinceLastBeat);
    if (self->playerB->process(self->stereoBuffer, !silence, numberOfSamples, self->volB, masterBpm, msElapsedSinceLastBeatA)) silence = false;

    return !silence;
}

- (id)init {
    self = [super init];
    lastSamplerate = activeFx = 0;
    crossValue = volB = 0.0f;
    volA = 1.0f * headroom;
    if (posix_memalign((void **)&stereoBuffer, 16, 4096 + 128) != 0) abort(); // Allocating memory, aligned to 16.
    
    playerA = new SuperpoweredAdvancedAudioPlayer((__bridge void *)self, playerEventCallbackA, 44100, 0);
    playerA->open([[[NSBundle mainBundle] pathForResource:@"lycka" ofType:@"mp3"] fileSystemRepresentation]);
    playerB = new SuperpoweredAdvancedAudioPlayer((__bridge void *)self, playerEventCallbackB, 44100, 0);
    playerB->open([[[NSBundle mainBundle] pathForResource:@"nuyorica" ofType:@"m4a"] fileSystemRepresentation]);
    
    playerA->syncMode = playerB->syncMode = SuperpoweredAdvancedAudioPlayerSyncMode_TempoAndBeat;
    
    output = [[SuperpoweredIOSAudioIO alloc] initWithDelegate:(id<SuperpoweredIOSAudioIODelegate>)self preferredBufferSize:12 preferredMinimumSamplerate:44100 audioSessionCategory:AVAudioSessionCategoryPlayback channels:2 audioProcessingCallback:audioProcessing clientdata:(__bridge void *)self];
    [output start];
    return self;
}

- (void)dealloc {
    delete playerA;
    delete playerB;
    free(stereoBuffer);
#if !__has_feature(objc_arc)
    [output release];
    [super dealloc];
#endif
}

- (void)interruptionStarted {}
- (void)recordPermissionRefused {}
- (void)mapChannels:(multiOutputChannelMap *)outputMap inputMap:(multiInputChannelMap *)inputMap externalAudioDeviceName:(NSString *)externalAudioDeviceName outputsAndInputs:(NSString *)outputsAndInputs {}

- (void)interruptionEnded { // If a player plays Apple Lossless audio files, then we need this. Otherwise unnecessary.
    playerA->onMediaserverInterrupt();
    playerB->onMediaserverInterrupt();
}

- (void)onPlayPause:(id)sender {
    if (playerA->playing) {
        playerA->pause();
        playerB->pause();
    } else {
        bool masterIsA = (crossValue <= 0.5f);
        playerA->play(!masterIsA);
        playerB->play(masterIsA);
    };
}

- (IBAction)onCrossFader:(id)sender {
    if (crossValue < 0.01f) {
        volA = 1.0f * headroom;
        volB = 0.0f;
    } else if (crossValue > 0.99f) {
        volA = 0.0f;
        volB = 1.0f * headroom;
    } else { // constant power curve
        volA = cosf(M_PI_2 * crossValue) * headroom;
        volB = cosf(M_PI_2 * (1.0f - crossValue)) * headroom;
    };
}

static inline float floatToFrequency(float value) {
    static const float min = logf(20.0f) / logf(10.0f);
    static const float max = logf(20000.0f) / logf(10.0f);
    static const float range = max - min;
    return powf(10.0f, value * range + min);
}

- (IBAction)onFxSelect:(id)sender {
}

- (IBAction)onFxValue:(id)sender {
}

- (IBAction)onFxOff:(id)sender {
}

@end
