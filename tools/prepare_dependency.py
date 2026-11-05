#!/usr/bin/env python3
# Copyright 2026 Lofrano Tecnologia. MIT license.
"""Fetch one explicitly pinned, hash-verified dependency; never execute it here."""
import hashlib
import os
from pathlib import Path
import sys
import tempfile
import urllib.request

URL = "https://dkolf.de/dkjson-lua/dkjson-2.11.lua"
SHA256 = "197cb50834c642f84b4cf99fe724932c50e6d9c92faec7ad89aa25e91df4d481"
MAX_BYTES = 524288
DEST = Path(__file__).resolve().parent.parent / "build/dependencies"


def verified(data):
    return len(data) <= MAX_BYTES and hashlib.sha256(data).hexdigest() == SHA256


def main():
    if len(sys.argv) != 1:
        raise ValueError("arguments")
    if DEST.is_symlink():
        raise ValueError("dependency directory")
    if DEST.parent.is_symlink():
        raise ValueError("build directory")
    DEST.parent.mkdir(mode=0o755, exist_ok=True)
    DEST.mkdir(mode=0o755, exist_ok=True)
    target = DEST / "dkjson.lua"
    if target.is_symlink():
        raise ValueError("dependency file")
    if target.exists():
        with target.open("rb") as stream:
            existing = stream.read(MAX_BYTES + 1)
        if not verified(existing):
            raise ValueError("existing dependency hash")
        print("dkjson 2.11: verified local source")
        return
    request = urllib.request.Request(URL, headers={"User-Agent": "byte-corpus-suffix-index/0.1.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        if not response.geturl().startswith("https://"):
            raise ValueError("transport")
        source = response.read(MAX_BYTES + 1)
    if not verified(source):
        raise ValueError("download hash")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=DEST, prefix="dkjson-", suffix=".tmp", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(source)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, target)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    print("dkjson 2.11: verified source installed in build/dependencies")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, urllib.error.URLError):
        print("dependency preparation failed; no unverified source accepted", file=sys.stderr)
        sys.exit(1)
