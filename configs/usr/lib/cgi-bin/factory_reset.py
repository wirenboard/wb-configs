#!/usr/bin/env python3

import os
import sys
from cgi import FieldStorage


def _error(msg=""):
    sys.stdout.write("Status: 400 Bad Request\r\n\r\nBad Request: %s" % msg)
    sys.exit(1)


def _die(msg=""):
    sys.stdout.write("Status: 500 Internal Server Error\r\n\r\nInternal Server Error: %s" % msg)
    sys.exit(1)


def to_chunks(fp, chunk_size=8192):
    while True:
        bs = fp.read(chunk_size)
        if not bs:
            break
        yield bs


def main():
    if os.path.islink("/var/run/wb-watch-update.dir"):
        RW_DIR = os.path.realpath("/var/run/wb-watch-update.dir")
    else:
        RW_DIR = os.environ.get("UPLOADS_DIR", "/var/www/uploads")  # nginx user should has rw access

    TMP_DIR = os.path.join(RW_DIR, "state", "tmp")  # excluded from wb-watch-update
    os.makedirs(TMP_DIR, exist_ok=True)

    form = FieldStorage(encoding="utf-8")
    do_factory_reset = "factory_reset" in form.keys() and str(form.getvalue("factory_reset")) == 'true'
    if not do_factory_reset:
        _error("no factory_reset=true in POST arguments")

    # we need to update-with-reboot in order to factory reset, so we're changing output directory to .wb_update
    RW_DIR = "/mnt/data/.wb-update/"
    os.makedirs(RW_DIR, exist_ok=True)
    # create flags file
    flags_file = os.path.join(RW_DIR, 'install_update.web.flags')
    with open(flags_file, "w") as flags_file_h:
        flags_file_h.write('--factoryreset ')

    # copy factoryreset.fit to RW_DIR
    fname = "webupd.fit"
    with open("/mnt/data/.wb-restore/factoryreset.fit", "rb") as fp_upload:
        with open(os.path.join(RW_DIR, fname), "wb") as fp_save:  # wb-watch-update triggers on fd close
            for chunk in to_chunks(fp_upload):
                fp_save.write(chunk)
    sys.stdout.write("Status: 200\r\n\r\n")


try:
    main()
except Exception as e:
    _die(str(e))
