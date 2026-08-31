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

## Releases

[Play the latest tagged release on GitHub Pages](https://bluehexagons.github.io/three-in-a-row/).

The authoritative version is `application/config/version` in
`project.godot`, and the game displays it on the About screen. Releases are
tag-only: pushing a matching tag such as `v0.1` runs the GitHub workflow that
deploys the web export to GitHub Pages and attaches an itch.io-compatible ZIP
to the GitHub release. Ordinary branch pushes and pull requests do not run the
workflow.

GitHub repository setup is required once: select **GitHub Actions** as the
Pages source, then allow the `v*` tag pattern in the `github-pages`
environment's deployment branches and tags. This keeps Pages deployments
restricted to version tags.

From a clean, up-to-date `main` branch, pass the next version explicitly:

```bash
./release.sh 0.1
```

The script requires local `main` to exactly match `origin/main`, updates the
project version, runs the tests and a Web export, creates a release commit and
annotated tag, then pushes the branch and tag atomically. With no argument, it
increments the last numeric component of the current version.

## License

Copyright © 2026 Loren Crain.

Licensed under the [Apache License, Version 2.0](LICENSE).
