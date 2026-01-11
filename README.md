# Gridiron Dynasty

Gridiron Dynasty is an American Football Manager–style simulation game built in
Godot. The focus is on long-running, deterministic world simulation rather than
scripted outcomes.

## Requirements

- **Godot 4.5 stable** (required)
  - Download: https://godotengine.org/download/4.x/
- Git (for cloning the repository)

## Get Started (Play the Game)

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd gridiron-dynasty
   ```

2. **Open the project in Godot**
   - Launch **Godot 4.5 stable**
   - Click **Import** and select the `project.godot` file at the repo root

3. **Run the game**
   - Press **Play** in the Godot editor (or `F5`)

## Command-Line (Optional)

You can also run the project from a terminal:

```bash
godot --path .
```

## Project Notes

- The simulation is designed to be deterministic when seeded.
- See `docs/` for architecture notes, task tracking, and design decisions.

## Contributing

- Check `plan.md` and `docs/tasks/` for the current phase and task backlog.
- Follow commit and PR standards in `COMMIT_STYLE.md` and `PR_STYLE.md`.
