# SnesRev Launcher

The [Zelda 3](https://github.com/snesrev/zelda3), [Super Metroid](https://github.com/snesrev/sm)
and [Super Mario World](https://github.com/snesrev/smw) PC ports behind one
launcher, built the same way as every other AppImage in this repository.

The upstream launcher is a shell script wrapped around prebuilt port binaries
in an AppDir. Here the ports are compiled from source during the build, the
launcher script is written from scratch as plain POSIX sh (no bashisms, no 
`jq`, no `pip` at runtime) and the AppDir layout follows what `quick-sharun`
produces.

**No ROM is shipped or downloaded.** The user drops their own dumps next to the
AppImage; the launcher identifies them by sha1, renames them, and extracts the
game assets on first launch with the ports' own python tools.

## Build

`useful-tools/demo/snesrev-launcher-appimage.sh`, run from the repository root
the same way as the other demos:

```sh
sh ./useful-tools/demo/snesrev-launcher-appimage.sh
```
It is registered for `x86_64` only: nothing about the ports is architecture
specific, but that is the only architecture it has been built and run on so far.

It compiles zelda3, sm, sm-redux and smw at pinned commits, builds `flips` in
CLI mode (the GUI build would pull in GTK3 and WebKit just to show a file
picker), assembles `AppDir/share/snesrev` with the asset tools and the Redux
patches, then hands everything to `quick-sharun`.

## Layout inside the AppImage
```sh
bin/snesrev-launcher        the launcher
bin/zelda3                  zelda3
bin/sm, bin/sm-redux        super metroid, and the Redux hack of it
bin/smw                     super mario world, smb1 and the lost levels
bin/flips                   applies the Redux IPS patches
bin/zenity                  the game picker
share/snesrev/tools/        per port asset extraction tools
share/snesrev/patches/      z3.redux.ips, sm.redux.ips
share/snesrev/icons/        per game icons for the desktop shortcuts
```

## What the launcher writes

Next to the AppImage, so the files survive AppImage updates:

| Directory | Contents |
| --- | --- |
| `srl-roms` | the user's dumps, renamed to the names the ports expect |
| `srl-config` | per game `.ini`, `zelda3_assets.dat` / `smw_assets.dat` |
| `srl-saves` | per game save files |
| `srl-run` | throwaway working directory the port is started in |

If the AppImage sits somewhere read-only (say `/usr/bin`) it falls back to
`$XDG_DATA_HOME/snesrev-launcher` instead of failing.

## Games

`z3`, `z3-redux` and the eight `z3-<lang>` translations all need the US Zelda 3
dump; the translations additionally need their own dump, because the dialogue
is baked into `zelda3_assets.dat` at extraction time. `z3-redux` and `sm-redux`
can also be built from the base ROM with the patches in the AppImage. `smb1` and
`smbll` are carved out of a Super Mario All-Stars dump, and also need a Super
Mario World dump because all three run on the same `smw` executable.

Run the AppImage with no arguments for the game picker, or `help` for the list
of commands and the sha1 each dump needs.
