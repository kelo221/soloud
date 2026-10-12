/*
SoLoud audio engine
Copyright (c) 2013-2020 Jari Komppa

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
claim that you wrote the original software. If you use this software
in a product, an acknowledgment in the product documentation would be
appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must not be
misrepresented as being the original software.

3. This notice may not be removed or altered from any source
distribution.
*/
#include <stdlib.h>

#include "soloud.h"

#if !defined(WITH_MINIAUDIO)

namespace SoLoud
{
    result miniaudio_init(SoLoud::Soloud *aSoloud, unsigned int aFlags, unsigned int aSamplerate, unsigned int aBuffer)
    {
        return NOT_IMPLEMENTED;
    }
}

#else

#define MINIAUDIO_IMPLEMENTATION
#define MA_NO_NULL
#define MA_NO_DECODING
#define MA_NO_WAV
#define MA_NO_FLAC
#define MA_NO_MP3
#include "miniaudio.h"
#include <math.h>
#include <stdlib.h>

namespace SoLoud
{
    // Each engine owns its device through Soloud::mBackendData; a shared
    // device would be re-initialized by a second engine and stopped for every
    // engine when any one of them deinits.
    void soloud_miniaudio_audiomixer(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount)
    {
        SoLoud::Soloud *soloud = (SoLoud::Soloud *)pDevice->pUserData;
            soloud->mix((float *)pOutput, frameCount);
    }

    static void soloud_miniaudio_deinit(SoLoud::Soloud *aSoloud)
    {
        ma_device *device = (ma_device *)aSoloud->mBackendData;
        if (!device)
            return;
        ma_device_uninit(device);
        free(device);
        aSoloud->mBackendData = NULL;
    }

    result miniaudio_init(SoLoud::Soloud *aSoloud, unsigned int aFlags, unsigned int aSamplerate, unsigned int aBuffer, unsigned int aChannels)
    {
        ma_device_config config = ma_device_config_init(ma_device_type_playback);
        //config.periodSizeInFrames = aBuffer; // setting to aBuffer (like 2048) causes miniaudio to crash; let's just use the default.
        config.playback.format    = ma_format_f32;
        config.playback.channels  = aChannels;
        config.sampleRate         = aSamplerate;
        config.dataCallback       = soloud_miniaudio_audiomixer;
        config.pUserData          = (void *)aSoloud;

        ma_device *device = (ma_device *)calloc(1, sizeof(ma_device));
        if (!device)
            return OUT_OF_MEMORY;

        if (ma_device_init(NULL, &config, device) != MA_SUCCESS)
        {
            free(device);
            return UNKNOWN_ERROR;
        }

        aSoloud->mBackendData = device;
        aSoloud->postinit_internal(device->sampleRate, device->playback.internalPeriodSizeInFrames, aFlags, device->playback.channels);

        aSoloud->mBackendCleanupFunc = soloud_miniaudio_deinit;

        ma_device_start(device);
        aSoloud->mBackendString = "MiniAudio";
        return 0;
    }
};
#endif
