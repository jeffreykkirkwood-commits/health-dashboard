"""Runs .githooks/pre-push against sample pushes in a throwaway repo (team #7)."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / '.githooks' / 'pre-push'
ZERO = '0' * 40


def git(cwd, *args):
    return subprocess.run(['git', *args], cwd=cwd, check=True, capture_output=True,
                          text=True).stdout.strip()


class PrePushHookTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        repo = cls.repo = cls.tmp.name
        git(repo, 'init', '-q')
        ident = ['-c', 'user.name=Test', '-c', 'user.email=test@example.invalid']
        git(repo, *ident, 'commit', '-q', '--allow-empty', '-m', 'base')
        cls.base = git(repo, 'rev-parse', 'HEAD')
        git(repo, *ident, 'commit', '-q', '--allow-empty', '-m', 'child')
        cls.child = git(repo, 'rev-parse', 'HEAD')
        git(repo, 'checkout', '-q', '-b', 'side', cls.base)
        git(repo, *ident, 'commit', '-q', '--allow-empty', '-m', 'sibling')
        cls.sibling = git(repo, 'rev-parse', 'HEAD')

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def run_hook(self, *lines):
        stdin = ''.join(f'{line}\n' for line in lines)
        return subprocess.run(['sh', str(HOOK), 'origin', 'https://example.invalid/repo.git'],
                              cwd=self.repo, input=stdin, capture_output=True, text=True)

    def test_hook_is_tracked_and_executable(self):
        self.assertTrue(HOOK.is_file())
        self.assertTrue(os.access(HOOK, os.X_OK))

    def test_readme_documents_install(self):
        readme = (ROOT / 'README.md').read_text()
        self.assertIn('git config core.hooksPath .githooks', readme)

    def test_blocks_risky_pushes(self):
        bad = {
            'push to main': f'refs/heads/x {self.child} refs/heads/main {self.base}',
            'push to master': f'refs/heads/x {self.child} refs/heads/master {ZERO}',
            'branch delete': f'(delete) {ZERO} refs/heads/feature {self.base}',
            'force push': f'refs/heads/x {self.sibling} refs/heads/feature {self.child}',
        }
        for name, line in bad.items():
            with self.subTest(name):
                result = self.run_hook(line)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn('pre-push: refusing', result.stderr)
        # A risky line after a safe one is still caught.
        self.assertEqual(self.run_hook(f'refs/heads/x {self.child} refs/heads/f {ZERO}',
                                       bad['push to main']).returncode, 1)

    def test_allows_normal_pushes(self):
        good = {
            'new branch': f'refs/heads/x {self.child} refs/heads/feature {ZERO}',
            'fast-forward': f'refs/heads/x {self.child} refs/heads/feature {self.base}',
            'push to staging': f'refs/heads/x {self.child} refs/heads/staging {self.base}',
        }
        for name, line in good.items():
            with self.subTest(name):
                result = self.run_hook(line)
                self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
