#!/usr/bin/env python3
"""Isolated installer regression tests. No real user settings or KDE session used.

Run: python3 new/tools/test-install-extras.py
Set INDEX_TEST_BASH if bash is not on PATH (Windows Git Bash is auto-detected).
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest


SOURCE = Path(__file__).resolve().parent.parent
BASH = os.environ.get("INDEX_TEST_BASH")
if not BASH and os.name == "nt":
    candidate = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git/bin/bash.exe"
    if candidate.is_file():
        BASH = str(candidate)
BASH = BASH or shutil.which("bash")


@unittest.skipUnless(BASH, "bash required")
class ExtrasTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="index-extras-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.src = self.root / "source"
        self.cfg = self.root / "custom & config"
        self.data = self.root / "custom data"
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        for directory in (self.cfg, self.data, self.home, self.bin):
            directory.mkdir()
        for relative in (
            "tools/install-extras.sh", "kde/konsole/INDEX.profile",
            "kde/konsole/INDEX.colorscheme", "kde/alacritty/index.toml",
            "fastfetch/config.jsonc", "fastfetch/index.txt",
        ):
            target = self.src / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(SOURCE / relative, target)
        self.write(self.src / "assets/PerfectDOSVGA437-Universal.ttf", "font fixture")
        self.stub("id", 'printf "%s\\n" "${TEST_UID:-1000}"')
        self.stub("fc-cache", 'printf "font-cache\\n" >> "$TEST_CALLS"')
        self.stub("kwriteconfig6", '''
printf '%s\\n' "$*" >> "$TEST_CALLS"
[[ $1 == --file && $3 == --group && $4 == 'Desktop Entry' && $5 == --key && $6 == DefaultProfile && $7 == INDEX.profile ]] || exit 91
printf '\\n[Desktop Entry]\\nDefaultProfile=INDEX.profile\\n' >> "$2"
''')
        self.stub("alacritty", '''
printf 'migrate\\n' >> "$TEST_CALLS"
[[ $1 == migrate && $2 == --config-file && $4 == --skip-imports && $5 == --silent ]] || exit 92
printf '\\n# migrated\\n' >> "$3"
''')
        for command in ("sudo", "pacman", "systemctl", "qdbus6", "kwin_wayland"):
            self.stub(command, f'printf "FORBIDDEN {command}\\n" >> "$TEST_CALLS"; exit 99')
        self.env = os.environ.copy()
        self.env.update({
            "HOME": self.home.as_posix(), "XDG_CONFIG_HOME": self.cfg.as_posix(),
            "XDG_DATA_HOME": self.data.as_posix(), "TEST_BIN": self.bin.as_posix(),
            "TEST_SCRIPT": (self.src / "tools/install-extras.sh").as_posix(),
            "TEST_CALLS": (self.root / "calls").as_posix(),
        })

    @staticmethod
    def write(path, content):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8", newline="\n")

    def stub(self, name, body):
        path = self.bin / name
        self.write(path, "#!/usr/bin/env bash\nset -euo pipefail\n" + body + "\n")
        path.chmod(0o755)

    def run_helper(self, *args, success=True):
        result = subprocess.run(
            [BASH, "-c", 'if command -v cygpath >/dev/null; then TEST_BIN=$(cygpath -u "$TEST_BIN"); fi; '
             'export PATH="$TEST_BIN:$PATH"; exec bash "$TEST_SCRIPT" "$@"', "test", *args],
            env=self.env, capture_output=True, text=True,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = self.root / "calls"
        if calls.exists():
            self.assertNotIn("FORBIDDEN", calls.read_text())
        return result

    def tree(self, root):
        return {p.relative_to(root).as_posix(): p.read_bytes() for p in root.rglob("*") if p.is_file()}

    def assert_fastfetch(self):
        source = (self.src / "fastfetch/config.jsonc").read_text()
        # The supplied JSONC uses whole-line comments only.
        strip_comments = lambda value: "\n".join(line for line in value.splitlines() if not line.lstrip().startswith("//"))
        expected = json.loads(strip_comments(source))
        actual = json.loads(strip_comments((self.cfg / "fastfetch/config.jsonc").read_text()))
        expected["logo"]["source"] = (self.cfg / "fastfetch/index.txt").as_posix()
        self.assertEqual(actual, expected)
        self.assertEqual(
            (self.cfg / "fastfetch/index.txt").read_bytes(),
            b"\x1b[38;2;93;173;226m" + (self.src / "fastfetch/index.txt").read_bytes() + b"\x1b[0m\n",
        )

    def test_terminals_rerun_and_exact_restore(self):
        originals = {
            "alacritty/alacritty.toml": '[colors.primary]\nbackground = "#123456"\n',
            "alacritty/index.toml": "old theme\n", "konsolerc": "[Other]\nKeep=yes\n",
        }
        for name, value in originals.items():
            self.write(self.cfg / name, value)
        self.write(self.data / "konsole/INDEX.profile", "original profile")
        self.write(self.data / "fonts/index/PerfectDOSVGA437-Universal.ttf", "original font")
        cfg_before = self.tree(self.cfg)
        data_before = self.tree(self.data)
        self.run_helper("--components", "terminals")
        self.assertFalse((self.cfg / "fastfetch").exists())
        parsed = tomllib.loads((self.cfg / "alacritty/alacritty.toml").read_text())
        self.assertEqual(parsed["general"]["import"], [
            (self.cfg / "alacritty/alacritty.user.toml").as_posix(),
            (self.cfg / "alacritty/index.toml").as_posix(),
        ])
        snapshot = self.tree(self.data / "index/extras-backups/terminals")
        self.run_helper("--components", "terminals")
        self.assertEqual(snapshot, self.tree(self.data / "index/extras-backups/terminals"))
        self.run_helper("--components", "terminals", "--restore")
        self.assertEqual(self.tree(self.cfg), cfg_before)
        self.assertEqual({k: v for k, v in self.tree(self.data).items() if not k.startswith("index/")}, data_before)
        self.run_helper("--components", "terminals", "--restore")
        self.assertEqual(self.tree(self.cfg), cfg_before)

    def test_preexisting_alacritty_user_file_is_restored(self):
        self.write(self.cfg / "alacritty/alacritty.toml", '[window]\nopacity = 0.8\n')
        self.write(self.cfg / "alacritty/alacritty.user.toml", "# user's own existing file\n")
        before = self.tree(self.cfg)
        self.run_helper("--components", "terminals")
        self.run_helper("--components", "terminals", "--restore")
        self.assertEqual(before, self.tree(self.cfg))

    def test_does_not_remove_user_file_it_did_not_create(self):
        self.run_helper("--components", "terminals")
        user = self.cfg / "alacritty/alacritty.user.toml"
        self.write(user, "# created by user after setup\n")
        self.run_helper("--components", "terminals", "--restore")
        self.assertEqual(user.read_text(), "# created by user after setup\n")

    def test_legacy_fastfetch_backup_is_adopted_and_preserved(self):
        legacy = self.data / "index/fastfetch-before-index"
        self.write(legacy / "config.jsonc", '{"original": true}\n')
        self.write(legacy / "absent.txt", "index.txt\n")
        self.write(self.cfg / "fastfetch/config.jsonc", "old INDEX config\n")
        self.write(self.cfg / "fastfetch/index.txt", "old INDEX logo\n")
        self.write(self.data / "index/backups/old/konsolerc", "desktop backup\n")
        legacy_before = self.tree(legacy)
        self.run_helper("--components", "fastfetch")
        self.assert_fastfetch()
        self.assertFalse((self.cfg / "alacritty").exists())
        self.assertFalse((self.root / "calls").exists())
        self.run_helper("--components", "fastfetch")
        self.run_helper("--components", "fastfetch", "--restore")
        self.assertEqual((self.cfg / "fastfetch/config.jsonc").read_text(), '{"original": true}\n')
        self.assertFalse((self.cfg / "fastfetch/index.txt").exists())
        self.assertEqual(self.tree(legacy), legacy_before)
        self.assertEqual((self.data / "index/backups/old/konsolerc").read_text(), "desktop backup\n")

    def test_default_install_and_selective_restore_with_absent_configs(self):
        self.run_helper()
        self.assert_fastfetch()
        self.run_helper("--restore", "--components", "fastfetch")
        self.assertTrue((self.cfg / "alacritty/alacritty.toml").exists())
        self.assertFalse((self.cfg / "fastfetch/config.jsonc").exists())
        # Restore works with the Konsole tool missing/broken.
        self.stub("kwriteconfig6", "exit 98")
        self.run_helper("--restore")
        self.assertEqual(self.tree(self.cfg), {})
        self.assertFalse((self.data / "fonts/index/PerfectDOSVGA437-Universal.ttf").exists())
        self.assertFalse((self.home / ".config").exists())

    def test_plain_fastfetch_snapshot_survives_reruns(self):
        self.write(self.cfg / "fastfetch/config.jsonc", '{"user": true}\n')
        self.write(self.cfg / "fastfetch/index.txt", "user logo\n")
        before = self.tree(self.cfg)
        self.run_helper("--components", "fastfetch")
        self.run_helper("--components", "fastfetch")
        self.run_helper("--components", "fastfetch", "--restore")
        self.assertEqual(self.tree(self.cfg), before)

    def test_unrelated_font_on_upgrade_is_ignored(self):
        self.run_helper("--components", "terminals")
        self.write(self.src / "assets/added.otf", "new font fixture")
        self.run_helper("--components", "terminals")
        self.assertFalse((self.data / "fonts/index/added.otf").exists())
        self.run_helper("--components", "terminals", "--restore")
        self.assertFalse((self.data / "fonts/index/added.otf").exists())

    def test_preflight_checks_all_components_before_writes(self):
        (self.src / "fastfetch/config.jsonc").unlink()
        self.run_helper(success=False)
        self.assertEqual(self.tree(self.cfg), {})
        self.assertEqual(self.tree(self.data), {})

    def test_invalid_input_and_root_fail_without_writes(self):
        for args in (("--components",), ("--components", ""), ("--components", "fastfetch,"),
                     ("--components", "fastfetch,unknown"), ("--unexpected",)):
            self.run_helper(*args, success=False)
            self.assertFalse((self.data / "index").exists())
        self.env["TEST_UID"] = "0"
        self.run_helper("--components", "fastfetch", success=False)
        self.assertFalse((self.data / "index").exists())
        self.run_helper("--help")


if __name__ == "__main__":
    unittest.main(verbosity=2)
