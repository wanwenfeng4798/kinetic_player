"""Verify release extraction and cache validation without downloading a framework."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ReleaseInstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.scripts = self.root / 'darwin/scripts/sgplayer'
        shutil.copytree(ROOT / 'darwin/scripts/sgplayer', self.scripts)
        manifests = self.root / 'darwin/sgplayer'
        manifests.mkdir()
        archive = self.root / 'release.zip'
        with zipfile.ZipFile(archive, 'w') as output:
            output.writestr('Package-macOS/Artifacts/SGPlayer.xcframework/Info.plist', '<plist/>')
            output.writestr('Package-macOS/Sources/SGPlayerUI/Resources/Fonts/NotoSansCJKsc-Regular.otf', 'fixture')
            output.writestr('Package-macOS/Sources/SGPlayerUI/Resources/Licenses/OFL.txt', 'fixture')
        self.manifest = manifests / 'manifest.macos.json'
        self.data = dict(version='2.0.0', download_url=archive.as_uri(),
                         sha256=hashlib.sha256(archive.read_bytes()).hexdigest())
        self.output = self.root / 'darwin/Frameworks/macos/SGPlayer.xcframework'

    def run_installer(self):
        self.manifest.write_text(json.dumps(self.data))
        return subprocess.run(['bash', str(self.scripts / 'download_sgplayer.sh'), 'macos'],
                              capture_output=True, text=True)

    def test_nested_release_and_stamp(self):
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.output / 'Info.plist').exists())
        self.assertTrue((self.root / 'darwin/kinetic_player/Sources/kinetic_player/Resources/SGPlayer/Fonts/NotoSansCJKsc-Regular.otf').exists())
        self.assertEqual((self.output.parent / '.sgplayer-version').read_text().strip(), '2.0.0')

    def test_checksum_rejection_preserves_old_artifact(self):
        self.output.mkdir(parents=True)
        (self.output / 'old').write_text('preserve')
        self.data['sha256'] = '0' * 64
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertTrue((self.output / 'old').exists())

    def test_unversioned_cache_is_replaced(self):
        self.output.mkdir(parents=True)
        (self.output / 'old').write_text('old')
        self.assertEqual(self.run_installer().returncode, 0)
        self.assertFalse((self.output / 'old').exists())


if __name__ == '__main__':
    unittest.main()
