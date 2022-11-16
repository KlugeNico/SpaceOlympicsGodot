#!/bin/bash

# Script Usage
# ---------------------------------------------------------------------------
echo_help() {
  cat <<EOF

Build godot for different platforms.

Possible platforms: android, x11, x11-editor, all

EOF
}

build_android=""
build_x11=""
build_x11_editor=""

if [ $# -eq 0 ]; then
	echo_help
	exit 0
fi

# idiomatic parameter and option handling in sh
while test $# -gt 0
do
	case "$1" in
		-h | --help)
			echo_help
			exit 0
			;;
		x11-editor)
			build_x11_editor="1"
			;;
		x11)
			build_x11="1"
			;;
		android)
			build_android="1"
			;;
		all)
			build_android="1"
			build_x11="1"
			build_x11_editor="1"
			;;
  	*)
    	printf "Error in command line usage:\n"
    	printf "Unknown command: %s" "$1"
    	printf "\n"
    	echo_help
    	;;
	esac
	shift
done

if $build_x11_editor; then
	scons platform=x11
fi

if $build_x11; then
	cp custom_module_config.py custom.py
	scons platform=x11 tools=no target=release
	rm custom.py
fi

if $build_android; then
	ANDROID_SDK_ROOT=/data/android/sdk
	export ANDROID_SDK_ROOT
	cp custom_module_config.py custom.py
	scons platform=android target=release_debug android_arch=armv7
	scons platform=android target=release_debug android_arch=arm64v8
	scons platform=android target=release android_arch=armv7
	scons platform=android target=release android_arch=arm64v8
	scons platform=android target=release android_arch=x86
	scons platform=android target=release android_arch=x86_64
	cd platform/android/java || exit 1
	./gradlew generateGodotTemplates
	rm custom.py
fi


exit 0
