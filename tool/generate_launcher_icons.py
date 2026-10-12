"""Generate Android vector launchers and an SVG preview from one original design.

No external packages, network downloads, or raster scaling needed during builds.
All foreground strokes stay within the adaptive icon's central safe region.
"""
from pathlib import Path
import argparse

BG = '#FFF3DF'
PATHS = [
    ('#EDD6B4', 'M40,30 H66 Q77,30 77,41 V74 Q77,83 67,83 H40 Q30,83 30,73 V40 Q30,30 40,30 Z'),
    ('#E98532', 'M40,26 H65 Q75,26 75,36 V72 Q75,80 66,80 H40 Q30,80 30,70 V36 Q30,26 40,26 Z'),
    ('#F5AC51', 'M40,26 H44 V80 H40 Q30,80 30,70 V36 Q30,26 40,26 Z'),
    ('#FFFCF4', 'M44,34 H64 Q68,34 68,38 V67 H43 Q38,67 38,72 V40 Q38,34 44,34 Z'),
    ('#FFE6BD', 'M43,71 H68 V75 H43 Q40,75 40,73 Q40,71 43,71 Z'),
    ('#2D6B60', 'M47,34 H54 V49 L50.5,46.5 L47,49 Z'),
    ('#DBCAB0', 'M46,54 H61 Q62.5,54 62.5,55.5 Q62.5,57 61,57 H46 Q44.5,57 44.5,55.5 Q44.5,54 46,54 Z'),
    ('#DBCAB0', 'M46,60 H56 Q57.5,60 57.5,61.5 Q57.5,63 56,63 H46 Q44.5,63 44.5,61.5 Q44.5,60 46,60 Z'),
    ('#FFF3DF', 'M72,28 C72,33 74,35 79,35 C74,35 72,37 72,42 C72,37 70,35 65,35 C70,35 72,33 72,28 Z'),
]
MONO = [
    ('#FFFFFF', 'M40,26 H65 Q75,26 75,36 V72 Q75,80 66,80 H40 Q30,80 30,70 V36 Q30,26 40,26 Z M44,34 Q38,34 38,40 V72 Q38,67 43,67 H68 V38 Q68,34 64,34 H54 V49 L50.5,46.5 L47,49 V34 Z M43,71 Q40,71 40,73 Q40,75 43,75 H68 V71 Z'),
]

def vector(paths, background=False):
    contents = [f'<path android:fillColor="{c}" android:fillType="evenOdd" android:pathData="{d}"/>' for c, d in paths]
    if background:
        contents.insert(0, f'<path android:fillColor="{BG}" android:pathData="M26,2 H82 Q106,2 106,26 V82 Q106,106 82,106 H26 Q2,106 2,82 V26 Q2,2 26,2 Z"/>')
    return '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">\n' + '\n'.join(contents) + '\n</vector>\n'

def generate(res):
    files = {
        'drawable/ic_smart_budget_foreground.xml': vector(PATHS),
        'drawable/ic_smart_budget_monochrome.xml': vector(MONO),
        'mipmap-anydpi/ic_launcher.xml': vector(PATHS, background=True),
        'values/smart_budget_colors.xml': f'<resources><color name="smart_budget_icon_bg">{BG}</color></resources>\n',
    }
    for version in (26, 33):
        monochrome = '\n    <monochrome android:drawable="@drawable/ic_smart_budget_monochrome" />' if version == 33 else ''
        files[f'mipmap-anydpi-v{version}/ic_launcher.xml'] = f'''<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/smart_budget_icon_bg" />
    <foreground android:drawable="@drawable/ic_smart_budget_foreground" />{monochrome}
</adaptive-icon>
'''
    for name, content in files.items():
        path = res / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--res', type=Path, required=True)
    parser.add_argument('--preview', type=Path)
    args = parser.parse_args()
    generate(args.res)
    if args.preview:
        paths = ''.join(f'<path fill="{c}" d="{d}"/>' for c, d in PATHS)
        args.preview.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 108 108"><rect width="108" height="108" rx="25" fill="{BG}"/>{paths}</svg>\n')
