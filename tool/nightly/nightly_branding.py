"""Badge launcher artwork and separate nightly identity in the CI checkout.

Adapted from Sentorr's nightly_branding.py and nightly_identity.py.
Requires Pillow. Source files are changed only in the ephemeral build checkout.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]


def replace(relative, before, after):
    path = ROOT / relative
    text = path.read_text()
    if before not in text:
        raise ValueError(f'{relative}: expected identity marker not found: {before}')
    path.write_text(text.replace(before, after))


# A pixel crescent hair clip in the portrait's cream, rose and burgundy palette.
MOON = (
    ".....###....",
    "...####.....",
    "..####......",
    ".####.......",
    ".###........",
    "####........",
    "####........",
    ".####.......",
    ".#####......",
    "..######..##",
    "...########.",
    ".....####...",
)

def badge(path):
    with Image.open(path) as source:
        size = source.size
        image = source.convert('RGBA').resize((1024, 1024), Image.Resampling.NEAREST)
        draw = ImageDraw.Draw(image)
        pixels = {(x, y) for y, row in enumerate(MOON)
                  for x, cell in enumerate(row) if cell == '#'}
        outline = {(x + dx, y + dy) for x, y in pixels
                   for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
        step, left, top = 16, 704, 182

        def square(x, y, colour):
            px, py = left + x * step, top + y * step
            draw.rectangle((px, py, px + step - 1, py + step - 1), fill=colour)

        for x, y in outline:
            square(x, y, '#430f25')
        for x, y in pixels:
            square(x, y, '#a17bb1' if y >= 9 else '#d8b9df')
        # A companion glint gives nightly a recognizable constellation clip.
        glint = {(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)}
        glint_outline = {(x + dx, y + dy) for x, y in glint
                         for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
        step, left, top = 12, 897, 169
        for x, y in glint_outline:
            square(x, y, '#430f25')
        for x, y in glint:
            square(x, y, '#f6e2ee')
        image = image.resize(size, Image.Resampling.NEAREST)
        if path.suffix == '.ico':
            image.save(path, sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
        else:
            image.save(path)


icons = [ROOT / 'assets/images/senpwai-icon.png',
         ROOT / 'windows/runner/resources/app_icon.ico']
icons += list((ROOT / 'macos/Runner/Assets.xcassets/AppIcon.appiconset').glob('*.png'))
icons += list((ROOT / 'android/app/src/main/res').glob('mipmap-*/ic_launcher.png'))
for icon in icons:
    badge(icon)

for relative, before, after in (
    ('android/app/build.gradle.kts', 'applicationId = "com.senpwai.app"',
     'applicationId = "com.senpwai.app.nightly"'),
    ('android/app/src/main/AndroidManifest.xml', 'android:name=".MainActivity"',
     'android:name="com.senpwai.app.MainActivity"'),
    ('android/app/src/main/AndroidManifest.xml', 'android:label="Senpwai"',
     'android:label="Senpwai Nightly"'),
    ('android/app/src/main/AndroidManifest.xml', 'android:scheme="senpwai"',
     'android:scheme="senpwai-nightly"'),
    ('macos/Runner/Info.plist', '<string>senpwai</string>',
     '<string>senpwai-nightly</string>'),
    ('macos/Runner/Info.plist', '<string>senpwai.auth</string>',
     '<string>senpwai-nightly.auth</string>'),
    ('linux/com.senpwai.app.desktop', 'MimeType=x-scheme-handler/senpwai;',
     'MimeType=x-scheme-handler/senpwai-nightly;'),
    ('windows/runner/main.cpp', 'RegisterUrlProtocol(L"senpwai")',
     'RegisterUrlProtocol(L"senpwai-nightly")'),
    ('macos/Runner/Configs/AppInfo.xcconfig', 'PRODUCT_BUNDLE_IDENTIFIER = com.senpwai.app',
     'PRODUCT_BUNDLE_IDENTIFIER = com.senpwai.app.nightly'),
    ('macos/Runner/Info.plist', '<string>Senpwai</string>', '<string>Senpwai Nightly</string>'),
    ('linux/CMakeLists.txt', 'set(APPLICATION_ID "com.senpwai.app")',
     'set(APPLICATION_ID "com.senpwai.app.nightly")'),
    ('linux/com.senpwai.app.desktop', 'Name=Senpwai', 'Name=Senpwai Nightly'),
    ('linux/com.senpwai.app.desktop', 'Icon=com.senpwai.app', 'Icon=com.senpwai.app.nightly'),
    ('linux/com.senpwai.app.desktop', 'StartupWMClass=com.senpwai.app',
     'StartupWMClass=com.senpwai.app.nightly'),
    ('linux/runner/my_application.cc', '"com.senpwai.app"', '"com.senpwai.app.nightly"'),
    ('linux/runner/my_application.cc', '"Senpwai"', '"Senpwai Nightly"'),
    ('windows/runner/main.cpp', 'L"Senpwai"', 'L"Senpwai Nightly"'),
    ('windows/runner/Runner.rc', '"CompanyName", "com.senpwai.app"',
     '"CompanyName", "com.senpwai.app.nightly"'),
    ('windows/runner/Runner.rc', '"FileDescription", "Senpwai"',
     '"FileDescription", "Senpwai Nightly"'),
    ('windows/runner/Runner.rc', '"ProductName", "Senpwai"',
     '"ProductName", "Senpwai Nightly"'),
    ('scripts/setup.iss', '#define AppName "Senpwai"', '#define AppName "Senpwai Nightly"'),
    ('scripts/setup.iss', 'AppId={{902B5BE6-4A98-45C1-ACC8-100676202200}',
     'AppId={{DF9E5386-569C-4720-9BBC-2C31FE65E115}'),
    ('scripts/setup.iss',
     r'"{userappdata}\\com.senpwai.app\\Senpwai\\SenpwaiData"',
     r'"{userappdata}\\com.senpwai.app.nightly\\Senpwai Nightly\\SenpwaiNightlyData"'),
):
    replace(relative, before, after)
