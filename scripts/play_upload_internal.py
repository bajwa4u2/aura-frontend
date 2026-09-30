"""Upload an Android App Bundle to Google Play's INTERNAL track, with notes.

    python scripts/play_upload_internal.py <aab> <notes.txt> [--commit]

Without --commit the edit is validated and then DELETED: nothing changes on Play.
With --commit the bundle lands in the library and on the internal track.
Production stays a human act in Play Console (the publisher account cannot
release to production, by design); promote from internal there.

Auth is the same keyless impersonation as play_release_api.sh.
"""
import json
import subprocess
import sys
import urllib.request

SA = 'aura-release-publisher@aura-22b3a.iam.gserviceaccount.com'
PKG = 'org.auraplatform.app'
API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' + PKG
UPLOAD = 'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/' + PKG


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


def main():
    aab, notes_path = sys.argv[1], sys.argv[2]
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
            'releases': [{'name': '%s (1.5.2)' % vc, 'versionCodes': [vc], 'status': 'completed',
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
