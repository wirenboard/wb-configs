#!/bin/sh
set -eu

url=$(jq -r '.mod4.options.url // "http://localhost"' /etc/wb-hardware.conf 2>/dev/null || true)
[ -z "$url" ] || [ "$url" = "null" ] && url="http://localhost"

ff_mode=$(jq -r '.mod4.options.ff_mode // "kiosk"' /etc/wb-hardware.conf 2>/dev/null || true)
[ -z "$ff_mode" ] || [ "$ff_mode" = "null" ] && ff_mode="kiosk"

PROFILE_NAME="wirenboard"
PROFILE_DIR="/root/.mozilla/firefox/${PROFILE_NAME}"
USER_JS="$PROFILE_DIR/user.js"
XULSTORE="$PROFILE_DIR/xulstore.json"
USER_CHROME_DIR="$PROFILE_DIR/chrome"
USER_CHROME="$USER_CHROME_DIR/userChrome.css"

ensure_profile() {
	if [ -d "$PROFILE_DIR" ]; then
		return
	fi

	firefox-esr --no-remote -CreateProfile "$PROFILE_NAME $PROFILE_DIR"
	for i in $(seq 1 10); do
		[ -d "$PROFILE_DIR" ] && break
		sleep 0.5
	done

	cat <<-'EOF' > "$USER_JS"
	user_pref("browser.sessionstore.resume_from_crash", false);
	user_pref("browser.shell.checkDefaultBrowser", false);
	user_pref("toolkit.startup.max_resumed_crashes", -1);
	user_pref("browser.crashReports.unsubmittedCheck.enabled", false);
	user_pref("datareporting.policy.dataSubmissionEnabled", false);
	user_pref("signon.rememberSignons", false);
	user_pref("signon.autofillForms", false);
	user_pref("signon.autologin.proxy", false);
	EOF
}

ensure_pref() {
	pref_line=$1

	grep -Fqx "$pref_line" "$USER_JS" 2>/dev/null && return
	printf '%s\n' "$pref_line" >> "$USER_JS"
}

apply_browser_layout() {
	mkdir -p "$USER_CHROME_DIR"

	cat <<-'EOF' > "$XULSTORE"
	{"chrome://browser/content/browser.xhtml":{"main-window":{"sizemode":"maximized","screenX":"0","screenY":"0","width":"1024","height":"600"}}}
	EOF

	if [ "$ff_mode" = "window" ]; then
		rm -f "$USER_CHROME"
		return
	fi

	cat <<-'EOF' > "$USER_CHROME"
	#navigator-toolbox,
	#TabsToolbar,
	#titlebar,
	#PersonalToolbar,
	#sidebar-box,
	#sidebar-header {
	  visibility: collapse !important;
	  min-height: 0 !important;
	  max-height: 0 !important;
	}

	#main-window,
	#browser,
	#appcontent,
	#tabbrowser-tabbox,
	#tabbrowser-tabpanels {
	  margin: 0 !important;
	  padding: 0 !important;
	}
	EOF
}

cleanup_profile_state() {
	rm -f "$PROFILE_DIR/.startup-incomplete" 2>/dev/null || true
	rm -f "$PROFILE_DIR/sessionCheckpoints.json" 2>/dev/null || true
	rm -f "$PROFILE_DIR/sessionstore.jsonlz4" "$PROFILE_DIR/sessionstore.js" "$PROFILE_DIR/sessionstore.bak" 2>/dev/null || true
	rm -rf "$PROFILE_DIR/sessionstore-backups" 2>/dev/null || true
	rm -rf "$PROFILE_DIR/crashes" "$PROFILE_DIR/minidumps" 2>/dev/null || true
	rm -f "$PROFILE_DIR/datareporting/aborted-session-ping" 2>/dev/null || true
	rm -rf "$PROFILE_DIR/datareporting/glean/pending_pings" 2>/dev/null || true
	rm -rf "/root/.mozilla/firefox/Crash Reports" 2>/dev/null || true
	rm -rf "/root/.mozilla/firefox/Pending Pings" 2>/dev/null || true
	rm -rf "/root/.mozilla/Crash Reports" 2>/dev/null || true
	rm -rf "/root/.mozilla/Pending Pings" 2>/dev/null || true
	rm -f "$PROFILE_DIR/lock" "$PROFILE_DIR/.parentlock" 2>/dev/null || true
	rm -f "$PROFILE_DIR/Telemetry.ShutdownTime.txt" "$PROFILE_DIR/times.json" 2>/dev/null || true
	rm -f "$PROFILE_DIR/datareporting/session-state.json" "$PROFILE_DIR/datareporting/state.json" 2>/dev/null || true
}

ensure_profile
ensure_pref 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
apply_browser_layout
cleanup_profile_state

exec firefox-esr --no-remote --profile "$PROFILE_DIR" "$url"
