# This is Wiren Board vendor script. If you want to override anything,
# add more files in this directory. This file may be replaced automatically on update.
#
# DO NOT EDIT THIS FILE!

# To provide compatibility with old (pre-ModemManager) wb-gsm scenarios, we need to guess,
# is wb-gsm launched from interactive session (WBGSM_INTERACTIVE is set) or system scripts.

WBGSM_INTERACTIVE=1  # Mind naming! (should not start from WB_ to prevent wb-env conflicts)
export WBGSM_INTERACTIVE
