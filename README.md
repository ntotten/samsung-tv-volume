# Kill Samsung TV Volume Overlay

**Kill the Samsung TV volume OSD** — the oversized banner that covers the
screen on every volume change. For setups where the TV's speakers are never
used (e.g. Apple TV → TV → receiver over HDMI-CEC/eARC): volume keeps working
end-to-end, the banner simply never draws.

Verified on a **QN77S90DAFXZA** (S90D OLED, 2024; software version 1310,
Tizen 8), including across a full power cycle. The root route is confirmed by
others on the same family on Tizen 9 — see [Compatibility](#compatibility).

## How it works (30 seconds)

The volume banner is drawn by a system app (`org.tizen.volume-app`) that the
TV launches on every volume event. Using a public, volatile root route over
the LAN ([samsung-tv-root](https://github.com/chris-ritsen/samsung-tv-root);
nothing is installed and a reboot closes it), this repo either:

- **`disable.sh`** — *permanent.* Flags the app disabled in the TV's package
  registry (a settings database; snapshotted first, one command to revert).
  The framework then refuses to launch it. No host computer needed afterward.
- **`apply.sh`** — *zero writes.* Bind-mounts a no-op binary over the app
  until the next reboot. Optional `install.sh` watchdog re-applies it
  automatically (macOS launchd; Linux: run `watch.sh` from cron).

## Use it

1. **TV — enable Developer Mode** (official Samsung feature):
   `Apps` → scroll to `App Settings` → enter `12345` (on a num-pad-less
   remote, press the `123` button for the on-screen keypad) →
   **Developer mode: On** → Host PC IP = your computer's LAN IP → reboot.
2. **Computer — two tools** in `tool/`:
   - `samsung-tv-root` v0.0.12 →
     [releases](https://github.com/chris-ritsen/samsung-tv-root/releases)
     (binary at `tool/samsung-tv-root`)
   - Samsung's `sdb`, standalone:
     [macOS](https://download.tizen.org/sdk/tizenstudio/official/binary/sdb_4.2.36_macos-64.zip)
     · [Windows](https://download.tizen.org/sdk/tizenstudio/official/binary/sdb_4.2.36_windows-64.zip)
     · [Linux](https://download.tizen.org/sdk/tizenstudio/official/binary/sdb_4.2.36_ubuntu-64.zip)
     (binary inside is `data/tools/sdb` → `tool/sdb`). macOS: Intel-only, so
     Apple Silicon needs Rosetta (`softwareupdate --install-rosetta
     --agree-to-license`), and `xattr -d com.apple.quarantine tool/sdb`.
3. **Verify the foothold** (non-destructive — either returns `uid: 0` or
   changes nothing):

   ```sh
   tool/samsung-tv-root --sdb tool/sdb archive-root probe <TV_IP>
   ```

4. **Apply:**

   ```sh
   TV_IP=<tv-ip> ./disable.sh   # permanent (recommended)
   # or
   TV_IP=<tv-ip> ./apply.sh     # volatile (nothing written to flash)
   ```

5. Press volume. No banner; volume still works.

## Undo

```sh
TV_IP=<tv-ip> ./restore.sh    # re-enables the app; then reboot the TV
```

(For `apply.sh`, a reboot alone is the undo. Remove the watchdog with
`launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/net.samsungtv.volume.plist`
or by deleting the cron entry.)

## Notes

- **Keep firmware auto-update off.** An update regenerates the registry
  (reverting `disable.sh`) and may patch the root foothold — at least one
  Tizen 10 build already rejects it. If you don't use the TV's smart
  features, the clean guard is blocking the TV from the internet **while
  keeping it on your LAN** (e.g. eero: Devices → TV → **Pause** — *not*
  "Block", which kicks it off the network) so this tooling stays reachable.
  Pin the TV's IP (eero: Settings → Advanced → Reservations).
- The **mute banner** shares the same app — it's suppressed too.
- Method B only: don't run two watchdogs on two hosts at once.

## More

- **[docs/FINDINGS.md](docs/FINDINGS.md)** — how this was figured out: the
  dead ends (why killing the app can't work, the mount-namespace trap), the
  other "permanent" approaches with honest risk sizing, and what a firmware
  update would do.
- **[recon/](recon/)** — the investigation scripts, for adapting this to
  other models.
- Credits: [chris-ritsen/samsung-tv-root](https://github.com/chris-ritsen/samsung-tv-root)
  (the toolchain this builds on), motodrizzle (original S90D route),
  [decogzz/s90d-root](https://github.com/decogzz/s90d-root),
  [splitcipher/couchroot](https://github.com/splitcipher/couchroot),
  [reisxd/TizenBrew](https://github.com/reisxd/TizenBrew).

## Compatibility

| TV | Firmware | Status |
| --- | --- | --- |
| QN77S90DAFXZA (S90D 77", US) | 1310 (Tizen 8) | **Both methods verified, incl. power cycle** |
| QN77S90DAEXZX (S90D 77", LatAm) | Tizen 9.0 | Root route reported; OSD methods untested |
| QN55S90DAFXZA (S90D 55", US) | 2130.0 | Root route reported; OSD methods untested |

Any Tizen TV where the archive-root probe succeeds likely works — the
registry schema is standard Tizen pkgmgr, and the OSD app id just needs
confirming (`recon/` has the scripts).

## License

MIT (this repo's scripts and docs). Third-party tools are never vendored
here and retain their own licenses.
