# Tic-Tac-Toe

A compact Godot 4 tic-tac-toe game for the web. Play against an unbeatable CPU or share the board with a second local player. Each mode keeps its own persistent match score.

## Play locally

```bash
godot --path .
```

Use the mouse/touch controls or keys `1`–`9` to place a mark. Press `R` to start a fresh round.

## Validate and export

```bash
godot --headless --path . --script tests/test_main.gd
godot --headless --path . --export-release Web build/tictactoe.html
```
