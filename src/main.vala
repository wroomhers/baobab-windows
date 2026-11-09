/* -*- tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* Baobab - disk usage analyzer
 *
 * Copyright (C) 2012  Ryan Lortie <desrt@desrt.ca>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

int main (string[] args) {
#if BAOBAB_WINDOWS
    // GLib resolves this from the executable, including paths containing Unicode.
    var prefix = GLib.Win32.get_package_installation_directory_of_module (null);
    var share = Path.build_filename (prefix, "share");
    var schemas = Path.build_filename (share, "glib-2.0", "schemas");
    if (FileUtils.test (Path.build_filename (schemas, "gschemas.compiled"), FileTest.EXISTS)) {
        Environment.set_variable ("GSETTINGS_SCHEMA_DIR", schemas, true);
        Environment.set_variable ("XDG_DATA_DIRS", share, true);
    }
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Path.build_filename (share, "locale"));
#else
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.GNOMELOCALEDIR);
#endif
    Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    Intl.textdomain (Config.GETTEXT_PACKAGE);

    var baobab = new Baobab.Application ();
#if BAOBAB_WINDOWS
    return baobab.run (GLib.Win32.get_command_line ());
#else
    return baobab.run (args);
#endif
}
