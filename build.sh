#!/bin/bash


ANDROID_SDK_ROOT=/data/android/sdk
export ANDROID_SDK_ROOT


echo_help() {
  cat <<EOF

Build godot for different platforms.

Possible platforms: x11-editor, x11, android, osx-editor, osx, iphone, all-linux, all-mac

EOF
}

build_x11_editor=""
build_x11=""
build_android=""
build_osx_editor=""
build_osx=""
build_iphone=""

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
		osx-editor)
			build_osx_editor="1"
			;;
		osx)
			build_osx="1"
			;;
		iphone)
			build_iphone="1"
			;;
		all-linux)
			build_android="1"
			build_x11="1"
			build_x11_editor="1"
			;;
		all-mac)
			build_osx_editor="1"
			build_osx="1"
			build_iphone="1"
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
	cp custom_module_config.py custom.py
	scons platform=android target=release_debug android_arch=armv7
	scons platform=android target=release_debug android_arch=arm64v8
	scons platform=android target=release android_arch=armv7
	scons platform=android target=release android_arch=arm64v8
	scons platform=android target=release android_arch=x86
	scons platform=android target=release android_arch=x86_64
	rm custom.py
	cd platform/android/java || { printf "ERROR: Can cd in platform/android/java. No generateGodotTemplates executed!\n"; exit 1; }
	./gradlew generateGodotTemplates
fi

if $build_osx_editor; then
	scons platform=osx arch=x86_64 --jobs=$(sysctl -n hw.logicalcpu)  # arch=arm64 for arm cpus
fi

if $build_osx; then
	cp custom_module_config.py custom.py
	scons platform=osx tools=no target=release arch=x86_64 --jobs=$(sysctl -n hw.logicalcpu)
	scons platform=osx tools=no target=release arch=arm64 --jobs=$(sysctl -n hw.logicalcpu)
	rm custom.py
	lipo -create bin/godot.osx.opt.x86_64 bin/godot.osx.opt.arm64 -output bin/godot.osx.opt.universal
	cp -r misc/dist/osx_template.app .
	mkdir -p osx_template.app/Contents/MacOS
	cp bin/godot.osx.opt.universal osx_template.app/Contents/MacOS/godot_osx_release.64
	chmod +x osx_template.app/Contents/MacOS/godot_osx*
	zip -q -9 -r osx.zip osx_template.app
fi

if $build_iphone; then
	cp custom_module_config.py custom.py
	scons p=iphone tools=no target=release arch=arm
	scons p=iphone tools=no target=release arch=arm64
	rm custom.py
	lipo -create bin/libgodot.iphone.opt.arm.a bin/libgodot.iphone.opt.arm64.a -output bin/libgodot.iphone.release.fat.a
fi

exit 0
