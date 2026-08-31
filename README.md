# Tic-Tac-Toe

A compact, print-inspired Godot 4 tic-tac-toe game for the web. Choose a casual, tactical, or perfect CPU opponent, or share the board with a second local player. Each mode keeps its own scoreboard between sessions.

This game was developed to test infra-tools agentic VMs and Godot web development.

## Play locally

```bash
godot --path .
```

Click or tap a square, or use keys `1`–`9` to place a mark. Press `R` to start a new round and `D` to change the CPU difficulty.

## Validate and export

```bash
godot --headless --path . --script tests/test_main.gd
godot --headless --path . --export-release Web build/tictactoe.html
```

## License

Copyright © 2026 Loren Crain.

Licensed under the [Apache License, Version 2.0](LICENSE).
