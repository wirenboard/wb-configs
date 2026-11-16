#!/bin/bash

# dpkg unpacks a new version of a symlinked conffile next to the symlink
# (/etc/X.dpkg-new), but on configure looks for it next to the symlink target
# (/mnt/data/etc/X.dpkg-new), so the update is silently skipped.

# Usage:
#   fix_dpkg_symlinks.sh           move .dpkg-new to the target (dpkg post-invoke hook, unpack only)
#   fix_dpkg_symlinks.sh cleanup   remove orphaned .dpkg-new left by previous upgrades,
#                                  relocate ones of packages still waiting for configure

MNT=/mnt/data

mode=${1:-relocate}
[[ "$mode" == "relocate" && "$DPKG_HOOK_ACTION" != "unpack" ]] && exit 0

pending()
{
    local owner

    owner=$(dpkg-query -S "$1" 2>/dev/null | grep -v '^diversion ' | head -n1)
    owner=${owner%%: *}
    owner=${owner%%, *}

    [[ -n "$owner" ]] || return 1

    case "$(dpkg-query -W -f '${db:Status-Status}' "$owner" 2>/dev/null)" in
        unpacked|half-configured) return 0 ;;
    esac

    return 1
}

find /etc -xdev -type f -name '*.dpkg-new' -print0 | while IFS= read -r -d '' new; do

    conf=${new%.dpkg-new}

    [[ -L "$conf" ]] || continue
    target=$(readlink -f "$conf") || continue
    [[ "$target" == "$MNT"/* && -f "$target" ]] || continue

    if [[ "$mode" == "cleanup" ]] && ! pending "$conf"; then
        echo "Removing orphaned $new"
        rm -f "$new"
    else
        mv -f "$new" "$target.dpkg-new"
    fi

done

exit 0
