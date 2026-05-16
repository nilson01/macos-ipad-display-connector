#!/bin/zsh
emulate -L zsh
set -euo pipefail

INSTALL_DIR="${IPAD_DISPLAY_INSTALL_DIR:-$HOME/Library/Application Support/ipad-display-connector}"
SERVICE_DIR="$HOME/Library/Services"
APP_DIR="$HOME/Applications"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/io.github.ipad-display-connector.plist"

remove_login_items_for_app() {
	local app_path="$1"
	local escaped_app_path
	escaped_app_path="${app_path//\\/\\\\}"
	escaped_app_path="${escaped_app_path//\"/\\\"}"
	/usr/bin/osascript <<OSA 2>/dev/null || true
tell application "System Events"
	repeat with loginItem in login items
		try
			if path of loginItem is "$escaped_app_path" then delete loginItem
		end try
	end repeat
end tell
OSA
}

if [[ -f "$LAUNCH_AGENT" ]]; then
	/bin/launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
	/bin/rm -f "$LAUNCH_AGENT"
fi

if [[ -d "$APP_DIR" ]]; then
	for app_path in "$APP_DIR"/Connect\ *\ Display.app(N); do
		bundle_id="$(/usr/bin/plutil -extract CFBundleIdentifier raw "$app_path/Contents/Info.plist" 2>/dev/null || true)"
		if [[ "$bundle_id" == io.github.ipad-display-connector.launcher* ]]; then
			remove_login_items_for_app "$app_path"
			/bin/rm -rf "$app_path"
		fi
	done
fi

if [[ -d "$SERVICE_DIR" ]]; then
	for service_path in "$SERVICE_DIR"/Connect\ *\ Display.workflow(N); do
		bundle_id="$(/usr/bin/plutil -extract CFBundleIdentifier raw "$service_path/Contents/Info.plist" 2>/dev/null || true)"
		if [[ "$bundle_id" == "io.github.ipad-display-connector.service" ]]; then
			/bin/rm -rf "$service_path"
		fi
	done
	/usr/bin/killall pbs 2>/dev/null || true
fi

if [[ -d "$INSTALL_DIR" ]]; then
	/bin/rm -rf "$INSTALL_DIR"
fi

/usr/bin/printf 'Removed iPad Display Connector files.\n'
/usr/bin/printf 'Logs are left in ~/Library/Logs so you can inspect old runs.\n'
