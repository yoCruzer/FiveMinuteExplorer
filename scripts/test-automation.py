#!/usr/bin/env python3
"""Regression tests for credential redaction and read-only release gates."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("guard", ROOT / "scripts/verify-static.py")
GUARD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GUARD)


class StaticGuardTests(unittest.TestCase):
    def test_sensitive_files_and_example_exception(self):
        for name in [".env", "config/.env.production", "Auth.p8", "cert.p12", "key.pem",
                     "key.key", "profile.mobileprovision", "a.jks", "a.keystore", "a.ipa",
                     "xcuserdata/a", "DerivedData/a", "a.xcarchive/a", "a.xcresult/a"]:
            self.assertIn("sensitive-file", list(GUARD.sensitive_findings(name, b"")))
        self.assertEqual(list(GUARD.sensitive_findings(".env.example", b"password=example")), [])

    def test_credentials_are_reported_without_values(self):
        samples = ["ghp_" + "a" * 36, "AKIA" + "A" * 16, "sk-proj-" + "a" * 50,
                   "xoxb-" + "1" * 24, "-----BEGIN " + "PRIVATE KEY-----"]
        for credential in samples:
            findings = list(GUARD.sensitive_findings("test.txt", credential.encode()))
            self.assertTrue(findings)
            self.assertNotIn(credential, str(findings))


class ReleaseGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        scripts = self.root / "scripts"
        scripts.mkdir()
        for name in ["release-preflight.sh", "create-testflight-tag.sh"]:
            shutil.copy2(ROOT / "scripts" / name, scripts / name)
        # The real static guard is tested separately; isolate only release orchestration.
        (scripts / "verify-static.py").write_text(
            "def app_settings():\n    return [{'MARKETING_VERSION':'0.1.0','CURRENT_PROJECT_VERSION':'1'}]\n")
        executable = self.root / "mock-bin"
        executable.mkdir()
        mock = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
mode = os.environ.get('CASE', '')
with open(os.environ['CALL_LOG'], 'a') as log: log.write(pathlib.Path(sys.argv[0]).name + ' ' + ' '.join(args) + '\n')
if pathlib.Path(sys.argv[0]).name == 'git':
    if args == ['branch', '--show-current']: print('candidate' if mode == 'branch' else 'main')
    elif args == ['status', '--porcelain']: print(' M file' if mode == 'dirty' else '')
    elif args[0] == 'rev-parse': print('b' * 40 if mode == 'remote-drift' and 'HEAD' not in args else 'a' * 40)
    elif args[0] == 'fetch': pass
    elif args[0] == 'show-ref': sys.exit(0 if mode == 'existing-tag' else 1)
    elif args[0] == 'ls-remote': print('existing' if mode == 'remote-tag' else '')
    else: sys.exit('Forbidden git operation: ' + str(args))
else:
    if args[0] == 'auth': sys.exit(1 if mode == 'auth' else 0)
    if args[:2] == ['run', 'list']:
        full = 'ios-full-qa.yml' in args
        evidence = dict(databaseId=2 if full else 1, headSha=('b' if mode == 'wrong-sha' else 'a') * 40,
                        headBranch='main', event='workflow_dispatch' if full else 'push', status='completed', conclusion='success')
        print(json.dumps([] if full and mode == 'missing-full' else [evidence]))
    elif args[:2] == ['run', 'view']:
        full = args[2] == '2'
        print(json.dumps(dict(headSha='a' * 40, headBranch='main', event='workflow_dispatch' if full else 'push',
              status='completed', conclusion='success', url='https://example.invalid/run',
              jobs=[dict(name=n, conclusion='skipped' if mode == 'skipped-job' else 'success')
                    for n in (['full-qa'] if full else ['static','ios'])])))
    else: sys.exit('Unexpected gh operation')
'''
        for name in ["git", "gh"]:
            path = executable / name
            path.write_text(mock)
            path.chmod(0o755)
        self.env = dict(os.environ, PATH=str(executable) + os.pathsep + os.environ["PATH"],
                        CALL_LOG=str(self.root / "calls"))

    def tearDown(self):
        self.temp.cleanup()

    def test_dry_run_and_fail_closed_paths_never_tag_or_push(self):
        for case in ["", "branch", "dirty", "remote-drift", "existing-tag", "remote-tag",
                     "auth", "wrong-sha", "missing-full", "skipped-job"]:
            with self.subTest(case=case):
                result = subprocess.run([str(self.root / "scripts/create-testflight-tag.sh"), "0.1.0", "1"],
                                        env=dict(self.env, CASE=case), capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, case == "", result.stderr)
                if not case:
                    self.assertIn("DRY RUN", result.stdout)
        calls = (self.root / "calls").read_text()
        self.assertNotIn("git tag ", calls)
        self.assertNotIn("git push ", calls)


if __name__ == "__main__":
    unittest.main()
