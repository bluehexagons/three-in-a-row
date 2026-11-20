# Three in a Row

A compact, print-inspired Godot 4 tic-tac-toe game for the web. Choose a casual, tactical, or perfect CPU opponent, or share the board with a second local player. Each mode keeps its own scoreboard between sessions.

This game was developed to test infra-tools agentic VMs and Godot web development.

## Play locally

Use Godot 4.7.2 (the release workflow's version) and matching Web export
templates when exporting. Basaltwater on Debian is the reference environment;
the native editor, tests, and exports also work with a manual Godot installation
on other systems, including CachyOS and Windows 11.

```bash
godot --path .
```

Click or tap a square, or use keys `1`–`9` to place a mark. Press `R` to start a new round, `D` to change the CPU difficulty, or `T` to switch between light and dark themes.

## Validate and export

```bash
godot --headless --path . --script tests/test_main.gd
mkdir -p build
godot --headless --path . --export-release Web build/tictactoe.html
```

Create `build/` manually or with PowerShell's `New-Item -ItemType Directory -Force build`
on Windows. Generated `build/` and `.godot/` are ignored; preserve source, saved
games, and useful review captures. Gameplay checks change saved score/preferences
state, so run them with an isolated test user-data profile. On Linux, for example:

```bash
XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . --script tests/test_main.gd
```

For an authorized managed HTTPS publication, use the shared
`basaltwater-godot-web` skill:

```bash
basaltwater-web publish godot three-in-a-row --preset Web --json
basaltwater-web url three-in-a-row
basaltwater-web doctor three-in-a-row
```

Use the returned URL for rendered checks through the installed browser-testing
skill. Native local exports do not require Basaltwater or publication.

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

From a clean, up-to-date `main` branch, run the release script:

```bash
./release.sh
```

The script requires local `main` to exactly match `origin/main`, updates the
project version, runs the tests and a Web export, creates a release commit and
annotated tag, then pushes the branch and tag atomically. With no argument, it
increments the last numeric component of the current version. Pass a version
explicitly when you need a different increment, for example `./release.sh 1.0`.

## License

Copyright © 2026 Loren Crain.

Licensed under the [Apache License, Version 2.0](LICENSE).
