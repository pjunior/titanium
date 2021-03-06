/**
 * Appcelerator Titanium - licensed under the Apache Public License 2
 * see LICENSE in the root folder for details on the license.
 * Copyright (c) 2008 Appcelerator, Inc. All Rights Reserved.
 */

#ifndef _MEDIA_BINDING_H_
#define _MEDIA_BINDING_H_

#include <api/module.h>
#include <api/binding/binding.h>
#include <map>
#include <vector>
#include <string>

namespace ti
{
	class MediaBinding : public StaticBoundObject
	{
	public:
		MediaBinding(SharedBoundObject);
	protected:
		virtual ~MediaBinding();
		std::string GetResourcePath(const char *URL);
	private:
		SharedBoundObject global;
		void _CreateSound(const ValueList& args, SharedValue result);
		void _Beep(const ValueList& args, SharedValue result);

		virtual SharedBoundObject CreateSound(std::string& url) = 0;
		virtual void Beep() = 0;
	};
}

#endif
