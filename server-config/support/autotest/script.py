#!/usr/bin/env python3
"""Script that performs a test of a Portier instance.

This code is loosely based on the Relying Party demo code. It fakes a user
agent going through a custom Identity Provider flow.
"""

from base64 import urlsafe_b64decode, urlsafe_b64encode
from os.path import exists
from stat import ST_MTIME
from time import perf_counter, time
from traceback import print_exc
from urllib.parse import parse_qs, urlencode, urlsplit
from uuid import uuid4
import http.client
import json
import os

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.asymmetric.rsa import (
    RSAPublicNumbers, generate_private_key)
from cryptography.hazmat.primitives.hashes import Hash, SHA256
from cryptography.hazmat.primitives.serialization import (
    Encoding, PrivateFormat, NoEncryption, load_pem_private_key)
import jwt

# Read settings from the environment.
broker_origin = os.environ['BROKER_ORIGIN']
test_host = os.environ['TEST_HOST']
state_dir = os.environ['STATE_DIRECTORY']

# Test origin and email address.
test_origin = 'https://' + test_host
test_email = 'autotest@' + test_host

# Private keys of our IdP.
current_key_file = state_dir + '/current_key.pem'
next_key_file = state_dir + '/next_key.pem'

# Public web directory.
public_dir = state_dir + '/public'

# Stats file, and temporary write location.
stats_file = public_dir + '/stats.jsonl'
stats_scratch_file = state_dir + '/.stats.jsonl.scratch'

# How many records to keep in stats file. Assuming we run every 5 minutes, this
# tracks data for 3 days, and should stay <150 KiB.
stats_len = int(3 * 24 * (60/5))

# Stats record written to `stats.jsonl`.
stats = {}


def b64dec(string):
    """Decode unpadded URL-safe base64."""
    padding = '=' * ((4 - len(string) % 4) % 4)
    return urlsafe_b64decode(string + padding)


def b64enc(data):
    """Encode unpadded URL-safe base64."""
    return urlsafe_b64encode(data).replace(b'=', b'').decode('ascii')


def decode_jwk_int(string):
    """Decode a JWK big integer."""
    return int.from_bytes(b64dec(string), 'big')


def encode_jwk_int(value):
    """Encode a JWK big integer."""
    return b64enc(value.to_bytes((value.bit_length() + 7) // 8, 'big'))


def jwk_to_rsa(key):
    """Convert a deserialized JWK into an RSAPublicKey instance."""
    e = decode_jwk_int(key['e'])
    n = decode_jwk_int(key['n'])
    return RSAPublicNumbers(e, n).public_key(default_backend())


def rsa_to_jwk(key):
    """Convert a RSAPrivateKey instance to a JWK structure."""
    numbers = key.public_key().public_numbers()
    return {
        'kid': make_kid(key),
        'alg': 'RS256',
        'use': 'sig',
        'kty': 'RSA',
        'e': encode_jwk_int(numbers.e),
        'n': encode_jwk_int(numbers.n)
    }


def make_kid(key):
    """Create a key ID for an RSAPrivateKey."""
    numbers = key.public_key().public_numbers()
    hasher = Hash(SHA256(), default_backend())
    hasher.update(f'{numbers.e}:{numbers.n}'.encode('ascii'))
    return b64enc(hasher.finalize())


def read_key(filename):
    """Read a private key from a file."""
    with open(filename, 'rb') as f:
        return load_pem_private_key(f.read(), None, default_backend())


def create_key(filename):
    """Generate a new private key, write it to a file, and return it."""
    key = generate_private_key(65537, 2048, default_backend())
    with open(filename, 'wb') as f:
        os.chmod(f.fileno(), 0o600)
        f.write(key.private_bytes(
            Encoding.PEM,
            PrivateFormat.TraditionalOpenSSL,
            NoEncryption(),
        ))
    return key


def request(stat_name, url, data=None):
    """Make a simple HTTP request, with optional form data.

    Bypasses urllib, because we want to parse redirects. Also records timing
    data using `stat_name`.
    """

    parsed = urlsplit(url)

    if parsed.scheme == 'http':
        conn = http.client.HTTPConnection(parsed.netloc)
    elif parsed.scheme == 'https':
        conn = http.client.HTTPSConnection(parsed.netloc)
    else:
        raise RuntimeError(f"Unsupported HTTP scheme: {parsed.scheme}")

    resource = parsed.path
    if parsed.query:
        resource += '?' + parsed.query

    headers = {
        'Host': parsed.netloc,
        'Connection': 'close'
    }
    if data:
        headers['Content-Type'] = 'application/x-www-form-urlencoded'

    start = perf_counter()
    if data:
        conn.request("POST", resource, data, headers)
    else:
        conn.request("GET", resource, None, headers)
    res = conn.getresponse()
    stats[stat_name] = perf_counter() - start

    return res


def run_test(signing_key):
    # Fetch the discovery document.
    url = broker_origin + '/.well-known/openid-configuration'
    with request('discovery', url) as res:
        if res.status != 200:
            raise RuntimeError(f'Unexpected discovery status: {res.status}')

        discovery_data = json.loads(res.read().decode('utf-8'))

    # Start authorization.
    nonce = uuid4().hex
    url = discovery_data['authorization_endpoint'] + '?' + urlencode({
        'login_hint': test_email,
        'scope': 'openid email',
        'nonce': nonce,
        'response_type': 'id_token',
        'client_id': test_origin,
        'redirect_uri': test_origin + '/autotest-verify',
    })
    with request('auth', url) as res:
        if res.status != 303:
            raise RuntimeError(f'Unexpected auth status: {res.status}')

        redirect = res.getheader('Location', '')
        redirect_qs_pos = redirect.find('/autotest-auth?')
        if redirect_qs_pos == -1:
            raise RuntimeError(f'Unexpected auth redirect: {redirect}')

        params = parse_qs(redirect.split('?')[1])

    # Send a token for our IdP back to the broker.
    now = int(time())
    idpt_headers = {
        'kid': make_kid(signing_key)
    }
    idpt_payload = {
        'iss': test_origin,
        'aud': broker_origin,
        'iat': now,
        'exp': now + 60,
        'nonce': params['nonce'][0],
        'email': test_email
    }
    idp_token = jwt.encode(idpt_payload, signing_key, 'RS256', idpt_headers)
    data = urlencode({
        'state': params['state'][0],
        'id_token': idp_token
    }).encode('ascii')
    with request('callback', params['redirect_uri'][0], data) as res:
        if res.status != 303:
            raise RuntimeError(f'Unexpected callback status: {res.status}')

        redirect = res.getheader('Location', '')
        redirect_qs_pos = redirect.find('/autotest-verify#')
        if redirect_qs_pos == -1:
            raise RuntimeError(f'Unexpected callback redirect: {redirect}')

        params = parse_qs(redirect.split('#')[1])
        token = params.get('id_token')
        if token:
            token = token[0]
        else:
            raise RuntimeError(f'No token in callback: {redirect}')

    # Fetch and parse JWKs.
    with request('jwks', discovery_data['jwks_uri']) as res:
        if res.status != 200:
            raise RuntimeError(f'Unexpected jwks status: {res.status}')

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
    payload = jwt.decode(token, pub_key,
                         algorithms=['RS256'],
                         audience=test_origin,
                         issuer=broker_origin,
                         leeway=3 * 60)

    # Extract the original email input from the token.
    email_original = payload.get('email_original', payload['email'])

    # Check that we have a valid session
    if email_original != test_email or payload['nonce'] != nonce:
        raise RuntimeError('Invalid session in JWT')


if __name__ == '__main__':
    # Ensure we have up-to-date private keys for our IdP.
    current_key = None
    next_key = None

    has_current_key = exists(current_key_file) and \
        time() - os.stat(current_key_file)[ST_MTIME] < 86400
    has_next_key = exists(next_key_file)

    if not has_current_key and has_next_key:
        # Rename and update mtime, so the key doesn't expire immediately.
        os.utime(next_key_file)
        os.rename(next_key_file, current_key_file)
        has_current_key = True
        has_next_key = False

    if has_current_key:
        current_key = read_key(current_key_file)
    else:
        current_key = create_key(current_key_file)

    if has_next_key:
        next_key = read_key(next_key_file)
    else:
        next_key = create_key(next_key_file)

    # Prepare the IdP directory structure.
    os.makedirs(public_dir + '/.well-known', exist_ok=True)
    with open(public_dir + '/.well-known/webfinger', 'w') as f:
        f.write(json.dumps({
            'links': [{
                'rel': 'https://portier.io/specs/auth/1.0/idp',
                'href': test_origin
            }]
        }))
    with open(public_dir + '/.well-known/openid-configuration', 'w') as f:
        f.write(json.dumps({
            'authorization_endpoint': test_origin + '/autotest-auth',
            'jwks_uri': test_origin + '/keys.json',
            'response_modes_supported': ['form_post']
        }))
    with open(public_dir + '/keys.json', 'w') as f:
        f.write(json.dumps({
            'keys': [
                rsa_to_jwk(current_key),
                rsa_to_jwk(next_key)
            ]
        }))

    # Run the test.
    stats['time'] = time()
    stats['ok'] = False
    try:
        run_test(current_key)
        stats['ok'] = True
    except:  # noqa: E722
        print_exc()

    # Append the new stats line.
    try:
        with open(stats_file) as f:
            lines = f.readlines()
    except IOError:
        lines = []
    lines.append(json.dumps(stats) + '\n')

    # Truncate and rewrite the stats file.
    with open(stats_scratch_file, 'w') as f:
        f.write(''.join(lines[-stats_len:]))
    os.rename(stats_scratch_file, stats_file)

    exit(int(not stats['ok']))
