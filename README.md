# Baobab

Baobab is the GNOME [Disk Usage Analyzer](https://apps.gnome.org/Baobab/).

Baobab is a simple application which can scan either specific folders
(local or remote) or volumes and give a graphical representation
including each directory size or percentage in the branch. It also
auto-detects any mounted/unmounted device.


## Hacking

The code lives at GNOME [GitLab](https://gitlab.gnome.org/GNOME/baobab).

Report issues to the GNOME [issue tracking system](https://gitlab.gnome.org/GNOME/baobab/issues).


## Building on Windows

The Windows build uses the UCRT64 environment from [MSYS2](https://www.msys2.org/).
This port currently targets x86-64 Windows. Install and update MSYS2 in
`C:\msys64`, install Git, open PowerShell in this Git checkout, and run:

```powershell
.\build-windows.ps1
```

The script installs the required UCRT64 packages, builds the application, and bundles
it with its DLLs, icons, translations and compiled settings in `dist/Baobab`.
Run `dist/Baobab/bin/baobab.exe` or use the **Baobab** desktop shortcut.
Keep the entire `Baobab` folder together when moving it. The bundle includes the
runtime DLLs and data; it has been tested with MSYS2 removed from PATH on the build
machine. A separate Windows machine without MSYS2 has not yet been tested.
`baobab-source.zip` in the bundle contains the matching application source.

To rebuild using dependencies already installed:

```powershell
.\build-windows.ps1 -SkipDependencies
```

Use `-MsysRoot 'D:\msys64'` for another MSYS2 location and `-NoShortcut` to omit the
desktop shortcut. Compiler and packaging tools run in the ASCII staging directory
`<MSYS2>/tmp/baobab-windows-<unique-id>` and are removed after the build. Use an
ASCII drive path without apostrophes for MSYS2; the project and finished bundle
support Unicode paths. Every build starts with fresh sources, build files and
runtime files. After a successful replacement, the previous bundle is retained
under `dist/Baobab-previous-<unique-id>` and can be removed when no longer needed.
Close Baobab before rebuilding. `build-windows.ini` selects Clang.

Windows does not expose Unix mount identifiers, so mount boundary checks are only
applied when that metadata is available. The main volume uses the home folder's
drive root. Windows runs independent application instances; GNOME D-Bus desktop
notifications are disabled. A missing D-Bus warning from GTK can be ignored.

The script runs scanner regression tests using only the bundled DLLs before
publishing the new output folder. Tests create and remove their own fixtures and cover
Unicode paths, nested files, empty and missing directories, retries, cancellation,
and repeated scans. The same tests are available on Linux through:

```sh
meson setup build
meson compile -C build
meson test -C build --print-errorlogs
```

Linux requires the GTK and libadwaita versions specified in `meson.build`.
The Windows port does not provide a native installer or Windows notifications.
GNOME Help integration and remote-location backends have not been validated on
Windows. Changes specific to this port should be reported to the repository
distributing it; the GNOME links above identify the original project.
