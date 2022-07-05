#!/usr/bin/env python3

import os
import sys
import shutil
from tempfile import mkstemp
from cgi import FieldStorage


RW_DIR = os.environ.get("UPLOADS_DIR", "/var/www/uploads")  # nginx user should has rw access
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
if "file" not in form.keys():  # get("file") does not work (due to FieldStorage internals)
    _error("Incorrect request")

uploading_file = form["file"]
if hasattr(uploading_file, "filename") and hasattr(uploading_file, "file"):
    fname = uploading_file.filename or "fwupdate"
    fp_upload = uploading_file.file
else:
    _error("Incorrect request body")

uploading_fd, uploading_fname = mkstemp()

with os.fdopen(uploading_fd, "wb") as fp_save:
    for chunk in to_chunks(fp_upload):
        fp_save.write(chunk)
sys.stdout.write("Status: 200\r\n\r\n")

shutil.copyfile(uploading_fname, os.path.join(RW_DIR, fname))
