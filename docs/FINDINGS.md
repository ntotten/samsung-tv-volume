# Findings: how the volume OSD actually dies

Everything we learned killing the Samsung Tizen volume banner, including the
approaches that *don't* work (the majority of the time went there). Verified
on a QN77S90DAFXZA (S90D, 2024, software version 1310 / Tizen 8).

The short version of the whole document:

> The OSD is a per-event-launched native app (`org.tizen.volume-app`).
> You can't kill it (it relaunches), can't redirect its path naively (the
> launch pool forks a pre-loaded image), and can't bind-mount over it from a
> root shell (the agent runs you in a private mount namespace). What works:
> a one-row registry flag (`app_disable='true'`) that makes the framework
> refuse to launch it, or a bind-mount applied *in the system namespace*.

## The target

`ps` shows the banner is `/usr/apps/org.tizen.volume-app/bin/volume-app` —
a native EFL/Elementary app (links `libelementary`, `libedje`, Wayland
client libs), package type `rpm`, launched per volume event by the app
framework with app-control args like `cmd extvolume value -1`. Its package
contains only the binary and translations — the UI is compiled in, so there
is no CSS/JS to patch. The same binary also draws the **mute banner** and a
**key-guide banner** (`CMuteBanner`, `CKeyGuideBanner` in its symbols), so
those disappear along with it under either method.

The actual volume change — including HDMI-CEC forwarding to a receiver —
happens in the audio middleware / key-routing daemons, not in this app.
Suppressing the app never touches volume control. (Verified: receiver
responds with the app fully disabled.)

## Dead end 1: killing it

- `killall volume-app` — the app **ignores SIGTERM** (it has lifecycle
  handlers; the signal is swallowed).
- `killall -9 volume-app` — the process dies, but the next volume press
  brings back a live instance within ~1s. The launcher's args show it's
  spawned fresh by `tvctx-manager` on every press.

## Dead end 2: the prelaunch pool

Tizen keeps apps resident through `launchpad-process-pool` (the parent of
essentially every app process on the TV — see `recon/recon4.sh`). The pool
maps the app's code once and services later launches with `fork()`, which
never re-reads the binary. Consequence: any path-level redirect (rename,
bind-mount) applied *after* the pool first loaded the app is never
consulted. You'd have to kill the pool's mapped image — and the pool is the
generic loader for all apps, not just this one.

## Dead end 3: the mount-namespace trap (the one that cost the most time)

A bind-mount applied from the `samsung-tv-root` root shell **works** — and
changes nothing. The archive-root agent executes your commands in a private
mount namespace (compare `readlink /proc/1/ns/mnt` with
`readlink /proc/self/ns/mnt`; they differ, and the app pool sits in pid 1's
namespace). Verify a bind from pid 1's view with
`nsenter -t 1 -m -- wc -c <path>`: the real binary size means the system
can't see your mount.

**Fix:** apply the bind in the system namespace:

```sh
nsenter -t 1 -m -- mount --bind /usr/bin/true \
  /usr/apps/org.tizen.volume-app/bin/volume-app
killall -9 volume-app   # clear the pre-bound instance
```

App containers are cloned from the system namespace at launch, so every
future launch inherits the redirect and execs `/usr/bin/true`. (This is
Method B, `tv-apply.sh`.)

## What actually persists: the registry flag (Method A)

Tizen's package manager keeps its registry in SQLite at
`/opt/dbspace/.pkgmgr_parser.db` (flash-backed, survives reboots). The
`package_app_info` table has an `app_disable` column, default `'false'`:

```sql
UPDATE package_app_info SET app_disable='true'
  WHERE app_id='org.tizen.volume-app';
```

The framework refuses to launch a disabled app, so volume events produce no
process and no banner. Verified across a full power cycle (unplugged, not
standby — standby doesn't reboot these TVs at all, which is also why the
volatile method survives daily use).

Discipline that makes it safe: snapshot first
(`sqlite3 "file:...?mode=ro" ".backup ..."`), one targeted `UPDATE`, read the
row back. Realistic worst case if botched: app-framework weirdness cured by a
factory reset — not a brick. `tv-disable.sh` does the snapshot and readback
itself; `tv-restore.sh` reverts.

**Caveat:** a firmware update regenerates the registry from package
manifests, so an update likely resets the flag. (An update may also patch
the root foothold — both are reasons to keep auto-update off or take the TV
offline.)

`pkgmgr-info` (the package-info daemon) refused a live restart on this build
(dangling `buxton2.socket` dependency), and may cache the registry; if the
OSD still shows on the first press after the edit, reboot the TV once. The
reboot is the persistence proof anyway.

## Notes for adapting to other models

- `pkgcmd` on this firmware **has no disable verb** (`-d` means "descriptor
  path"). If your build's `pkgcmd` supports disable, that's a one-command
  official route — check `pkgcmd --help` first. Untested here.
- **`input_keyevent` cannot inject volume keys.** It feeds the window
  manager's system D-Bus channel, which navigation keys traverse, but volume
  keys route through the hardware-keys daemon. Use a real remote (or a
  SmartThings-app remote) for volume tests.
- The vconf-looking key `banner/volume/show_mode` in the binary is a dead
  end: it selects the external-speaker display *style* (number vs symbol),
  not on/off. No "off" value exists.
- The system partition is read-only **and** signature-verified. Modifying it
  (replace the binary, add a boot unit) is the only route with real brick
  potential (non-booting TV, USB service recovery), and every firmware update
  reverts it. Not worth it for a cosmetic fix — this is why both methods here
  leave it alone.
- Recon scripts used, in order: `recon/recon1.sh` (find the renderer),
  `recon2.sh` (binary/library inspection — no `strings` on the TV, pull the
  binary with `--command 'base64 <path>'` and analyze on the host),
  `recon3.sh` (identify the launch pool), `recon4.sh` (namespace proof),
  `recon5.sh` (vconf/kdb/buxton key hunt), `recon6.sh` (registry schema).
  The raw trial-and-error runs are in `recon/experiments/`.

## Risk summary

| Approach | Persists? | Risk | Verdict |
| --- | --- | --- | --- |
| Registry flag (`disable.sh`) | Yes — verified across power cycle | Snapshot + one `UPDATE`; worst case factory reset | **Recommended** |
| Bind-mount (`apply.sh`) + watchdog | Until reboot; watchdog re-applies | None — nothing is ever written to flash | Zero-risk daily option |
| `pkgcmd` disable (if your build has it) | Yes | Low — official API | Unsupported on our build |
| vconf `show_mode` | — | Zero | Dead end (style, not on/off) |
| System-partition modification | Yes | **Real brick risk** + reverted by updates | Don't |

## Credits

- [chris-ritsen/samsung-tv-root](https://github.com/chris-ritsen/samsung-tv-root) —
  SVE-2025-50109 foothold, archive-launcher root route, host CLI.
- motodrizzle — original capability/mount-namespace route on an S90D
  (r/Tizen), which the archive route adapts.
- [decogzz/s90d-root](https://github.com/decogzz/s90d-root) — independent
  S90D-77" confirmation on Tizen 9; debloat reference.
- [splitcipher/couchroot](https://github.com/splitcipher/couchroot) — S90D
  registry layout, Home-replacement records, standby/boot behavior.
- [reisxd/TizenBrew](https://github.com/reisxd/TizenBrew) — the no-root
  sideloading route.
