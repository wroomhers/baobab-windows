// Standalone scanner regression tests; compile together with baobab-scanner.vala.
namespace Baobab {
    public class Application : Object {
        public static Application get_default () { return new Application (); }
        public GenericSet<string> get_excluded_locations () {
            return new GenericSet<string> (str_hash, str_equal);
        }
    }
}

bool run_scan (Baobab.Scanner scanner, bool expect_error, int expected_elements) {
    var loop = new MainLoop ();
    int completions = 0;
    bool passed = false;
    ulong handler = scanner.completed.connect (() => {
        completions++;
        try {
            scanner.finish ();
            passed = !expect_error && scanner.root != null &&
                     scanner.root.elements == expected_elements;
            if (passed && expected_elements == 5) {
                passed = scanner.root.children_list_store.n_items == 3 &&
                         scanner.root.size >= 3072;
            }
        } catch (Error e) {
            passed = expect_error;
        }
        loop.quit ();
    });
    uint timeout = Timeout.add_seconds (10, () => {
        loop.quit ();
        return Source.CONTINUE;
    });
    scanner.scan (true);
    loop.run ();
    Source.remove (timeout);
    scanner.disconnect (handler);
    if (completions == 0) {
        scanner.cancel ();
    }
    return completions == 1 && passed;
}

int main () {
    string fixture;
    try {
        fixture = DirUtils.make_tmp ("baobab-scanner-XXXXXX");
    } catch (Error e) {
        stderr.printf ("Cannot create fixture: %s\n", e.message);
        return 1;
    }
    string unicode_dir = Path.build_filename (fixture, "Klasör ü");
    string nested = Path.build_filename (unicode_dir, "Alt klasör");
    string empty = Path.build_filename (fixture, "empty");
    string first = Path.build_filename (unicode_dir, "dosya.bin");
    string second = Path.build_filename (nested, "ikinci.bin");
    string zero = Path.build_filename (unicode_dir, "boş.txt");
    bool passed = true;
    try {
        assert (DirUtils.create_with_parents (nested, 0700) == 0);
        assert (DirUtils.create (empty, 0700) == 0);
        FileUtils.set_data (first, new uint8[1024]);
        FileUtils.set_data (second, new uint8[2048]);
        FileUtils.set_data (zero, new uint8[0]);
        var scanner = new Baobab.Scanner (File.new_for_path (unicode_dir), Baobab.ScanFlags.EXCLUDE_MOUNTS);
        var empty_scanner = new Baobab.Scanner (File.new_for_path (empty), Baobab.ScanFlags.NONE);
        var missing = new Baobab.Scanner (File.new_for_path (Path.build_filename (fixture, "missing")), Baobab.ScanFlags.NONE);
        for (int i = 0; i < 20; i++) {
            passed = run_scan (scanner, false, 5) && passed;
            passed = run_scan (empty_scanner, false, 1) && passed;
            passed = run_scan (missing, true, 0) && passed;
        }
        // A failed query must be retryable after the directory appears.
        string retry_path = Path.build_filename (fixture, "missing");
        assert (DirUtils.create (retry_path, 0700) == 0);
        passed = run_scan (missing, false, 1) && passed;
        DirUtils.remove (retry_path);
        scanner.scan (true);
        scanner.cancel ();
        try {
            scanner.finish ();
            passed = false;
        } catch (IOError.CANCELLED e) {
        }
        passed = run_scan (scanner, false, 5) && passed;
    } catch (Error e) {
        stderr.printf ("Fixture error: %s\n", e.message);
        passed = false;
    } finally {
        FileUtils.remove (first);
        FileUtils.remove (second);
        FileUtils.remove (zero);
        DirUtils.remove (nested);
        DirUtils.remove (unicode_dir);
        DirUtils.remove (empty);
        DirUtils.remove (fixture);
    }
    print ("Scanner regression tests: %s (Unicode, empty, missing, retry, cancel)\n", passed ? "PASS" : "FAIL");
    return passed ? 0 : 1;
}
