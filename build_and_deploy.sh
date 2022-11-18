#!/bin/bash

ANDROID_SDK_ROOT="/data/android/sdk"
godot_version="3.5.2.rc"
project_folder="../SpaceTournament"

godot_folder="$(pwd)"
bin_folder="$godot_folder/bin"
template_folder="$HOME/.local/share/godot/templates/$godot_version"
export ANDROID_SDK_ROOT


printf "Your OS: "
case "$OSTYPE" in
	solaris*) printf "SOLARIS" ;;
	darwin*)  printf "OSX"; template_folder="$HOME/Library/Application Support/Godot/templates/$godot_version" ;;
	linux*)   printf "LINUX"; template_folder="$HOME/.local/share/godot/templates/$godot_version" ;;
	bsd*)     printf "BSD" ;;
	msys*)    printf "WINDOWS"; template_folder="$HOME\AppData\Roaming\Godot" ;;
	cygwin*)  printf "STRANGE WINDOWS" ;;
	*)        printf "unknown: %s" "$OSTYPE" ;;
esac
printf "\n"


echo_help() {
  cat <<EOF

Build godot for different platforms.

Possible platforms: x11-editor, x11, android, osx-editor, osx, iphone, all-linux, all-mac

EOF
}


clean_up() {
	cd "$godot_folder"
	if [ -f "custom.py" ]; then
		rm "custom.py"
	fi
}

fail_exit() {
	echo "$1"
	echo "Stop Process."
	clean_up
	exit 1
}

ensured() {
	$@ || fail_exit "ERROR: Can not: $@"
}

ensured_folder() {
	if [ ! -d "$1" ]; then
		mkdir "$1" || fail_exit "ERROR: Can not ensure folder: $1"
	fi
}

ensured_file_content() {
	echo "$2" >| "$1" || fail_exit "ERROR: Can not set file content: $1"
}

ensured_in_dir() {
	(cd "$1" && shift && $@) || fail_exit "ERROR: Can not '${@:2}' in '$1'"
}


build_android() {
	echo "BUILD FOR ANDROID"
	ensured cp custom_module_config.py custom.py
	ensured scons platform=android target=release_debug android_arch=armv7
	ensured scons platform=android target=release_debug android_arch=arm64v8
	ensured scons platform=android target=release android_arch=armv7
	ensured scons platform=android target=release android_arch=arm64v8
	ensured scons platform=android target=release android_arch=x86
	ensured scons platform=android target=release android_arch=x86_64
	ensured rm custom.py
	ensured_in_dir platform/android/java ./gradlew generateGodotTemplates
}

deploy_android() {
	echo "DEPLOY FOR ANDROID"
	echo "Install godot template folder"
	ensured_folder "$template_folder"
	ensured cp "$bin_folder/android_source.zip" "$template_folder"
	ensured_file_content "$template_folder/version.txt" "$godot_version"

	echo "Prepare godot_google_play_billing"
	godot_google_play_billing_folder="$bin_folder/godot-google-play-billing"
	if [ ! -d "$godot_google_play_billing_folder" ]; then
		ensured_in_dir "$bin_folder" git clone https://github.com/godotengine/godot-google-play-billing.git
	fi
	ensured_in_dir "$godot_google_play_billing_folder" git checkout billing-v5
	ensured_in_dir "$godot_google_play_billing_folder" git pull
	ensured_folder "$godot_google_play_billing_folder/godot-google-play-billing/libs"
	ensured cp "$bin_folder/godot-lib.release.aar" "$godot_google_play_billing_folder/godot-google-play-billing/libs"

	echo "Compile godot_google_play_billing"
	ensured_in_dir "$godot_google_play_billing_folder" sed -i 's/\x0D$//' "gradlew"
	ensured_in_dir "$godot_google_play_billing_folder" ./gradlew build

	echo "Install godot_google_play_billing to project"
	ensured_folder "$project_folder/android"
	ensured_folder "$project_folder/android/plugins"
	ensured cp -r "$godot_google_play_billing_folder/godot-google-play-billing/build/outputs/aar" "$project_folder/android/plugins"
	ensured cp "$godot_google_play_billing_folder/GodotGooglePlayBilling.gdap" "$project_folder/android/plugins"

	echo "SUCCESS"
	echo "IMPORTANT: Remember to 'Install Android Build Template...' from godot 'Project' menu!"
}

build_ios() {
	Cp custom_module_config.py custom.py

	scons p=iphone tools=no target=release arch=arm
	scons p=iphone tools=no target=release arch=arm64
	scons p=iphone tools=no target=release arch=x86_64 ios_simulator=yes
	scons p=iphone tools=no target=release arch=arm64 ios_simulator=yes
	scons p=iphone tools=no target=debug arch=arm
	scons p=iphone tools=no target=debug arch=arm64
	scons p=iphone tools=no target=debug arch=x86_64 ios_simulator=yes
	scons p=iphone tools=no target=debug arch=arm64 ios_simulator=yes 

	cp -r ../misc/dist/ios_xcode .
	
	cp libgodot.iphone.debug.arm64.a ios_xcode/libgodot.iphone.debug.xcframework/ios-arm64/libgodot.a
	lipo -create libgodot.iphone.debug.arm64.simulator.a libgodot.iphone.debug.x86_64.simulator.a -output ios_xcode/libgodot.iphone.debug.xcframework/ios-arm64_x86_64-simulator/libgodot.a
	cp libgodot.iphone.opt.arm64.a ios_xcode/libgodot.iphone.release.xcframework/ios-arm64/libgodot.a
	lipo -create libgodot.iphone.opt.arm64.simulator.a libgodot.iphone.opt.x86_64.simulator.a -output  ios_xcode/libgodot.iphone.release.xcframework/ios-arm64_x86_64-simulator/libgodot.a

	(cd ios_xcode && zip -r "../iphone.zip" .)
	cp iphone.zip ~/Library/Application\ Support/Godot/templates/3.5.2.rc
	
	Rm custom.py

	git clone https://github.com/godotengine/godot-ios-plugins.git

	Rmdir godot
	ln -s ../.. godot 
	
	./scripts/generate_xcframework.sh inappstore release_debug 3.x

	mkdir ../../../../SpaceTournament/ios/
	mkdir ../../../../SpaceTournament/ios/plugins/
	mkdir ../../../../SpaceTournament/ios/plugins/inappstore
	cp -r inappstore.release_debug.xcframework ../../../../SpaceTournament/ios/plugins/inappstore/inappstore.xcframework
	cp plugins/inappstore/inappstore.gdip ../../../SpaceTournament/ios/plugins/inappstore
}




do_x11_editor=0
do_x11=0
do_android=0
do_osx_editor=0
do_osx=0
do_iphone=0

if [ $# -eq 0 ]; then
  printf "Missing arguments! List desired platforms as arguments.\n\n"
	echo_help
	exit 1
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
			do_x11_editor=1
			;;
		x11)
			do_x11=1
			;;
		android)
			do_android=1
			;;
		osx-editor)
			do_osx_editor=1
			;;
		osx)
			do_osx=1
			;;
		iphone)
			do_iphone=1
			;;
		all-linux)
			do_android=1
			do_x11=1
			do_x11_editor=1
			;;
		all-mac)
			do_osx_editor=1
			do_osx=1
			do_iphone=1
			;;
  	*)
    	printf "Error in command line usage:\n"
    	printf "Unknown command: %s\n\n" "$1"
    	echo_help
    	exit 1
    	;;
	esac
	shift
done

clean_up

if [ $do_x11_editor -eq 1 ] ; then
	echo $do_x11_editor
	echo "BUILD EDITOR FOR LINUX"
	scons platform=x11
fi

if [ $do_x11 -eq 1 ] ; then
	echo "BUILD FOR LINUX"
	ensured cp custom_module_config.py custom.py
	scons platform=x11 tools=no target=release
	ensured rm custom.py
fi

if [ $do_android -eq 1 ] ; then
	# build_android
	deploy_android
fi

if [ $do_osx_editor -eq 1 ] ; then
	echo "BUILD EDITOR FOR MAC"
	scons platform=osx arch=x86_64 --jobs=$(sysctl -n hw.logicalcpu)  # arch=arm64 for arm cpus
fi

if [ $do_osx -eq 1 ] ; then
	echo "BUILD FOR MAC"
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

if [ $do_iphone -eq 1 ] ; then
	echo "BUILD FOR IPHONE"
	cp custom_module_config.py custom.py
	scons p=iphone tools=no target=release arch=arm
	scons p=iphone tools=no target=release arch=arm64
	rm custom.py
	lipo -create bin/libgodot.iphone.opt.arm.a bin/libgodot.iphone.opt.arm64.a -output bin/libgodot.iphone.release.fat.a
fi


exit 0
