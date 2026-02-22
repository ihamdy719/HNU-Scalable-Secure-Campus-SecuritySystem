import hashlib
import hmac

# =========================================================
# Password Security Utilities (SQL-Compatible)
# =========================================================

def hash_password(password: str) -> bytes:
    """
    Hash password EXACTLY like SQL Server:
    HASHBYTES('SHA2_256', NVARCHAR)
    => UTF-16LE encoding
    """
    if password is None:
        return None

    if not isinstance(password, str):
        raise ValueError("Password must be a string")

    #  MUST be utf-16le to match SQL Server NVARCHAR
    return hashlib.sha256(password.encode("utf-16le")).digest()


def compare_hashes(hash1: bytes, hash2: bytes) -> bool:
    if hash1 is None or hash2 is None:
        return False

    if isinstance(hash1, memoryview):
        hash1 = hash1.tobytes()
    if isinstance(hash2, memoryview):
        hash2 = hash2.tobytes()

    return hmac.compare_digest(hash1, hash2)
