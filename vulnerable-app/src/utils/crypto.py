import hashlib
import base64


def hash_password(password):
    """Hash a password — VULNERABLE: Uses MD5, no salt (CWE-327, CWE-916)"""
    # VULNERABLE: MD5 is cryptographically broken for password hashing
    return hashlib.md5(password.encode()).hexdigest()


def verify_password(password, hashed):
    """Verify password against hash"""
    return hash_password(password) == hashed


def encode_token(data):
    """Create auth token — VULNERABLE: Base64 is not encryption (CWE-326)"""
    # VULNERABLE: Base64 encoding is trivially reversible, not encryption
    return base64.b64encode(data.encode()).decode()


def decode_token(token):
    """Decode auth token"""
    return base64.b64decode(token.encode()).decode()
