/**
 * Appcelerator Kroll - licensed under the Apache Public License 2
 * see LICENSE in the root folder for details on the license.
 * Copyright (c) 2008 Appcelerator, Inc. All Rights Reserved.
 */

#ifndef _MEDIA_WIN32_SOUND_H_
#define _MEDIA_WIN32_SOUND_H_

#include <api/module.h>
#include <api/binding/binding.h>
#include <vector>
#include "../sound.h"

using namespace kroll;

namespace ti
{
	class Win32Sound : public Sound
	{
	public:
		Win32Sound(std::string& url);
		virtual ~Win32Sound();
		
		virtual void Play();
		virtual void Pause();
		virtual void Resume();
		virtual void Stop();
		virtual void Reset();
		virtual void SetVolume(double volume);
		virtual double GetVolume();
		virtual void SetLooping(bool loop);
		virtual bool IsLooping();
		virtual bool IsPlaying();
		virtual bool IsPaused();
		virtual void OnComplete(SharedBoundMethod callback);
		
	private:
		SharedBoundMethod* callback;
	};
}

#endif
