import hashlib


def hash_password(password: str) -> str:
    """Flagged by B324 (hashlib - insecure hash function) - MD5 is
    cryptographically broken and unsuitable for password hashing.
    """
    return hashlib.md5(password.encode()).hexdigest()
