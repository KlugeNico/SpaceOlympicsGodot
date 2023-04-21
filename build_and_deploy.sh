#!/bin/bash


ANDROID_SDK_ROOT="/data/android/sdk"
godot_version="3.5.2.rc"
project_folder="../SpaceTournament"

template_folder="$HOME/.local/share/godot/templates/$godot_version"
export ANDROID_SDK_ROOT

summary=""


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
	if [ -f "custom.py" ]; then
		rm "custom.py"
	fi
}

fail_exit() {
	printf "\n BUILD AND DEPLOY SUMMARY:\n%b\n" "$summary"
	printf "%s\n" "$@"
	echo "Stop Process."
	clean_up
	exit 1
}

success_msg() {
	printf "%b\n" "$1"
	summary="$summary$1\n"
}

ensured() {
	"$@" || fail_exit "ERROR: Can not: $*"
}

ensured_folder() {
	if [ ! -d "$1" ]; then
		mkdir "$1" || fail_exit "ERROR: Can not ensure folder: $1"
	fi
}

ensured_no_folder() {
	if [ -d "$1" ]; then
		rm -rf "$1" || fail_exit "ERROR: Can not remove folder: $1"
	fi
}

ensured_file_content() {
	echo "$2" >| "$1" || fail_exit "ERROR: Can not set file content: $1"
}

ensured_in_dir() {
	(cd "$1" && shift && "$@") || fail_exit "ERROR: Can not '" "${@:2}" "' in '$1'"
}


build_and_deploy_android() {
	echo "BUILD AND DEPLOY ANDROID: build"
	ensured cp custom_module_config.py custom.py
	ensured scons platform=android target=release_debug android_arch=armv7
	ensured scons platform=android target=release_debug android_arch=arm64v8
	ensured scons platform=android target=release android_arch=armv7
	ensured scons platform=android target=release android_arch=arm64v8
	ensured scons platform=android target=release android_arch=x86
	ensured scons platform=android target=release android_arch=x86_64
	ensured rm custom.py

	echo "BUILD AND DEPLOY ANDROID: gradlew generateGodotTemplates"
	ensured_in_dir platform/android/java ./gradlew generateGodotTemplates

	echo "BUILD AND DEPLOY ANDROID: install godot template folder"
	ensured cp "bin/android_source.zip" "$template_folder"

	echo "BUILD AND DEPLOY ANDROID: prepare godot_google_play_billing"
	godot_google_play_billing_folder="bin/godot-google-play-billing"
	ensured_no_folder "$godot_google_play_billing_folder"
	ensured_in_dir "bin" git clone https://github.com/godotengine/godot-google-play-billing.git
	ensured_in_dir "$godot_google_play_billing_folder" git checkout billing-v5
	ensured_in_dir "$godot_google_play_billing_folder" git pull
	ensured_folder "$godot_google_play_billing_folder/godot-google-play-billing/libs"
	ensured cp "bin/godot-lib.release.aar" "$godot_google_play_billing_folder/godot-google-play-billing/libs"

	echo "BUILD AND DEPLOY ANDROID: compile godot_google_play_billing"
	ensured_in_dir "$godot_google_play_billing_folder" sed -i 's/\x0D$//' "gradlew"
	ensured_in_dir "$godot_google_play_billing_folder" ./gradlew build

	echo "BUILD AND DEPLOY ANDROID: install godot_google_play_billing to project"
	ensured_folder "$project_folder/android"
	ensured_folder "$project_folder/android/plugins"
	ensured cp -r "$godot_google_play_billing_folder/godot-google-play-billing/build/outputs/aar/." "$project_folder/android/plugins"
	ensured cp "$godot_google_play_billing_folder/GodotGooglePlayBilling.gdap" "$project_folder/android/plugins"

	success_msg "BUILD AND DEPLOY ANDROID: SUCCESS\nIMPORTANT: Remember to 'Install Android Build Template...' from godot 'Project' menu!"
}

build_and_deploy_osx() {
	echo "BUILD AND DEPLOY OSX: build"
	ensured cp custom_module_config.py custom.py
	ensured scons platform=osx tools=no target=release arch=x86_64 --jobs="$(sysctl -n hw.logicalcpu)"
	ensured scons platform=osx tools=no target=release arch=arm64 --jobs="$(sysctl -n hw.logicalcpu)"
	ensured rm custom.py

	echo "BUILD AND DEPLOY OSX: pack"
	ensured lipo -create "bin/godot.osx.opt.x86_64" "bin/godot.osx.opt.arm64" -output "bin/godot.osx.opt.universal"
	ensured cp -r "misc/dist/osx_template.app" "bin"
	ensured_folder "bin/osx_template.app/Contents"
	ensured_folder "bin/osx_template.app/Contents/MacOS"
	ensured cp "bin/godot.osx.opt.universal" "bin/osx_template.app/Contents/MacOS/godot_osx_release.64"
	ensured chmod +x "bin/osx_template.app/Contents/MacOS/godot_osx_release.64"
	ensured_in_dir "bin" zip -q -9 -r osx.zip osx_template.app

	echo "BUILD AND DEPLOY OSX: deploy"
	ensured cp "bin/osx.zip" "$template_folder"

	success_msg "BUILD AND DEPLOY OSX: SUCCESS\nIMPORTANT: Remember to ship executeable with steam lib!"
}

build_and_deploy_ios() {
	echo "BUILD AND DEPLOY IOS: build"
	ensured cp custom_module_config.py custom.py
	ensured scons p=iphone tools=no target=release arch=arm
	ensured scons p=iphone tools=no target=release arch=arm64
	ensured scons p=iphone tools=no target=release arch=x86_64 ios_simulator=yes
	ensured scons p=iphone tools=no target=release arch=arm64 ios_simulator=yes
	ensured scons p=iphone tools=no target=debug arch=arm
	ensured scons p=iphone tools=no target=debug arch=arm64
	ensured scons p=iphone tools=no target=debug arch=x86_64 ios_simulator=yes
	ensured scons p=iphone tools=no target=debug arch=arm64 ios_simulator=yes
	ensured rm custom.py

	echo "BUILD AND DEPLOY IOS: pack"
	ensured_no_folder "bin/ios_xcode"
	ensured cp -r "misc/dist/ios_xcode" "bin"
	ensured cp "bin/libgodot.iphone.debug.arm64.a" "bin/ios_xcode/libgodot.iphone.debug.xcframework/ios-arm64/libgodot.a"
	ensured lipo -create "bin/libgodot.iphone.debug.arm64.simulator.a" "bin/libgodot.iphone.debug.x86_64.simulator.a" -output "bin/ios_xcode/libgodot.iphone.debug.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
	ensured cp "bin/libgodot.iphone.opt.arm64.a" "bin/ios_xcode/libgodot.iphone.release.xcframework/ios-arm64/libgodot.a"
	ensured lipo -create "bin/libgodot.iphone.opt.arm64.simulator.a" "bin/libgodot.iphone.opt.x86_64.simulator.a" -output  "bin/ios_xcode/libgodot.iphone.release.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
	ensured_in_dir "bin/ios_xcode" zip -q -9 -r "../iphone.zip" .

	echo "BUILD AND DEPLOY IOS: deploy"
	ensured cp "bin/iphone.zip" "$HOME/Library/Application Support/Godot/templates/3.5.2.rc"

	echo "BUILD AND DEPLOY IOS: prepare godot-ios-plugins"
	ensured_no_folder "bin/godot-ios-plugins"
	ensured_in_dir "bin" git clone https://github.com/godotengine/godot-ios-plugins.git
	ensured rmdir "bin/godot-ios-plugins/godot"
	ensured_in_dir "bin/godot-ios-plugins" ln -s ../.. godot

	echo "BUILD AND DEPLOY IOS: build godot-ios-plugin inappstore"
	ensured_in_dir "bin/godot-ios-plugins" ./scripts/generate_xcframework.sh inappstore release 3.x

	echo "BUILD AND DEPLOY IOS: deploy godot-ios-plugin inappstore"
	ensured_folder "$project_folder/ios"
	ensured_folder "$project_folder/ios/plugins"
	ensured_folder "$project_folder/ios/plugins/inappstore"
	ensured_no_folder "$project_folder/ios/plugins/inappstore/inappstore.xcframework"
	ensured cp -r "bin/godot-ios-plugins/bin/inappstore.release.xcframework" "$project_folder/ios/plugins/inappstore/inappstore.xcframework"
	ensured cp "bin/godot-ios-plugins/plugins/inappstore/inappstore.gdip" "$project_folder/ios/plugins/inappstore"

	success_msg "BUILD AND DEPLOY IOS: SUCCESS"
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
ensured_folder "$template_folder"
ensured_file_content "$template_folder/version.txt" "$godot_version"


if [ $do_x11_editor -eq 1 ] ; then
	echo "BUILD X11 EDITOR: build"
	ensured scons platform=x11
	echo "BUILD X11 EDITOR: copy steam lib"
	ensured cp "modules/godotsteam/sdk/redistributable_bin/linux64/libsteam_api.so" "bin"
	success_msg "BUILD X11 EDITOR: SUCCESS"
fi

if [ $do_x11 -eq 1 ] ; then
	echo "BUILD AND DEPLOY X11: build"
	ensured cp custom_module_config.py custom.py
	ensured scons platform=x11 tools=no target=release
	ensured rm custom.py
	echo "BUILD AND DEPLOY X11: deploy"
	ensured cp "bin/godot.x11.opt.64" "$template_folder/linux_x11_64_release"
	success_msg "BUILD X11: SUCCESS\nIMPORTANT: Remember to ship executeable with steam lib!"
fi

if [ $do_android -eq 1 ] ; then
	build_and_deploy_android
fi

if [ $do_osx_editor -eq 1 ] ; then
	echo "BUILD OSX EDITOR: build"
	ensured scons platform=osx arch=x86_64 --jobs="$(sysctl -n hw.logicalcpu)"  # arch=arm64 for arm cpus
	echo "BUILD OSX EDITOR: copy steam lib"
	ensured cp "modules/godotsteam/sdk/redistributable_bin/osx/libsteam_api.dylib" "bin"
	success_msg "BUILD OSX EDITOR: SUCCESS"
fi

if [ $do_osx -eq 1 ] ; then
	build_and_deploy_osx
fi

if [ $do_iphone -eq 1 ] ; then
	build_and_deploy_ios
fi


printf "\n BUILD AND DEPLOY SUMMARY:\n%b\n\n" "$summary"
exit 0
