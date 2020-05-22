#!/usr/bin/env python3
"""Script that performs a test of a Portier instance.

This code is based on the relying party demo code. It uses the JSON API of the
Portier Broker and the Postmark webhook functionality to run through the full
authentication process without a browser.

A separate server stores the last received Postmark webhook. The code for this
is in `./server/` and it must be started separately.
"""

from base64 import urlsafe_b64decode
from email.utils import parsedate_tz, mktime_tz
from traceback import print_exc
from time import perf_counter, time, sleep
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from uuid import uuid4
import json
import os
import re

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.asymmetric import rsa
import jwt

# Read settings from the environment.
broker_origin = os.environ['BROKER_ORIGIN']
test_origin = os.environ['TEST_ORIGIN']
test_email = os.environ['TEST_EMAIL']
secret_file = os.environ['SECRET_FILE']
logs_directory = os.environ['LOGS_DIRECTORY']

# Read the secret file.
with open(secret_file) as f:
    secret = f.read().strip()

# Stats record written to `stats.jsonl`.
stats = {}


def b64dec(string):
    """Decode unpadded URL-safe Base64 strings."""
    padding = '=' * ((4 - len(string) % 4) % 4)
    return urlsafe_b64decode(string + padding)


def jwk_to_rsa(key):
    """Convert a deserialized JWK into an RSA Public Key instance."""
    e = int.from_bytes(b64dec(key['e']), 'big')
    n = int.from_bytes(b64dec(key['n']), 'big')
    return rsa.RSAPublicNumbers(e, n).public_key(default_backend())


def run_test():
    # Fetch the discovery document.
    discovery_start_perf = perf_counter()
    res = urlopen(broker_origin + '/.well-known/openid-configuration')
    stats['discovery'] = perf_counter() - discovery_start_perf
    discovery_data = json.loads(res.read().decode('utf-8'))

    # Start authorization.
    nonce = uuid4().hex
    url = discovery_data['authorization_endpoint'] + '?' + urlencode({
        'login_hint': test_email,
        'scope': 'openid email',
        'nonce': nonce,
        'response_type': 'id_token',
        'response_mode': 'form_post',
        'client_id': test_origin,
        'redirect_uri': test_origin + '/autotest/verify',
    })
    auth_start_perf = perf_counter()
    auth_start_time = time()
    res = urlopen(Request(url, headers={'Accept': 'application/json'}))
    stats['auth'] = perf_counter() - auth_start_perf
    auth_data = json.loads(res.read().decode('utf-8'))

    if auth_data.get('result') != 'verification_code_sent':
        raise RuntimeError(f"Unexpected auth response: {auth_data}")

    # Wait until the mail arrives.
    inbox = test_origin + '/autotest/' + secret
    code_re = re.compile('^[a-z0-9]{6} [a-z0-9]{6}$', re.MULTILINE)
    mail_start_perf = perf_counter()
    for attempt in range(60):
        try:
            res = urlopen(inbox)
            last_mail = json.loads(res.read().decode('utf-8'))

            # Look for the code. Also check the mail is recent.
            code_match = code_re.search(last_mail['TextBody'])
            mail_date = mktime_tz(parsedate_tz(last_mail['Date']))
            if code_match and abs(mail_date - auth_start_time) < 300:
                break
        except json.JSONDecodeError:
            pass

        sleep(0.5)
    else:
        raise RuntimeError("Timeout waiting for verification mail")
    stats['mail'] = perf_counter() - mail_start_perf

    # Submit the code.
    url = broker_origin + '/confirm'
    data = urlencode({
        'session': auth_data['session'],
        'code': code_match.group(0)
    }).encode('ascii')
    confirm_start_perf = perf_counter()
    res = urlopen(Request(url, data, headers={'Accept': 'application/json'}))
    stats['confirm'] = perf_counter() - confirm_start_perf
    confirm_data = json.loads(res.read().decode('utf-8'))

    token = confirm_data.get('id_token')
    if not token:
        raise RuntimeError(f"Unexpected confirm response: {confirm_data}")

    # Fetch and parse JWKs.
    jwks_start_perf = perf_counter()
    res = urlopen(discovery_data['jwks_uri'])
    stats['jwks'] = perf_counter() - jwks_start_perf
    jwks_data = json.loads(res.read().decode('utf-8'))
    keys = {key['kid']: jwk_to_rsa(key) for key in jwks_data['keys']
            if key['alg'] == 'RS256'}

    # Locate the specific key used to sign this JWT via its ``kid`` header.
    raw_header, _, _ = token.partition('.')
    header = json.loads(b64dec(raw_header).decode('utf-8'))
    try:
        pub_key = keys[header['kid']]
    except KeyError:
        raise RuntimeError('Cannot find public key with ID %s' % header['kid'])

    # Verify the JWT's signature and validate its claims
    try:
        payload = jwt.decode(token, pub_key,
                             algorithms=['RS256'],
                             audience=test_origin,
                             issuer=broker_origin,
                             leeway=3 * 60)
    except Exception as exc:
        raise RuntimeError('Invalid JWT: %s' % exc)

    # Extract the original email input from the token.
    email_original = payload.get('email_original', payload['email'])

    # Check that we have a valid session
    if email_original != test_email or payload['nonce'] != nonce:
        raise RuntimeError('Invalid session in JWT')


if __name__ == '__main__':
    stats['time'] = time()
    stats['ok'] = False
    try:
        run_test()
        stats['ok'] = True
    except:  # noqa: E722
        print_exc()

    with open(logs_directory + '/stats.jsonl', 'a') as f:
        f.write(json.dumps(stats) + '\n')

    exit(int(not stats['ok']))
