echo "Requires: VS 2019, Python 3.5+, SCons (https://docs.godotengine.org/en/stable/development/compiling/compiling_for_windows.html)"


echo "USE custom_module_config"
copy /y custom_module_config.py custom.py

scons platform=windows tools=no target=release bits=32
scons platform=windows tools=no target=release bits=64

echo "CLEAN UP custom_module_config"
del custom.py

echo "COPY STEAM LIBS FOR EDITOR"
copy /y "modules\godotsteam\sdk\redistributable_bin\steam_api.dll" "bin"
copy /y "modules\godotsteam\sdk\redistributable_bin\win64\steam_api64.dll" "bin"

echo "GENERATE TEMPLATE FOLDER"
if not exist "%APPDATA%\Godot\" mkdir "%APPDATA%\Godot"
if not exist "%APPDATA%\Godot\templates\" mkdir "%APPDATA%\Godot\templates"
if not exist "%APPDATA%\Godot\templates\3.5.2.rc\" mkdir "%APPDATA%\Godot\templates\3.5.2.rc"

echo "DEPLOY TEMPLATES"
copy /y "bin\godot.windows.opt.32.exe" "%APPDATA%\Godot\templates\3.5.2.rc\windows_32_release.exe"
copy /y "bin\godot.windows.opt.64.exe" "%APPDATA%\Godot\templates\3.5.2.rc\windows_64_release.exe"

echo "FINISH PROCESS"
echo "IMPORTANT: Remember to ship executeable with steam lib!"
