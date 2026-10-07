/*
SoLoud audio engine
Copyright (c) 2015 Jari Komppa

Core Audio backend for Mac OS X
Copyright (c) 2015 Petri Häkkinen

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
#include <math.h>

#include "soloud.h"
#include "soloud_thread.h"

#if !defined(WITH_COREAUDIO)

namespace SoLoud
{
	result coreaudio_init(SoLoud::Soloud *aSoloud, unsigned int aFlags, unsigned int aSamplerate, unsigned int aBuffer)
	{
		return NOT_IMPLEMENTED;
	}
}
#else

#include <AudioToolbox/AudioToolbox.h>
#include <stdlib.h>

#define NUM_BUFFERS 2

namespace SoLoud
{
	// Per-engine backend state. Stored in Soloud::mBackendData so each engine
	// instance owns its own AudioQueue — the old static audioQueue variable was
	// shared across all engines, so deiniting one engine would stop every other
	// engine's queue.
	struct CoreAudioBackendData
	{
		AudioQueueRef audioQueue;
	};

	void soloud_coreaudio_deinit(SoLoud::Soloud *aSoloud)
	{
		CoreAudioBackendData *data = (CoreAudioBackendData *)aSoloud->mBackendData;
		if (!data)
			return;
		if (data->audioQueue)
		{
			AudioQueueStop(data->audioQueue, true);
			AudioQueueDispose(data->audioQueue, false);
			data->audioQueue = NULL;
		}
		free(data);
		aSoloud->mBackendData = NULL;
	}

	result soloud_coreaudio_pause(SoLoud::Soloud *aSoloud)
	{
		CoreAudioBackendData *data = (CoreAudioBackendData *)aSoloud->mBackendData;
		if (!data || !data->audioQueue)
			return UNKNOWN_ERROR;

		AudioQueuePause(data->audioQueue);

		return 0;
	}

	result soloud_coreaudio_resume(SoLoud::Soloud *aSoloud)
	{
		CoreAudioBackendData *data = (CoreAudioBackendData *)aSoloud->mBackendData;
		if (!data || !data->audioQueue)
			return UNKNOWN_ERROR;

		AudioQueueStart(data->audioQueue, nil);

		return 0;
	}

	static void coreaudio_mutex_lock(void *mutex)
	{
		Thread::lockMutex(mutex);
	}

	static void coreaudio_mutex_unlock(void *mutex)
	{
		Thread::unlockMutex(mutex);
	}

	static void coreaudio_fill_buffer(void *context, AudioQueueRef queue, AudioQueueBufferRef buffer)
	{
		SoLoud::Soloud *aSoloud = (SoLoud::Soloud*)context;
		aSoloud->mixSigned16((short*)buffer->mAudioData, buffer->mAudioDataByteSize / 4);
		AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
	}

	result coreaudio_init(SoLoud::Soloud *aSoloud, unsigned int aFlags, unsigned int aSamplerate, unsigned int aBuffer, unsigned int aChannels)
	{
		aSoloud->postinit_internal(aSamplerate, aBuffer, aFlags, 2);
		aSoloud->mBackendCleanupFunc = soloud_coreaudio_deinit;
		aSoloud->mBackendPauseFunc = soloud_coreaudio_pause;
		aSoloud->mBackendResumeFunc = soloud_coreaudio_resume;

		CoreAudioBackendData *data = (CoreAudioBackendData *)malloc(sizeof(CoreAudioBackendData));
		if (!data)
			return UNKNOWN_ERROR;
		data->audioQueue = NULL;
		aSoloud->mBackendData = data;

		AudioStreamBasicDescription audioFormat;
		audioFormat.mSampleRate = aSamplerate;
		audioFormat.mFormatID = kAudioFormatLinearPCM;
		audioFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
		audioFormat.mBytesPerPacket = 4;
		audioFormat.mFramesPerPacket = 1;
		audioFormat.mBytesPerFrame = 4;
		audioFormat.mChannelsPerFrame = 2;
		audioFormat.mBitsPerChannel = 16;
		audioFormat.mReserved = 0;

		// create the audio queue
		OSStatus result = AudioQueueNewOutput(&audioFormat, coreaudio_fill_buffer, aSoloud, NULL, NULL, 0, &data->audioQueue);
		if(result)
		{
			free(data);
			aSoloud->mBackendData = NULL;
			return UNKNOWN_ERROR;
		}

		// allocate and prime audio buffers
		for(int i = 0; i < NUM_BUFFERS; ++i)
		{
			AudioQueueBufferRef buffer;
			result = AudioQueueAllocateBuffer(data->audioQueue, aBuffer * 4, &buffer);
			if(result)
			{
				free(data);
				aSoloud->mBackendData = NULL;
				return UNKNOWN_ERROR;
			}
			buffer->mAudioDataByteSize = aBuffer * 4;
			memset(buffer->mAudioData, 0, buffer->mAudioDataByteSize);
			AudioQueueEnqueueBuffer(data->audioQueue, buffer, 0, NULL);
		}

		// start playback
		result = AudioQueueStart(data->audioQueue, NULL);
		if(result)
		{
			free(data);
			aSoloud->mBackendData = NULL;
			return UNKNOWN_ERROR;
		}

		aSoloud->mBackendString = "CoreAudio";
		return 0;
	}
};
#endif
