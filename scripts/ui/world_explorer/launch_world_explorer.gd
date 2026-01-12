extends SceneTree

## Command-line launcher for World Explorer
##
## Usage:
##   godot --headless --script scripts/ui/world_explorer/launch_world_explorer.gd -- [years] [seed]
##
## Parameters:
##   years: Number of years to simulate (default: 20)
##   seed: Random seed for generation (default: 0)
##
## Examples:
##   godot --headless --script scripts/ui/world_explorer/launch_world_explorer.gd -- 10 12345
##   godot --headless --script scripts/ui/world_explorer/launch_world_explorer.gd -- 20 0

func _init() -> void:
	# Parse command-line arguments
	var args = OS.get_cmdline_user_args()
	var years = 20
	var seed_val = 0

	if args.size() > 0:
		years = int(args[0])
	if args.size() > 1:
		seed_val = int(args[1])

	print("=".repeat(60))
	print("World Explorer Launcher")
	print("=".repeat(60))
	print("Bootstrap parameters:")
	print("  Years: %d" % years)
	print("  Seed: %d" % seed_val)
	print("=".repeat(60))

	# Run bootstrap
	var result = WorldExplorerLauncher.launch_from_bootstrap(years, seed_val)

	if result.is_empty():
		print("\n[ERROR] Launch failed!")
		quit(1)
		return

	print("\n" + "=".repeat(60))
	print("World Generation Complete!")
	print("=".repeat(60))

	var summary = result.get("summary", {})
	for key in summary.keys():
		print("  %s: %s" % [key, summary[key]])

	print("=".repeat(60))
	print("\nWorld Explorer ready to use!")
	print("To launch in GUI mode, run:")
	print("  godot scenes/main/world_explorer_main.tscn")
	print("=".repeat(60))

	quit(0)
