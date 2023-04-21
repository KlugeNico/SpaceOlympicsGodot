echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
scons
cd bin
./godot.x11.tools.64 --editor --path ../../SpaceTournament
