"""Verify that a built release app really contains the pinned offline model."""
from pathlib import Path
import argparse
import json
import plistlib

from prepare_voice_model import MODEL_SHA, digest


def verify(app):
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if not info.get('NSMicrophoneUsageDescription'):
        raise ValueError('Missing microphone permission description')
    if info.get('CFBundleShortVersionString') != '3.0.1':
        raise ValueError('Unexpected app version')
    folder = app / 'VoiceAssets'
    metadata = json.loads((folder / 'model.json').read_text())
    model = folder / 'model.int8.onnx'
    if model.stat().st_size != 227330205 or digest(model) != MODEL_SHA:
        raise ValueError('Built app model does not match the pinned Android 3.0.1 model')
    for name in ('model.int8.onnx', 'tokens.txt'):
        if (folder / name).stat().st_size != metadata['sizes'][name]:
            raise ValueError(f'Incomplete bundled resource: {name}')
    if (folder / 'smoke.wav').exists():
        raise ValueError('Test audio must not be included in a release app')
    for name in ('MODEL_LICENSE.txt', 'PrivacyInfo.xcprivacy'):
        path = folder / name if name == 'MODEL_LICENSE.txt' else app / name
        if not path.is_file():
            raise ValueError(f'Missing release resource: {name}')
    print(f'Verified iOS {info["CFBundleShortVersionString"]}+{info["CFBundleVersion"]}: '
          f'offline model SHA256 {MODEL_SHA}; microphone text and licenses present; no test audio')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('app', type=Path)
    verify(parser.parse_args().app)
