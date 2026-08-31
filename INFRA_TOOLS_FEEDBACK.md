# Infra-tools agentic development feedback

> Follow-up: the VM refresh on 2026-08-31 resolved most of the initial findings below. See [Follow-up after the VM refresh](#follow-up-after-the-vm-refresh-2026-08-31) for the new results.

## Session scope

I used an infra-tools-managed agent VM on 2026-08-30 to polish and test this Godot 4.7.2 web game. The pass exercised the installed Godot workflow skill, the managed HTTPS publisher, capability diagnostics, the T3 Code preview handoff, and the VM-local Playwright fallback. `infra-tools --version` is not supported, so I could not attach an exact infra-tools CLI version to this report.

The browser workflow directly influenced the game changes: wide and phone-sized screenshots exposed the old fixed-aspect gutters and validated the expanded-canvas layout, while canvas-only browser semantics reinforced the value of first-class keyboard focus and shortcuts.

## What I exercised

| Feature | Result |
| --- | --- |
| `infra-tools-godot-web` and browser-testing skills | Concise, useful guardrails; they correctly steered publication to the shared HTTPS origin and prohibited TLS bypasses or ad-hoc public servers. |
| `godot --headless` imports and tests | Worked immediately with the installed engine and matching web templates. |
| `infra-web publish godot` | Found the project and Web preset, derived a stable slug, exported, precompressed, and atomically republished without project-specific server setup. |
| `infra-web url` / `infra-web doctor` | Returned the authoritative URL and verified the managed endpoint cleanly. |
| T3 `preview_status` / `preview_open` | Both clearly reported that no preview automation host was available for this environment. |
| `infra-tools agent doctor --capability browser --json` | Confirmed that the managed Playwright fallback was installed, registered, smoke-tested, and healthy. |
| VM-local browser tools | Successfully navigated the private HTTPS URL, sent gameplay keys, resized to desktop and phone viewports, inspected console output, and captured visual evidence. |

## What worked especially well

1. **The Godot-to-HTTPS path is genuinely low ceremony.** One command handled export and safe publication, while repeat runs retained the same URL. There was no Nginx, certificate, port, or process cleanup work in the game repository.
2. **The failure boundaries are well designed.** Publication, endpoint health, collaborative-preview availability, and VM browser capability are separate checks. That made it easy to distinguish an application problem from a client/network/tooling problem.
3. **The fallback browser shared the VM's trust and network context.** It opened the private managed URL with no certificate workaround and reported no application console errors.
4. **The workflow guidance is safety-oriented without being cumbersome.** The skill gave the exact happy path and explained why the returned URL, managed TLS, and loopback boundaries matter.
5. **Responsive inspection was fast.** Browser resize plus screenshots caught a real presentation issue that headless gameplay tests could not.

## Friction and suggested improvements

### 1. Add a safe canvas-coordinate interaction tool

Godot exposes one HTML canvas, so accessibility snapshots cannot discover its internal buttons. The managed `browser_click` accepts a selector/reference but no coordinates. To click a Godot mode control I had to use `browser_run_code_unsafe`, an explicitly RCE-equivalent escape hatch, with `page.mouse.click(...)`.

Add `x`/`y` to the safe click tool, ideally with a canvas-relative option such as `{ target: "canvas", normalized_x: 0.5, normalized_y: 0.15 }`. A screenshot-backed image locator would be even better. This would help Godot, canvas games, remote desktops, maps, and other non-DOM interfaces.

### 2. Keep browser evidence out of the worktree by default

The browser-testing skill says generated evidence is kept under `~/.local/state/infra_tools/playwright-mcp`, but this session created `.playwright-mcp/` in the current repository. Supplying `filename: "baseline-tic-tac-toe.png"` also created that file at the repository root. I cleaned both up after inspection.

The tool should default to the documented private state directory and return its resolved artifact path. An explicit `artifact_scope: "workspace"` or absolute destination could opt into deliverable evidence when requested. This avoids accidental commits and repeated worktree cleanup.

### 3. Make WebGL screenshots stable by default

Several screenshots taken immediately after a Godot animation or input contained mostly black or partially rendered frames. Waiting about one second and retrying produced the complete frame. Chromium also emitted repeated `ReadPixels` GPU-stall warnings during capture, while the application itself had zero console errors.

For WebGL canvases, screenshot capture could wait for two matching animation frames, retry implausibly empty captures, or expose a `stabilize_ms` option. Distinguishing browser-capture warnings from page console warnings in the result would also make the signal clearer.

### 4. Improve the collaborative-preview fallback handoff

`preview_status` and `preview_open` returned a clear but terminal “No preview automation host is available” message. The skill explained the next step, but the tool result itself could recommend the exact fallback probe:

```text
Collaborative preview unavailable. Try:
infra-tools agent doctor --capability browser --json
```

Even better, T3 Code could surface whether the VM fallback is healthy in the same status response. That would reduce discovery/tool calls while preserving the important distinction between client-origin and VM-origin browser tests.

### 5. Add top-level version and fuller capability reporting

`infra-tools --version` currently exits with an argument error. The general `infra-tools agent doctor --json` reports installed coding agents and credential health, while browser capability health requires a separate command.

Add a machine-readable version command and an `agent doctor --all-capabilities --json` view. A feedback or support document could then identify the exact build and relevant capabilities without probing them one by one.

### 6. Optimize command output for agent consumption

`infra-web publish godot` is excellent interactively, but normal output includes the full Godot import/export progress stream before the one-line publication result. The existing `--json` mode solved this cleanly and returned a useful stable object, though the installed skill's happy path does not mention it.

The skill should recommend `--json` for agents. The result could become even more useful with artifact sizes, elapsed time, and whether the previous publication was replaced.

## Highest-leverage next steps

1. Fix private evidence-path defaults and add safe coordinate/canvas clicking.
2. Make T3 preview failure responses point directly to the managed-browser fallback.
3. Add stable WebGL capture and structured end-to-end publication output.
4. Add `infra-tools --version` plus an all-capabilities doctor report.

The core experience is already strong: the VM turned a plain Godot repository into a trusted HTTPS build and a browser-tested game with almost no infrastructure work. The main opportunity is to make visual/canvas testing as first-class and safe as publication already is.

## Follow-up after the VM refresh (2026-08-31)

### Summary

I repeated the same workflow on infra-tools 2.0.0. The refresh directly addressed nearly every high-priority item from the initial pass. The agent now has a clearer preflight, richer structured publishing, safe canvas input, isolated evidence, reliable WebGL capture, and a comprehensive capability report.

| Initial finding | Fresh observation | Result |
| --- | --- | --- |
| No top-level version | `infra-tools --version` reports `infra-tools 2.0.0`. | Resolved |
| Capabilities required separate probes | `infra-tools agent doctor --all-capabilities --json` reports tools plus browser, development, host, and T3 Code health in one response. | Resolved |
| No Godot-specific preflight | The refreshed skill requires `--capability development`; it verified Godot 4.7.2, export templates, and web templates before work began. | Resolved |
| Publish JSON lacked useful build details | `infra-web publish godot --json` now reports elapsed time, artifact and compressed sizes/counts, and `replaced: true`. | Resolved |
| Evidence landed in the repository | Snapshots, screenshots, and console logs resolved under `~/.local/state/infra_tools/playwright-mcp`; the worktree stayed clean. | Resolved |
| Canvas clicks required unsafe code execution | `browser_mouse_click_xy` safely switched the Godot canvas to two-player mode using screenshot coordinates. No unsafe browser evaluation was needed. | Resolved |
| Immediate WebGL screenshots were often incomplete | The browser doctor reports `webgl_settle_delay: true`; every screenshot in this pass rendered completely on the first capture. | Resolved |
| Preview failure required consulting the skill for fallback | The refreshed skill explicitly treats “no preview automation host” as a VM-browser handoff and points to the capability doctor. | Improved |

The browser doctor is especially effective now. Its `launcher_features`, `issues`, `remediation`, managed-default state, and stale-process inventory make the browser path auditable instead of merely “healthy.” The all-capabilities output also confirmed host capacity and T3 Code service health without separate diagnostic commands.

### Remaining preview lifecycle issue

The collaborative preview was inconsistent during this follow-up:

1. `preview_status` initially returned `available: true`.
2. `preview_open` created visible tab `tab_3` at `about:blank`.
3. The immediate `preview_navigate` call reported that no preview automation host was available.
4. A follow-up `preview_status` reported the same unavailable-host condition.

At the same time, `infra-tools agent doctor --all-capabilities --json` reported the T3 Code service and endpoint healthy. That distinction is plausible—the VM service can be healthy while the current collaborative automation attachment is gone—but it is not visible in either result.

Suggested next improvements:

1. Make `preview_open` transactional: return success only after the automation host lease is confirmed for the returned tab, or return a specific `host_disconnected` state.
2. Add current-session preview attachment health to the T3 Code capability report, separately from server/service health.
3. Keep the new skill-level fallback guidance, and also include its exact capability-doctor command in the preview tool error itself.

### Smaller opportunities

- The safe coordinate tool is a major improvement. A canvas-relative or normalized coordinate mode would make interactions resilient across viewport sizes and avoid manually recalculating CSS pixels after resize.
- Screenshot results still summarize Chromium `ReadPixels` capture messages as console warnings. The skill correctly explains that these are browser-process warnings, but labeling them separately in tool output would remove the remaining ambiguity.
- `--all-capabilities` is comprehensive and useful for support capture. A compact summary mode could make routine agent preflight easier to scan while retaining the full JSON form for diagnostics.

Overall, the refresh turned the original feedback loop into a satisfying verification exercise: six concrete issues were fully resolved, one was materially improved, and the remaining problem is narrowly scoped to collaborative-preview attachment lifecycle.

## Second refresh and minimized-preview correction (2026-08-31)

I repeated the workflow after another setup run. `infra-tools --version` still
reports 2.0.0, while the capability report identifies T3 Code 0.0.37. The
development, browser, host, and T3 Code capabilities were all healthy. Godot
4.7.2 and its Web templates were ready without repair, and structured Godot
publication replaced the existing build in 6.028 seconds.

The initial T3 result looked like a regression: navigation reached both the
public GitHub Pages build and the private managed HTTPS build, but the tab
reported `visible: false` and snapshots failed with `UnknownVizError`. The
connected T3 application was minimized at the time. Once it was restored:

- `preview_status` changed to `visible: true` without reopening or navigating
  the tab.
- The next snapshot completed in under a second with a full WebGL frame,
  canvas bounds, console output, and no application errors.
- Safe coordinate clicking switched game modes, and keyboard input placed
  marks without an unsafe evaluation tool.
- Pressing `R` followed immediately by a snapshot caught the new round
  animation at its edge-on midpoint; a second snapshot confirmed the cleared
  board and restored controls.

This corrects my initial diagnosis during this pass: the failed captures were
not evidence of a Godot page-main-thread stall. They were tied to the minimized
T3 window. The refreshed collaborative path works very well when the
application is visible and is now capable of low-latency animation evidence
that the VM-local fallback's settle delay cannot capture as precisely.

### Fresh feedback

1. Distinguish a minimized application from a hidden but automation-capable
   preview. The browser-testing guidance correctly says `visible: false` can
   still be usable, so status needs a separate window-state or
   capture-capability field.
2. Fail snapshots fast with a specific `window_minimized` or
   `capture_unavailable` result and a “restore T3 Code” remediation. An
   `UnknownVizError` led to unnecessary retries and fallback diagnostics.
3. The snapshot action timeline reports the snapshot currently producing the
   response as `running`; it changes to `succeeded` on the following call.
   Marking it complete before serializing the response would make captured
   evidence self-consistent.
4. The top-level infra-tools version did not change across this refresh even
   though behavior and bundled components changed. Including a build revision
   or setup bundle version would make feedback reports reproducible.

The managed Playwright fallback also remained healthy and kept every artifact
under `~/.local/state/infra_tools/playwright-mcp`. Its screenshots carried only
the documented Chromium `ReadPixels` warnings, with zero application errors.
The fallback remains valuable for VM-origin checks, but it was not needed to
work around the game once T3 was restored.
