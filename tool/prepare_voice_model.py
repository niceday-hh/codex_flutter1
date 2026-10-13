"""Pin and verify the Paraformer-zh INT8 model, then package only required files.

Model by FunASR / Alibaba; ONNX export by sherpa-onnx / Fangjun Kuang.
No upstream code is executed. Model weights are not stored in git.
"""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

REPO = 'csukuangfj/sherpa-onnx-paraformer-zh-2024-03-09'
REVISION = '906992d326ebf0c5171cde675aa0902be9e5bc6c'
MODEL_SHA = '90bc03034ae1bef9575f8cc798cd1519c8be8aa9e8b458a033e32017ff4d584c'
CACHE = Path('.voice-model-cache')


def download(name):
    destination = CACHE / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists():
        url = f'https://huggingface.co/{REPO}/resolve/{REVISION}/{name}'
        temporary = destination.with_suffix(destination.suffix + '.part')
        subprocess.run(['curl', '--fail', '--location', '--retry', '4', '--connect-timeout', '30',
                        '--max-time', '600', '--output', str(temporary), url], check=True)
        temporary.rename(destination)
    return destination


def digest(path):
    sha = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''): sha.update(block)
    return sha.hexdigest()


if __name__ == '__main__':
    model = download('model.int8.onnx')
    if model.stat().st_size != 227330205 or digest(model) != MODEL_SHA:
        raise RuntimeError('Paraformer model SHA256/size mismatch; do not publish')
    tokens = download('tokens.txt')
    if len(tokens.read_text().splitlines()) < 8000:
        raise RuntimeError('Incomplete Paraformer vocabulary')
    output = Path('android/app/src/main/assets/voice')
    output.mkdir(parents=True, exist_ok=True)
    for file in (model, tokens): shutil.copyfile(file, output / file.name)
    metadata = {'name': 'Paraformer-zh INT8 (220M)', 'author': 'FunASR / Alibaba',
                'conversion': 'sherpa-onnx / Fangjun Kuang', 'repository': REPO,
                'revision': REVISION, 'sha256': MODEL_SHA,
                'sizes': {file.name: file.stat().st_size for file in (model, tokens)}}
    (output / 'model.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2))
    shutil.copyfile('assets/licenses/FunASR_MODEL_LICENSE.txt', output / 'MODEL_LICENSE.txt')
    download('test_wavs/0.wav')
    print(f'Verified and packaged Paraformer-zh: {model.stat().st_size} bytes, SHA256 {MODEL_SHA}')
