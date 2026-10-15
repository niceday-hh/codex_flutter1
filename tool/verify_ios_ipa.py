"""Validate the actual unsigned device IPA handed to SideStore."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import stat
from zipfile import ZipFile

from prepare_voice_model import MODEL_SHA


def verify(path):
    root = 'Payload/Runner.app/'
    with ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError('Duplicate IPA entries')
        if any(not name.startswith('Payload/') or '..' in name.split('/') for name in names):
            raise ValueError('IPA must contain only the Payload directory')
        bundles = {name.split('/')[1] for name in names if len(name.split('/')) > 1 and name.split('/')[1]}
        if bundles != {'Runner.app'}:
            raise ValueError('IPA must contain exactly Payload/Runner.app')
        info = plistlib.loads(archive.read(root + 'Info.plist'))
        if info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
            raise ValueError('IPA must contain a device build, not a simulator build')
        if info.get('CFBundleShortVersionString') != '3.0.1' or info.get('CFBundleVersion') != '16':
            raise ValueError('Unexpected release version')
        if not info.get('NSMicrophoneUsageDescription'):
            raise ValueError('Missing microphone permission description')
        executable = archive.getinfo(root + info['CFBundleExecutable'])
        if not (executable.external_attr >> 16) & stat.S_IXUSR:
            raise ValueError('IPA lost executable permissions')
        for name in ('Frameworks/App.framework/App', 'Frameworks/Flutter.framework/Flutter',
                     'PrivacyInfo.xcprivacy', 'VoiceAssets/MODEL_LICENSE.txt'):
            archive.getinfo(root + name)
        if root + 'embedded.mobileprovision' in names:
            raise ValueError('Delivery IPA must not contain a device-specific provisioning profile')
        if root + 'VoiceAssets/smoke.wav' in names:
            raise ValueError('Release IPA must not contain inference test audio')
        metadata = json.loads(archive.read(root + 'VoiceAssets/model.json'))
        for name in ('model.int8.onnx', 'tokens.txt'):
            if archive.getinfo(root + 'VoiceAssets/' + name).file_size != metadata['sizes'][name]:
                raise ValueError(f'Incomplete IPA model resource: {name}')
        model_hash = hashlib.sha256()
        with archive.open(root + 'VoiceAssets/model.int8.onnx') as model:
            for block in iter(lambda: model.read(1024 * 1024), b''):
                model_hash.update(block)
        if model_hash.hexdigest() != MODEL_SHA:
            raise ValueError('IPA model SHA256 does not match Android 3.0.1')
        damaged = archive.testzip()
        if damaged:
            raise ValueError(f'Corrupt IPA entry: {damaged}')
    print(f'Verified unsigned iPhone IPA: {info["CFBundleIdentifier"]} '
          f'{info["CFBundleShortVersionString"]}+{info["CFBundleVersion"]}; '
          f'Payload layout, device platform, executable mode, Flutter frameworks, '
          f'offline model SHA256 and ZIP CRCs passed')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    verify(parser.parse_args().ipa)
