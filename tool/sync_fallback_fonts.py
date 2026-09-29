"""Mirror Flutter's web font-fallback set into web/fallback-fonts/.

Flutter web draws text in a canvas and, the moment a script appears that no
loaded font covers, fetches a Noto font for it. web/flutter_bootstrap.js points
that fetch at /fallback-fonts/ on Aura's own origin instead of fonts.gstatic.com,
so no browser setting or network filter can turn a language into empty boxes
(founder, 2026-09-29: "it should support posting on every language on earth").

The list is the ENGINE's own (font_fallback_data.dart), so run this after every
Flutter upgrade:  python tool/sync_fallback_fonts.py
"""
import concurrent.futures as cf
import os
import re
import shutil
import subprocess
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'web', 'fallback-fonts')


def engine_list() -> list[str]:
    flutter = shutil.which('flutter')
    if not flutter:
        sys.exit('flutter is not on PATH')
    sdk = os.path.dirname(os.path.dirname(os.path.realpath(flutter)))
    data = os.path.join(sdk, 'bin', 'cache', 'flutter_web_sdk', 'lib', '_engine', 'engine', 'font_fallback_data.dart')
    if not os.path.exists(data):
        subprocess.run([flutter, 'precache', '--web'], check=True)
    paths = set(re.findall(r"'([a-z0-9]+/v\d+/[^']+\.(?:woff2|ttf|otf))'", open(data, encoding='utf-8').read()))
    # The engine also loads its BASE font (Roboto) from the same place. Missing
    # it blanked every word in the app, English included (caught 2026-09-29
    # before shipping). Take every path written after fontFallbackBaseUrl in
    # any engine file, so a new base font after an upgrade cannot be missed.
    engine = os.path.dirname(data)
    for root, _, files in os.walk(engine):
        for name in files:
            if name.endswith('.dart'):
                src = open(os.path.join(root, name), encoding='utf-8').read()
                paths.update(re.findall(r"fontFallbackBaseUrl\}([a-z0-9]+/v\d+/[^']+\.(?:woff2|ttf|otf))", src))
    return sorted(paths)


def fetch(path: str) -> int:
    dst = os.path.join(OUT, path)
    if os.path.exists(dst):
        return os.path.getsize(dst)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with urllib.request.urlopen('https://fonts.gstatic.com/s/' + path, timeout=60) as r:
        data = r.read()
    with open(dst, 'wb') as f:
        f.write(data)
    return len(data)


def main() -> None:
    paths = engine_list()
    total = failed = 0
    with cf.ThreadPoolExecutor(16) as ex:
        for fut in cf.as_completed([ex.submit(fetch, p) for p in paths]):
            try:
                total += fut.result()
            except Exception:
                failed += 1
    print(f'{len(paths)} files, {total / 1e6:.1f} MB, {failed} failed')
    if failed:
        sys.exit(1)


if __name__ == '__main__':
    main()
