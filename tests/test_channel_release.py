"""Exercise release edits and replacement uploads without GitHub credentials."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
class ChannelRelease(unittest.TestCase):
    def publish(self, exists=True, fail=''):
        (ROOT/'tmp').mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT/'tmp') as tmp:
            root = Path(tmp)
            gh = root/'gh'
            gh.write_text("""#!/usr/bin/env python3
import json,os,sys
with open(os.environ['CALLS'],'a') as f: f.write(json.dumps(sys.argv[1:])+'\\n')
if sys.argv[2]=='view': sys.exit(0 if os.environ['EXISTS']=='1' else 1)
if sys.argv[2]==os.environ['FAIL']: sys.exit(7)
""")
            gh.chmod(0o755)
            asset = root/'release.zip'; asset.write_bytes(b'fixture')
            calls = root/'calls'
            result = subprocess.run(['bash',str(ROOT/'scripts/ci-publish-channel-release.sh'),
                'channel/develop','Develop',str(asset),'true'],
                env=dict(os.environ,PATH=str(root)+os.pathsep+os.environ['PATH'],
                    CALLS=str(calls),EXISTS='1' if exists else '0',FAIL=fail),capture_output=True,text=True)
            return result, [json.loads(line) for line in calls.read_text().splitlines()]

    def test_existing_release_is_edited_without_target_then_asset_replaced(self):
        result, calls = self.publish()
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual([c[1] for c in calls],['view','edit','upload'])
        self.assertNotIn('--target',calls[1])
        self.assertIn('--clobber',calls[2])
        self.assertIn('--prerelease=true',calls[1])

    def test_missing_release_is_created_for_existing_tag(self):
        result, calls = self.publish(exists=False)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual([c[1] for c in calls],['view','create'])
        self.assertIn('--verify-tag',calls[1])

    def test_edit_failure_does_not_upload(self):
        result, calls = self.publish(fail='edit')
        self.assertEqual(result.returncode,7)
        self.assertEqual([c[1] for c in calls],['view','edit'])

    def test_upload_failure_is_propagated(self):
        result, _ = self.publish(fail='upload')
        self.assertEqual(result.returncode,7)
