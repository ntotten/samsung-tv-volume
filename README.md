# Kill Samsung TV Volume Overlay

**Kill the Samsung Smart TV volume OSD** — the oversized banner that covers
the screen on every volume change — without modifying the TV's firmware,
without touching the disk, and with a reboot returning everything to stock.

Built for setups where the TV's speakers are never used (e.g. Apple TV → TV →
receiver over HDMI-CEC/eARC), where the banner is pure annoyance. Volume
control keeps working end-to-end — the CEC passthrough happens deeper in the
stack — the banner simply never draws.

Verified on a **QN77S90DAFXZA** (S90D OLED, 2024; software version 1310,
Tizen 8). The underlying root route is confirmed by others on the same family
on Tizen 9 (see [Compatibility](#compatibility)).

## How it works

1. **Foothold.** With the TV's Developer Mode on, Samsung's debug bridge
   (`sdbd`, TCP 26101) is reachable on the LAN. It has a public command
   injection vulnerability, **SVE-2025-50109**, and the
   [samsung-tv-root](https://github.com/chris-ritsen/samsung-tv-root) project
   turns that into a temporary, authenticated `uid=0` agent on the TV via its
   model-independent "archive-launcher" route. Nothing persists; a reboot
  closes it.
2. **The OSD is just an app.** The banner is drawn by a native EFL app,
   `/usr/apps/org.tizen.volume-app/bin/volume-app`, which the TV's app
   framework launches **on every volume event**.
3. **The decoy.** We bind-mount `/usr/bin/true` (a signed stock binary) over
   the app's binary **inside the TV's system mount namespace**. Every
   subsequent "launch" executes a no-op that exits instantly. No process, no
   window, no banner.

The result, in daily use: press volume on any remote (including CEC-forwarded
presses from an Apple TV), the receiver responds, and the screen stays clean.

## Findings: the dead ends (so you don't repeat them)

Getting to the three-line fix required ruling out four plausible approaches.
The interesting parts:

- **`killall volume-app` does nothing.** The app catches/ignores SIGTERM, and
  the framework relaunches it on the next press anyway.
- **`killall -9` does nothing either.** Tizen's `launchpad-process-pool` keeps
  the app pre-loaded in memory and answers a launch request with a `fork()`,
  which never re-executes the binary — so a path-level redirect applied
  *after* the pool loaded the app is never consulted.
- **A bind-mount from the root shell does nothing.** The `samsung-tv-root`
  agent runs your commands in a *private mount namespace*, so the mount is
  invisible to the rest of the system. Check for yourself:
  `readlink /proc/1/ns/mnt` vs `readlink /proc/self/ns/mnt`. This is the trap
  that cost us the most time.
- **The fix:** apply the bind with `nsenter -t 1 -m -- mount --bind ...` so it
  lands in the **system** namespace, *then* SIGKILL the resident instance.
  App containers are cloned from the system namespace at launch, so the
  redirect is visible to every future launch of the app.

The investigation scripts (service census, namespace checks, pool analysis)
are in [`recon/`](recon/) if you're adapting this to another model.

## Setup

### 1. Enable Developer Mode on the TV

`Apps` → scroll down to `App Settings` → enter `12345` (on a num-pad-less
Samsung remote, press the `123` button for the on-screen keypad) →
**Developer mode: On** → enter your computer's LAN IP as Host PC IP → reboot.
This is an official Samsung feature; no exploit involved.

### 2. Get the two host tools

Into `tool/` (or point `config.env` anywhere):

- `samsung-tv-root` v0.0.12:
  <https://github.com/chris-ritsen/samsung-tv-root/releases> (pick your
  host OS/arch; extract so the binary is `tool/samsung-tv-root`)
- Samsung's `sdb` (standalone package, no full Tizen Studio needed):
  [macOS](https://download.tizen.org/sdk/tizenstudio/official/binary/sdb_4.2.36_macos-64.zip)
  · [Windows](https://download.tizen.org/sdk/tizenstudio/official/binary/sdb_4.2.36_windows-64.zip)
  · [Linux](https://download.tizen.org/sdk/tizenstudio/official/binary/sdb_4.2.36_ubuntu-64.zip)
  (the binary inside is `data/tools/sdb`; put it at `tool/sdb`)

macOS notes: `sdb` is Intel-only — on Apple Silicon install Rosetta
(`softwareupdate --install-rosetta --agree-to-license`), and clear Gatekeeper
quarantine on downloaded binaries (`xattr -d com.apple.quarantine tool/sdb`).

### 3. Verify the foothold (non-destructive)

```sh
tool/samsung-tv-root --sdb tool/sdb archive-root probe <TV_IP>
```

You want `uid: 0` with `system files unchanged: yes` and
`staging cleaned: yes`. The probe performs the full acquisition and cleans
up; if your exact firmware patched the foothold, it fails without changing
anything.

### 4. Apply

```sh
TV_IP=<tv-ip> ./apply.sh     # → "VOLUME OSD: DISABLED (bind active)"
```

Press volume on the remote. No banner; volume still changes.

### 5. Persistence (optional watchdog)

A reboot clears the bind, so a tiny host-side watchdog re-applies it:

```sh
TV_IP=<tv-ip> ./install.sh   # macOS: per-user launchd agent, every 180s
```

Linux: put `watch.sh` on a cron entry or systemd timer instead. Set a DHCP
reservation for the TV so the IP survives.

**Important side effects to know:**

- Samsung's power button is **standby**, not a reboot — the bind survives
  ordinary daily on/off with no host involved. Only true reboots clear it,
  and the watchdog heals those within one interval.
- Keep the TV's **firmware auto-update OFF**. A future firmware may patch the
  foothold; at least one Tizen 10 build already rejects it. If that lands,
  you're back to stock until a new foothold exists.

## Undo

Reboot the TV — the bind evaporates. Remove the watchdog with
`launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/net.samsungtv.volume.plist`
(or delete the cron entry). Developer Mode can be switched off the same way
it was enabled.

## "Real" permanent approaches — researched, deliberately NOT attempted

We hunted for a variant that survives reboots with no host machine at all.
Here's what we found, with honest risk sizing. **None of these were tried on
our TV** — the bind + watchdog gets the same daily result with zero
persistence risk, and that's the point of the design.

| Approach | Persists? | How big is the risk, really? | Verdict |
| --- | --- | --- | --- |
| `pkgcmd` package disable | Yes (registry flag) | Low — official API, reversible with one command. | **Unsupported on our firmware** — this build's `pkgcmd` has no enable/disable verb (`-d` means "descriptor path"). If your firmware's build has it, it's a promising one-liner. Untested. |
| Hand-edit the package-registry DB (`sqlite3`) | Yes | **Low-ish, annoying worst case.** Snapshot the DB first and it's a single targeted row change; a botched registry realistically means app-framework weirdness cured by a factory reset, not a brick. But the payoff is unverified — `pkgmgr-info` may cache or rewrite the DB, and nobody's confirmed the disabled flag is honored for a preloaded system app. | Uncertain payoff; we didn't need it. |
| vconf `banner/volume/show_mode` | (a setting) | Zero risk. | **Dead end, documented to save you the evening:** the binary uses it to pick the external-speaker display *style* (number vs symbol). There is no "off" value. |
| Modify the system partition (replace the binary, add a boot unit) | Yes | **The only genuinely dangerous route.** The system filesystem is read-only *and* signature-verified; a mistake can mean a non-booting TV and a USB service recovery or worse. And every firmware update reverts it. | Not worth it for a cosmetic fix. |

## Caveats

- The **mute icon and key-guide banner** live in the same app — they're
  suppressed too. (We consider that a feature; you were warned.)
- The root route needs the host's `openssl` on `PATH` (ephemeral signing).
- If the host is off when the TV reboots, stock behavior returns until the
  host is back.
- Two watchdogs on two hosts at once can collide on the debug bridge — run
  one.

## Compatibility

| TV | Firmware | Status |
| --- | --- | --- |
| QN77S90DAFXZA (S90D 77", US) | 1310 (Tizen 8) | **Verified here** |
| QN77S90DAEXZX (S90D 77", LatAm) | Tizen 9.0 | Root route reported working ([decogzz/s90d-root](https://github.com/decogzz/s90d-root)); this OSD method untested |
| QN55S90DAFXZA (S90D 55", US) | 2130.0 | Root route reported ([couchroot](https://github.com/splitcipher/couchroot), motodrizzle); this OSD method untested |

In principle the method works on any Tizen TV where (a) the
`samsung-tv-root` archive route succeeds, (b) `nsenter` exists, and (c) the
OSD is `org.tizen.volume-app` — check (c) first on non-S90D models
(`recon/` has the scripts).

## Credits

- [chris-ritsen/samsung-tv-root](https://github.com/chris-ritsen/samsung-tv-root) —
  the toolchain this builds on (foothold, archive-launcher route, host CLI).
- motodrizzle — the original capability/mount-namespace route on an S90D
  (r/Tizen), which the archive route adapts.
- [decogzz/s90d-root](https://github.com/decogzz/s90d-root) — independent
  S90D-77" confirmation on Tizen 9, and a debloat reference.
- [splitcipher/couchroot](https://github.com/splitcipher/couchroot) — S90D
  records on Home-screen replacement and standby/boot behavior.
- [reisxd/TizenBrew](https://github.com/reisxd/TizenBrew) — the no-root
  sideloading route, if apps are all you want.

## License

MIT (this repo's scripts and docs). Third-party tools are never vendored
here and retain their own licenses.
