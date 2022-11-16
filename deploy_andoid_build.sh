#!/bin/bash

ANDROID_SDK_ROOT="/data/android/sdk"
export ANDROID_SDK_ROOT

godot_version="3.5.2.rc"
bin_src_folder="bin"
template_folder="$HOME/.local/share/godot/templates/$godot_version"
project_folder="../SpaceTournament"
godot_google_play_billing_folder="../platforms/android/godot-google-play-billing"


ensured_folder() {
	if [ ! -d "$1" ]; then
		mkdir "$1" || { printf "Can not ensure folder: %s\n" "$1"; exit 1; }
	fi
}

ensured_file_content() {
	echo "$2" >| "$1" || { printf "Can not set file content: %s\n" "$1"; exit 1; }
}

ensured_copy() {
	cp "$1" "$2" || { printf "Can not copy file from %s to %s\n" "$1" "$2"; exit 1; }
}

ensured_copy_folder_content() {
	cp -a "$1/." "$2" || { printf "Can not copy folder content from %s to %s\n" "$1" "$2"; exit 1; }
}

ensured_cd() {
	cd "$1" || { printf "Can not cd to %s\n" "$1"; exit 1; }
}


echo "Install godot template folder"
ensured_folder "$template_folder"
ensured_copy "$bin_src_folder/android_source.zip" "$template_folder"
ensured_file_content "$template_folder/version.txt" "$godot_version"

echo "Prepare godot_google_play_billing"
ensured_folder "$godot_google_play_billing_folder/godot-google-play-billing/libs"
ensured_copy "$bin_src_folder/godot-lib.release.aar" "$godot_google_play_billing_folder/godot-google-play-billing/libs"

echo "Compile godot_google_play_billing"
current_path="$(pwd)"
ensured_cd "$godot_google_play_billing_folder"
sed -i 's/\x0D$//' "gradlew" || { printf "Can not adjust line endings.\n"; exit 1; }
./gradlew build || { printf "Can not compile godot_google_play_billing.\n"; exit 1; }
ensured_cd "$current_path"

echo "Install godot_google_play_billing to project"
ensured_folder "$project_folder/android"
ensured_folder "$project_folder/android/plugins"
ensured_copy_folder_content "$godot_google_play_billing_folder/godot-google-play-billing/build/outputs/aar" "$project_folder/android/plugins"
ensured_copy "$godot_google_play_billing_folder/GodotGooglePlayBilling.gdap" "$project_folder/android/plugins"

echo "SUCCESS"
echo "IMPORTANT: Remember to 'Install Android Build Template...' from godot 'Project' menu!"
