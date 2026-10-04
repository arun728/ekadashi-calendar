"""Validate the live test VM and narrowly classify driver transport loss."""
import json
from pathlib import Path
import re
import sys
import urllib.parse
import urllib.request
from urllib.error import URLError


def verify_vm_service(base_url, target):
    try:
        parsed = urllib.parse.urlsplit(base_url)
        if parsed.scheme != 'http' or parsed.hostname not in ('127.0.0.1', 'localhost', '::1'):
            return False

        def call(method, **arguments):
            url = base_url.rstrip('/') + '/' + method
            if arguments:
                url += '?' + urllib.parse.urlencode(arguments)
            with urllib.request.urlopen(url, timeout=1) as response:
                value = json.loads(response.read())
                return value.get('result', value)

        vm = call('getVM')
        for isolate in vm.get('isolates', []):
            if isolate.get('name') != 'main' or isolate.get('isSystemIsolate', False):
                continue
            details = call('getIsolate', isolateId=isolate['id'])
            uri = details.get('rootLib', {}).get('uri', '')
            name = urllib.parse.unquote(urllib.parse.urlsplit(uri).path).rsplit('/', 1)[-1]
            if name == Path(target).name:
                return True
        return False
    except (URLError, OSError, ValueError, KeyError, TypeError):
        return False


def may_retry_transport(log):
    # Never retry app assertions, crashes, render failures or a running test timeout.
    failures = ('Some tests failed', 'TestFailure', 'Test failed.',
                'EXCEPTION CAUGHT BY FLUTTER', 'FATAL EXCEPTION',
                'Fatal signal', 'Unhandled Exception:')
    if any(marker in log for marker in failures):
        return False
    if 'All tests passed' in log and 'Service has disappeared' in log:
        return True
    return ('Connection refused' in log
            and re.search(r'\d{2}:\d{2} \+0:', log) is None)


if __name__ == '__main__':
    if sys.argv[1] == 'ready':
        ok = verify_vm_service(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == 'retry':
        ok = may_retry_transport(Path(sys.argv[2]).read_text(errors='replace'))
    else:
        raise SystemExit('Use ready URL TARGET or retry LOG')
    raise SystemExit(0 if ok else 1)
