"""Bundle the MSYS2 UCRT64 runtime so Baobab runs outside an MSYS2 shell."""
import re
import os
import shutil
import subprocess
import sys
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

source, runtime, output = map(Path, sys.argv[1:])
if output.exists():
    raise RuntimeError(f'Package output must not exist: {output}')
system_dir = Path(os.environ['SystemRoot']) / 'System32'
bin_dir = output / 'bin'
bin_dir.mkdir(parents=True, exist_ok=True)
shutil.copy2(source / 'build/src/baobab.exe', bin_dir)
pending = [bin_dir / 'baobab.exe']


def copy_tree(relative):
    src = runtime / relative
    if src.exists():
        shutil.copytree(src, output / relative, dirs_exist_ok=True)
        pending.extend((output / relative).rglob('*.dll'))


for relative in ('share/icons/Adwaita', 'share/icons/AdwaitaLegacy',
                 'share/icons/hicolor', 'lib/gio/modules',
                 'etc/fonts', 'share/fontconfig', 'share/licenses'):
    copy_tree(relative)

# The application needs SVG icons, not every optional image/video codec.
# GdkPixbuf's built-in loaders handle PNG; keep only the SVG module and its cache.
pixbuf = Path('lib/gdk-pixbuf-2.0/2.10.0')
svg = runtime / pixbuf / 'loaders/pixbufloader_svg.dll'
loader_dir = output / pixbuf / 'loaders'
loader_dir.mkdir(parents=True, exist_ok=True)
shutil.copy2(svg, loader_dir / svg.name)
pending.append(loader_dir / svg.name)
cache = subprocess.check_output(
    [str(runtime / 'bin/gdk-pixbuf-query-loaders.exe'), str(svg)],
    text=True, encoding='utf-8')
# Windows resolves relative loader paths against the relocated installation prefix.
absolute = str(svg).replace('\\', '\\\\')
relative = str(pixbuf / 'loaders' / svg.name).replace('\\', '\\\\')
cache = cache.replace(absolute, relative)
(output / pixbuf / 'loaders.cache').write_text(cache, encoding='utf-8')

# Resolve the complete import graph, including dynamically loaded image loaders.
seen = set()
while pending:
    binary = pending.pop()
    if binary.name.lower() in seen:
        continue
    seen.add(binary.name.lower())
    imports = subprocess.check_output(
        [str(runtime / 'bin/objdump.exe'), '-p', str(binary)], text=True)
    for name in re.findall(r'DLL Name:\s*(\S+)', imports):
        dep = runtime / 'bin' / name
        if dep.exists():
            target = bin_dir / name
            shutil.copy2(dep, target)
            pending.append(target)
        elif not (system_dir / name).exists() and not name.lower().startswith(('api-ms-', 'ext-ms-')):
            raise RuntimeError(f'Missing runtime dependency: {name} (imported by {binary})')

schemas = output / 'share/glib-2.0/schemas'
schemas.mkdir(parents=True, exist_ok=True)
shutil.copy2(source / 'data/org.gnome.baobab.gschema.xml', schemas)
subprocess.run([str(runtime / 'bin/glib-compile-schemas.exe'), str(schemas)], check=True)
shutil.copytree(source / 'data/icons', output / 'share/icons', dirs_exist_ok=True)
for mo in (source / 'build/po').glob('*/LC_MESSAGES/baobab.mo'):
    dest = output / 'share/locale' / mo.relative_to(source / 'build/po')
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(mo, dest)
for locale in (runtime / 'share/locale').glob('*/LC_MESSAGES'):
    for domain in ('gtk40', 'glib20', 'libadwaita'):
        mo = locale / (domain + '.mo')
        if mo.exists():
            dest = output / 'share/locale' / mo.relative_to(runtime / 'share/locale')
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(mo, dest)
shutil.copy2(source / 'COPYING', output / 'COPYING')
with ZipFile(output / 'baobab-source.zip', 'w', ZIP_DEFLATED) as archive:
    for path in sorted(source.rglob('*')):
        relative = path.relative_to(source)
        if relative.parts[0] not in ('build', 'dist') and path.is_file():
            archive.write(path, relative.as_posix())
(output / 'README.txt').write_text(
    'Run bin/baobab.exe. Keep bin, lib, etc and share together.\n'
    'The runtime DLLs and data are bundled; MSYS2 is needed only to build.\n'
    'Baobab source: https://gitlab.gnome.org/GNOME/baobab\n'
    'Matching Baobab source and build scripts: baobab-source.zip.\n'
    'Runtime packages: https://packages.msys2.org/ (UCRT64).\n'
    'Licenses: COPYING and share/licenses.\n', encoding='utf-8')
print(f'Packaged {len(seen)} binaries in {output}')
