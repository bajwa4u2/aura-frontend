"""Upload an Android App Bundle to Google Play's INTERNAL track, with notes.

    python scripts/play_upload_internal.py <aab> <notes.txt> [--commit]
        [--package com.example] [--version-name 1.2.0]

The release is named "<versionCode> (<version name>)". The version name is read
from pubspec.yaml beside this script unless --version-name is given (45 (1.6.0)
was once labelled "45 (1.5.2)" by a hard-coded name).

Without --commit the edit is validated and then DELETED: nothing changes on Play.
With --commit the bundle lands in the library and on the internal track.
Production stays a human act in Play Console (the publisher account cannot
release to production, by design); promote from internal there.

Auth is the same keyless impersonation as play_release_api.sh.
"""
import json
import os
import re
import subprocess
import sys
import urllib.request

SA = 'aura-release-publisher@aura-22b3a.iam.gserviceaccount.com'
PKG = 'org.auraplatform.app'
PUBSPEC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'pubspec.yaml')


def token():
    out = subprocess.run(
        ['gcloud', 'auth', 'print-access-token', '--impersonate-service-account=' + SA,
         '--scopes=https://www.googleapis.com/auth/androidpublisher'],
        capture_output=True, text=True, shell=True)
    t = out.stdout.strip()
    if not t:
        raise SystemExit('no token: ' + out.stderr[-300:])
    return t


def call(tok, method, url, body=None, data=None, ctype='application/json'):
    headers = {'Authorization': 'Bearer ' + tok}
    if body is not None:
        data = json.dumps(body).encode()
    if data is not None:
        headers['Content-Type'] = ctype
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:800]


def _arg(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def pubspec_version_name():
    """The name part of pubspec.yaml's `version: 1.6.0+45`."""
    m = re.search(r'^version:\s*([^+\s]+)', open(PUBSPEC, encoding='utf-8').read(), re.M)
    if not m:
        raise SystemExit('no version: line in ' + PUBSPEC)
    return m.group(1)


def main():
    global API, UPLOAD
    aab, notes_path = sys.argv[1], sys.argv[2]
    pkg = _arg('--package', PKG)
    version_name = _arg('--version-name', None) or pubspec_version_name()
    API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' + pkg
    UPLOAD = 'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/' + pkg
    print('package', pkg, 'version name', version_name)
    commit = '--commit' in sys.argv
    notes = open(notes_path, encoding='utf-8').read().strip()
    assert len(notes) <= 500, len(notes)
    tok = token()
    st, edit = call(tok, 'POST', API + '/edits', {})
    print('edit', st)
    eid = edit['id']
    try:
        st, b = call(tok, 'POST', UPLOAD + '/edits/%s/bundles?uploadType=media' % eid,
                     data=open(aab, 'rb').read(), ctype='application/octet-stream')
        print('upload', st, b if st != 200 else {'versionCode': b.get('versionCode'), 'sha256': b.get('sha256')})
        if st != 200:
            raise SystemExit(1)
        vc = str(b['versionCode'])
        st, t = call(tok, 'PUT', API + '/edits/%s/tracks/internal' % eid, {
            'track': 'internal',
            'releases': [{'name': '%s (%s)' % (vc, version_name), 'versionCodes': [vc], 'status': 'completed',
                          'releaseNotes': [{'language': 'en-US', 'text': notes}]}]})
        print('track internal', st, t if st != 200 else 'ok')
        st, v = call(tok, 'POST', API + '/edits/%s:validate' % eid)
        print('validate', st, v if st != 200 else 'ok')
        if st != 200 or not commit:
            call(tok, 'DELETE', API + '/edits/%s' % eid)
            print('edit discarded' + ('' if st == 200 else ' after a failed validation'))
            return
        st, c = call(tok, 'POST', API + '/edits/%s:commit' % eid)
        print('commit', st, c)
    except BaseException:
        call(tok, 'DELETE', API + '/edits/%s' % eid)
        raise


if __name__ == '__main__':
    main()
