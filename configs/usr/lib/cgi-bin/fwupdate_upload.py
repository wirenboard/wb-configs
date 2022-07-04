#!/usr/bin/env python3

import os
import sys
from cgi import FieldStorage


RW_DIR = os.environ.get("UPLOADS_DIR", "/var/www/uploads")  # nginx user should have rw access
os.makedirs(RW_DIR, exist_ok=True)


def _error(msg=""):
    sys.stdout.write("Status: 400 %s\r\n\r\n" % msg)
    sys.exit(1)


def to_chunks(fp, chunk_size=8192):
    while True:
        bs = fp.read(chunk_size)
        if not bs:
            break
        yield bs


form = FieldStorage(encoding="utf-8")
uploading_file = form.get("file", None)
if not uploading_file:
    _error()

if hasattr(uploading_file, "filename") and hasattr(uploading_file, "file"):
    fname = uploading_file.filename or "fwupdate"
    fp_upload = uploading_file.file
else:
    _error()

with open(os.path.join(RW_DIR, fname), "wb") as fp_save:
    for chunk in to_chunks(fp_upload):
        fp_save.write(chunk)
