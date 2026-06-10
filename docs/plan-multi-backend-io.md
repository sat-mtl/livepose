# Plan — Multi-backend video input refactor (Camera / Video file / NDI / Spout / Syphon)

Status: **proposal, awaiting review** — no code written yet.
Tracks: livepose#1 ("support generic video input"), livepose#2 (extract JS),
livepose#51 (too many camera feeds), livepose#43 (camera FPS dedup).
Reference implementation: `sat-mtl/DomeportPro` `qml/Main.qml` (NDI/Spout/Syphon
already working there, by @ogauthiersat). Combine that work into livepose.

---

## 1. Current situation (verified, not from memory)

### 1.1 livepose input today (`qml/livepose/Views/RunView.qml`)
Two hard-coded input modes toggled by two buttons (`inputSource` = `"camera"` | `"video"`):

- **Camera** — enumerated with `Score.enumerateDevices("d615690b-…")` (the
  `Gfx::CameraDevice` protocol). On selection:
  ```js
  Score.createDevice("Camera", "d615690b-…", cameraList[i].settings) // full DeviceSettings blob
  Score.setAddress(getVideoInPortViaMapper(videoMapperLabel), "Camera:/")
  ```
  i.e. the camera is a **device** whose tree is wired into the *"in"* port of
  the `… Video Mapper` process (`Score.port(mapper, "in")`).
- **Video file** — a separate `Gfx::Video` process (labels `"pose video"` /
  `"obj video"`); selection sets `process_object.path = filePath`.

Both paths feed a 2-input mixer per scenario (`Pose Video Mixer` /
`Obj Video Mixer`), inlets 8/9 = `alpha1`/`alpha2`. `updateInputSourceMixer()`
cross-fades: camera ⇒ `alpha1=1, alpha2=0`; video ⇒ `alpha1=0, alpha2=1`.

**Key insight:** `alpha1` is the *live-device* lane (currently only camera);
`alpha2` is the *file* lane. NDI/Spout/Syphon are all **devices** exactly like
the camera, so they belong in the `alpha1` lane and need **no new mixer inlets**.

### 1.2 What ossia/score exposes (verified in the local clone)
Device protocol UUIDs (`SCORE_CONCRETE`, `src/plugins/score-plugin-gfx/Gfx/…`):

| Backend  | Input device UUID                      | Source file | Platform |
|----------|----------------------------------------|-------------|----------|
| Camera   | `d615690b-f2e2-447b-b70e-a800552db69c` | `CameraDevice.hpp` | all |
| Spout    | `3c995cb6-052b-4c52-a8fd-841b33b81b29` | `Spout/SpoutInput.hpp` | Windows |
| Syphon   | `398cec01-c4ea-43b7-8281-d848748e0f68` | `Syphon/SyphonInput.hpp` | macOS |
| NDI      | `ae78b7c6-6400-483e-b45b-fd6ff87ec700` | NDI addon (not in this clone; **proven working in DomeportPro**) | all |

`Score.enumerateDevices(uuid)` returns a `GlobalDeviceEnumerator`
(`JS/Qml/DeviceEnumerator.hpp`) with:
- `devices` (list of `DeviceIdentifier{ category, name, settings }`) — synchronous snapshot,
- `enumerate` (bool) — start/stop listening,
- `deviceAdded(factory, category, name, settings)` / `deviceRemoved(factory, name)` signals — async discovery.

`Score.createDevice(name, uuid, obj)` (`JS/Qml/EditContext.device.cpp:232`)
accepts **either**:
- a full `DeviceSettings` (what the camera enumerator hands back via `dev.settings`), **or**
- a plain JS object → JSON → `prot->makeProtocolSpecificSettings(...)`.
  Shared-texture inputs (`Gfx::SharedInputSettings`, one field `QString path`)
  take `{ "Path": "<source name>" }` — confirmed in DomeportPro.

### 1.3 How DomeportPro already does it (the template to follow)
- One reusable device named `live_input`, recreated with the chosen backend's
  UUID + settings on every change; routed with
  `Score.setAddress(Score.port(liveSource, "inputImage"), "live_input:/")`.
- **NDI**: async — registers `deviceAdded/Removed` listeners, accumulates names.
- **Spout**: async `deviceAdded` listener, names list.
- **Syphon**: synchronous `for (dev of enumerator.devices)`, keeps full
  `dev.settings` to recreate with the exact enumerated blob.
- Platform-aware mode list: Windows ⇒ Spout, macOS ⇒ Syphon, NDI everywhere.
- Env-var gating: `Util.environmentVariable("DOMEPORTPRO_BASIC")` collapses the
  list to the basic set.

### 1.4 Build availability
livepose and DomeportPro both build via `ossia/actions/package-custom-app@master`
with the **full** score plugin set (no `SCORE_QT_PLUGINS_NO_QTQUICK3D`, gfx
enabled). The Spout/Syphon/NDI devices used by DomeportPro are therefore present
in the livepose binary too. No CI/build change required for availability.

---

## 2. Goal & scope

Replace the two-button camera/video toggle with a **single backend picker** that
covers: **Camera, Video file, NDI, Spout, Syphon**. For network/shared backends
the user must be able to **type the source name** (NDI sources frequently do not
enumerate reliably across subnets; Spout/Syphon names may need manual entry).
New backends (NDI/Spout/Syphon) are **gated behind an env var** like DomeportPro.

**In scope:** QML/JS only. No new C++ in ossia/score, no `.score` re-authoring if
avoidable (see §4 — the camera lane is reused as-is). No CI change.

**Explicitly out of scope (for this change):** generic output (Spout/Syphon/NDI
*out*), audio, multi-source simultaneous mixing, per-source colour controls.

---

## 3. Env-var gating

Mirror DomeportPro. Use **`LIVEPOSE_ADVANCED_IO`**.

- Unset (default): backends = `["Camera", "Video file"]` — today's behaviour, zero regression.
- Set to a truthy value: append the platform-appropriate live backends.

```js
function availableBackends() {
    const adv = Util.environmentVariable("LIVEPOSE_ADVANCED_IO")
    const base = ["Camera", "Video file"]
    if (!adv) return base
    if (Qt.platform.os === "windows") return [...base, "NDI", "Spout"]
    if (Qt.platform.os === "osx")     return [...base, "NDI", "Syphon"]
    return [...base, "NDI"]                    // Linux
}
```

Add the var (commented/off by default) to the `environment` file with a note, so
it ships documented but inert:
```sh
# Uncomment to expose NDI / Spout / Syphon inputs in the Input Source picker
# export LIVEPOSE_ADVANCED_IO=1
```

---

## 4. Architecture decision — one live device lane, no score re-authoring

**Decision:** unify Camera + NDI + Spout + Syphon into a **single device named
`Input`** occupying the existing `alpha1` live lane, routed to the existing
`… Video Mapper` *"in"* port. Video file keeps the `alpha2` lane unchanged.

Switching backend = `removeDevice("Input")` → `createDevice("Input", uuid,
settings)` → `setAddress(mapperInPort, "Input:/")`, then mixer `alpha1=1,
alpha2=0`. Video file mode ⇒ `alpha1=0, alpha2=1`.

Rejected alternative — adding NDI/Spout/Syphon as **new mixer inlets** (the
literal reading of issue #1's "add inputs in video mixer"): requires editing
`app.score` to widen both mixers to 5 inputs and rewire, multiplies device
lifetime bugs, and gains nothing because only one live source is shown at a time.
The single-`Input`-device approach needs **no `.score` change** and reuses the
camera wiring that already works. (Rename "Camera" → "Input" is the only churn;
keep "Camera" as the device name if we want literally zero diff — naming is
cosmetic. Plan uses `Input` for clarity.)

This also fixes the device-name leak on switch: today camera uses
`removeDevice("Camera")` then recreate; we centralise that into one
`recreateInputDevice()` so every backend tears down cleanly (relevant to the
crash history in #50/#54).

---

## 5. Component breakdown (also resolves #2 "extract JS")

New files under `qml/livepose/`:

```
Components/InputSourceSelector.qml   # the refactored widget (backend + source UI)
js/InputBackends.js                  # backend descriptors + enumeration helpers
js/InputController.js                # device lifecycle (create/route/teardown)
```

### 5.1 `js/InputBackends.js` — declarative backend table
Single source of truth so adding a backend later = one entry:
```js
.pragma library
const BACKENDS = {
  "Camera":     { uuid: "d615690b-f2e2-447b-b70e-a800552db69c", kind: "device", enumerate: "sync",  typed: false, platforms: ["*"] },
  "NDI":        { uuid: "ae78b7c6-6400-483e-b45b-fd6ff87ec700", kind: "device", enumerate: "async", typed: true,  platforms: ["*"] },
  "Spout":      { uuid: "3c995cb6-052b-4c52-a8fd-841b33b81b29", kind: "device", enumerate: "async", typed: true,  platforms: ["windows"] },
  "Syphon":     { uuid: "398cec01-c4ea-43b7-8281-d848748e0f68", kind: "device", enumerate: "sync",  typed: true,  platforms: ["osx"] },
  "Video file": { kind: "file" },
}
```
- `enumerate: "sync"` ⇒ read `enumerator.devices` once (Camera, Syphon — they
  carry full `settings` blobs we must reuse verbatim).
- `enumerate: "async"` ⇒ keep `deviceAdded/Removed` listeners (NDI, Spout —
  names only; settings built as `{ "Path": name }`).
- `typed: true` ⇒ the source selector is an **editable** combo (type or pick).

### 5.2 `Components/InputSourceSelector.qml` — the widget
Replaces lines ~661–769 of `RunView.qml` ("Input Source" section). Layout:

1. **Backend combo** (`CustomComboBox`, model = `availableBackends()`).
2. **Source row**, shown only for device backends:
   - an **editable `ComboBox`** (`editable: true`, `editText` ↔ typed source).
     The current `CustomComboBox` is `Controls.Basic` non-editable; add an
     `editable`/`onAccepted` path (small variant `EditableComboBox.qml`, or
     extend `CustomComboBox` with `editable` passthrough + a styled `TextField`
     contentItem). Enumerated names populate the dropdown; typing sets the
     source for `typed` backends.
   - a **Refresh** button (re-run enumeration) — addresses "sources changed
     after launch".
   - status label: "No NDI sources found — type a source name" etc.
3. **Video-file row** (existing `FileDialog` + path field), shown when backend == "Video file".

Signals out to `RunView`: `backendChanged(name)`, `sourceChanged(name)`,
`videoPathChanged(path)`. The selector owns **no** Score calls — it only emits;
`InputController` performs them. This keeps the widget reusable (livepose,
DomeportPro, future apps) and testable.

For #51/#43 (camera shows 50+ feeds): the Camera branch de-dups by
`category`/resolution, keeping highest FPS — folded into `enumerate sync` for
Camera so the combo is readable.

### 5.3 `js/InputController.js` — device lifecycle
```js
function recreateInputDevice(backend, source, mapperLabel) {
  Score.startMacro()
  Score.removeDevice("Input")                       // idempotent teardown
  if (backend.enumerate === "sync") {
     // reuse exact enumerated DeviceSettings (Camera, Syphon)
     Score.createDevice("Input", backend.uuid, snapshot[source].settings)
  } else {
     Score.createDevice("Input", backend.uuid, { "Path": source })   // NDI, Spout
  }
  const inPort = Score.port(Score.find(mapperLabel), "in")
  if (inPort) Score.setAddress(inPort, "Input:/")
  Score.endMacro()
}
```
Mixer cross-fade and `restartIfRunning()` stay in `RunView` (they already exist).

---

## 6. Persistence (Settings) — also fixes #48-style amnesia
Extend the existing `Settings { category: "…" }` block:
`lastBackend` (string), `lastSourceName` (string), keep `lastVideoPath`.
Restore on `Component.onCompleted` after enumeration; if the saved source is gone
and the backend is `typed`, pre-fill the editable combo's text so the user sees
their last source even when offline.

---

## 7. Touch list

| File | Change |
|---|---|
| `qml/livepose/Views/RunView.qml` | Remove inline camera/video block; embed `InputSourceSelector`; wire its 3 signals to `InputController`; drop `enumerateCameras()` (moved). |
| `qml/livepose/Components/InputSourceSelector.qml` | **new** widget. |
| `qml/livepose/Components/EditableComboBox.qml` *(or extend CustomComboBox)* | **new/changed** — editable, typed source entry. |
| `qml/livepose/js/InputBackends.js` | **new** backend table + enumeration. |
| `qml/livepose/js/InputController.js` | **new** device lifecycle. |
| `qml/livepose/qmldir` | register new components/singletons. |
| `environment` | documented (off) `LIVEPOSE_ADVANCED_IO`. |
| `score/app.score` | **no change** (camera lane reused). |
| `.github/workflows/build.yml` | **no change**. |

Estimated ~250–350 lines net, 5 new files. Above the 100-line/2-file threshold,
hence this plan before code.

---

## 8. Risks / open questions
1. **NDI presence at runtime** — UUID proven in DomeportPro but the NDI addon is
   not in this score clone. Guard `createDevice`/`enumerateDevices` in
   try/catch and surface "NDI unavailable" if the protocol is missing, so a
   build without NDI degrades gracefully instead of throwing.
2. **Syphon settings blob** — DomeportPro reuses `dev.settings` from the
   enumerator (not `{Path}`); for a *typed* Syphon name with no enumerated match
   we may need `{ "Path": name }`. Verify the Syphon `makeProtocolSpecificSettings`
   accepts a bare path before relying on typing for Syphon.
3. **Editable combo styling** — `Controls.Basic` editable combo needs a styled
   `TextField` contentItem to match `DarkStyle`. Minor.
4. **Naming** — switch device name `Camera`→`Input`. If we prefer a literally
   minimal diff we keep `Camera`; decide before implementing.
5. **Should the env var name be shared org-wide** (e.g. `SAT_ADVANCED_IO`) so the
   same flag governs DomeportPro + livepose? Worth a 1-line decision.

---

## 9. Proposed sequencing
1. `InputBackends.js` + `InputController.js` (pure logic, no UI).
2. `EditableComboBox` / `CustomComboBox` editable support.
3. `InputSourceSelector.qml`, wired to the JS, behind `LIVEPOSE_ADVANCED_IO`.
4. Splice into `RunView.qml`, remove old block, persistence.
5. Manual test matrix: Camera (Linux/macOS/Win), Video file, NDI (typed +
   discovered), Spout (Win), Syphon (macOS); switch while running; restart-persist.
</content>
</invoke>
