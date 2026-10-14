import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from configure_ios import configure_project, VOICE_BUILD, PRIVACY_BUILD


class IOSProjectConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.project = '''// !$*UTF8*$!
/* Begin PBXBuildFile section */
/* End PBXBuildFile section */
/* Begin PBXFileReference section */
/* End PBXFileReference section */
AAAAAAAAAAAAAAAAAAAAAAAA /* Runner */ = {
 isa = PBXGroup;
 children = ();
};
BBBBBBBBBBBBBBBBBBBBBBBB /* Runner */ = {
 isa = PBXNativeTarget;
 buildPhases = (CCCCCCCCCCCCCCCCCCCCCCCC /* Resources */,);
};
CCCCCCCCCCCCCCCCCCCCCCCC /* Resources */ = {
 isa = PBXResourcesBuildPhase;
 buildActionMask = 2147483647;
 files = ();
};
DDDDDDDDDDDDDDDDDDDDDDDD /* Resources */ = {
 isa = PBXResourcesBuildPhase;
 files = ();
};
IPHONEOS_DEPLOYMENT_TARGET = 13.0;
TARGETED_DEVICE_FAMILY = "1,2";
DEVELOPMENT_TEAM = EXISTINGTEAM;
'''

    def test_resources_go_to_app_not_tests_and_signing_is_preserved(self):
        result = configure_project(self.project)
        app = result.split('CCCCCCCCCCCCCCCCCCCCCCCC /* Resources */ = {')[1].split('};')[0]
        tests = result.split('DDDDDDDDDDDDDDDDDDDDDDDD /* Resources */ = {')[1].split('};')[0]
        for resource in (VOICE_BUILD, PRIVACY_BUILD):
            self.assertIn(resource, app)
            self.assertNotIn(resource, tests)
        self.assertIn('DEVELOPMENT_TEAM = EXISTINGTEAM;', result)
        self.assertIn('IPHONEOS_DEPLOYMENT_TARGET = 15.0;', result)
        self.assertEqual(configure_project(result), result)

    def test_unexpected_scaffold_fails_instead_of_silently_omitting_model(self):
        with self.assertRaisesRegex(ValueError, 'Runner target'):
            configure_project('unrecognized project')


if __name__ == '__main__':
    unittest.main()
