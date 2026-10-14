"""Configure a generated Flutter 3.47.2 iOS scaffold without touching signing."""
from pathlib import Path
import json
import plistlib
import re

from generate_launcher_icons import BG, PATHS

ROOT = Path(__file__).resolve().parents[1]
VOICE_FILE = 'A12730010000000000000001'
VOICE_BUILD = 'A12730010000000000000002'
PRIVACY_FILE = 'A12730010000000000000003'
PRIVACY_BUILD = 'A12730010000000000000004'


def configure_project(text):
    text = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [^;]+;',
                  'IPHONEOS_DEPLOYMENT_TARGET = 15.0;', text)
    text = re.sub(r'TARGETED_DEVICE_FAMILY = [^;]+;', 'TARGETED_DEVICE_FAMILY = 1;', text)
    if f'{VOICE_FILE} /* VoiceAssets */' in text:
        return text

    target = re.search(r'/\* Runner \*/ = \{\s*isa = PBXNativeTarget;.*?'
                       r'buildPhases = \((.*?)\);', text, re.S)
    if not target:
        raise ValueError('Cannot find Runner target in generated Xcode project')
    resources = re.search(r'([A-F0-9]{24}) /\* Resources \*/', target[1])
    if not resources:
        raise ValueError('Cannot find Runner resource phase')

    def append_section(source, section, lines):
        marker = f'/* End {section} section */'
        if marker not in source:
            raise ValueError(f'Missing Xcode section: {section}')
        return source.replace(marker, lines + '\n' + marker, 1)

    text = append_section(text, 'PBXBuildFile',
        f'\t\t{VOICE_BUILD} /* VoiceAssets in Resources */ = {{isa = PBXBuildFile; fileRef = {VOICE_FILE} /* VoiceAssets */; }};\n'
        f'\t\t{PRIVACY_BUILD} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; fileRef = {PRIVACY_FILE} /* PrivacyInfo.xcprivacy */; }};')
    text = append_section(text, 'PBXFileReference',
        f'\t\t{VOICE_FILE} /* VoiceAssets */ = {{isa = PBXFileReference; lastKnownFileType = folder; path = VoiceAssets; sourceTree = "<group>"; }};\n'
        f'\t\t{PRIVACY_FILE} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = PrivacyInfo.xcprivacy; sourceTree = "<group>"; }};')
    text, count = re.subn(r'(/\* Runner \*/ = \{\s*isa = PBXGroup;\s*children = \()',
        lambda m: m[1] + f'\n\t\t\t\t{VOICE_FILE} /* VoiceAssets */,\n\t\t\t\t{PRIVACY_FILE} /* PrivacyInfo.xcprivacy */,',
        text, count=1)
    if count != 1:
        raise ValueError('Cannot find Runner file group')
    phase = resources[1]
    text, count = re.subn(r'(' + phase + r' /\* Resources \*/ = \{\s*isa = PBXResourcesBuildPhase;.*?files = \()',
        lambda m: m[1] + f'\n\t\t\t\t{VOICE_BUILD} /* VoiceAssets in Resources */,\n\t\t\t\t{PRIVACY_BUILD} /* PrivacyInfo.xcprivacy in Resources */,',
        text, count=1, flags=re.S)
    if count != 1:
        raise ValueError('Cannot configure Runner resources')
    return text


def configure(root=ROOT):
    ios = root / 'ios'
    project = ios / 'Runner.xcodeproj/project.pbxproj'
    project.write_text(configure_project(project.read_text()))
    info = ios / 'Runner/Info.plist'
    data = plistlib.loads(info.read_bytes())
    data.update({
        'CFBundleDisplayName': '拾光账本',
        'NSMicrophoneUsageDescription': '用于离线语音记账。录音在本机识别，处理后删除，不上传服务器。',
        'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'],
    })
    info.write_bytes(plistlib.dumps(data, sort_keys=False))
    privacy = {'NSPrivacyTracking': False, 'NSPrivacyCollectedDataTypes': [],
               'NSPrivacyAccessedAPITypes': [{
                   'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryFileTimestamp',
                   'NSPrivacyAccessedAPITypeReasons': ['C617.1'],
               }]}
    (ios / 'Runner/PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps(privacy))
    (ios / 'Runner/VoiceAssets').mkdir(exist_ok=True)
    (ios / 'branding-paths.json').write_text(json.dumps({'background': BG, 'paths': PATHS}))


if __name__ == '__main__':
    configure()
