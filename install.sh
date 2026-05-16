#!/bin/zsh
emulate -L zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
INSTALL_DIR_DEFAULT="$HOME/Library/Application Support/ipad-display-connector"
LOG_DIR_DEFAULT="$HOME/Library/Logs"
APP_DIR_DEFAULT="$HOME/Applications"
SERVICE_DIR_DEFAULT="$HOME/Library/Services"

device_name=""
attempts="6"
retry_delay="5"
connect_wait="35"
install_login_item="1"
install_quick_action="1"
install_launch_agent="0"
install_dir="$INSTALL_DIR_DEFAULT"
log_dir="$LOG_DIR_DEFAULT"

usage() {
	/usr/bin/printf '%s\n' \
		"Usage: ./install.sh --device DEVICE_NAME [options]" \
		"" \
		"Options:" \
		"  --device NAME          Exact iPad or Sidecar display name." \
		"  --attempts N           Retry count for startup and Quick Action. Default: 6" \
		"  --retry-delay SECONDS  Delay between retries. Default: 5" \
		"  --connect-wait SECONDS Wait for selected display to stabilize. Default: 35" \
		"  --no-login-item        Do not install the login app." \
		"  --no-quick-action      Do not install the keyboard-bindable Quick Action." \
		"  --with-launch-agent    Also install and load a launchd job. Login app is preferred." \
		"  --install-dir PATH     Install support files here." \
		"  -h, --help             Show this help."
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--device)
			[[ $# -ge 2 ]] || { /usr/bin/printf 'Missing value for --device.\n' >&2; exit 64; }
			device_name="$2"
			shift 2
			;;
		--attempts)
			[[ $# -ge 2 ]] || { /usr/bin/printf 'Missing value for --attempts.\n' >&2; exit 64; }
			attempts="$2"
			shift 2
			;;
		--retry-delay)
			[[ $# -ge 2 ]] || { /usr/bin/printf 'Missing value for --retry-delay.\n' >&2; exit 64; }
			retry_delay="$2"
			shift 2
			;;
		--connect-wait)
			[[ $# -ge 2 ]] || { /usr/bin/printf 'Missing value for --connect-wait.\n' >&2; exit 64; }
			connect_wait="$2"
			shift 2
			;;
		--no-login-item)
			install_login_item="0"
			shift
			;;
		--no-quick-action)
			install_quick_action="0"
			shift
			;;
		--with-launch-agent)
			install_launch_agent="1"
			shift
			;;
		--install-dir)
			[[ $# -ge 2 ]] || { /usr/bin/printf 'Missing value for --install-dir.\n' >&2; exit 64; }
			install_dir="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			/usr/bin/printf 'Unknown option: %s\n' "$1" >&2
			usage >&2
			exit 64
			;;
	esac
done

if [[ -z "$device_name" ]]; then
	/usr/bin/printf 'Enter the exact iPad display name: '
	read -r device_name
fi

if [[ -z "$device_name" ]]; then
	/usr/bin/printf 'A device name is required.\n' >&2
	exit 64
fi

case "$attempts$retry_delay$connect_wait" in
	*[!0-9]*)
		/usr/bin/printf 'Attempts, retry delay, and connect wait must be numeric.\n' >&2
		exit 64
		;;
esac

sanitize_name() {
	/usr/bin/printf '%s' "$1" | /usr/bin/tr '/:' '__'
}

safe_identifier() {
	/usr/bin/printf '%s' "$1" \
		| /usr/bin/tr '[:upper:]' '[:lower:]' \
		| /usr/bin/tr -cs '[:alnum:]' '-' \
		| /usr/bin/sed 's/^-//; s/-$//'
}

shell_quote() {
	/usr/bin/printf '%s' "$1" | /usr/bin/sed "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/"
}

applescript_escape() {
	local value="$1"
	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	/usr/bin/printf '%s' "$value"
}

copy_support_files() {
	/bin/mkdir -p "$install_dir/bin" "$install_dir/lib" "$install_dir/tools" "$log_dir"
	/usr/bin/install -m 755 "$PROJECT_DIR/bin/ipad-display-connect" "$install_dir/bin/ipad-display-connect"
	/usr/bin/install -m 644 "$PROJECT_DIR/lib/connect-ipad-display.applescript" "$install_dir/lib/connect-ipad-display.applescript"
	/usr/bin/install -m 755 "$PROJECT_DIR/tools/list-screen-mirroring-devices" "$install_dir/tools/list-screen-mirroring-devices"
	/usr/bin/install -m 644 "$PROJECT_DIR/tools/list-screen-mirroring-devices.applescript" "$install_dir/tools/list-screen-mirroring-devices.applescript"
}

compile_login_app() {
	local safe_device app_name app_path launcher_source launcher_bundle_id escaped_script_path escaped_device
	safe_device="$(sanitize_name "$device_name")"
	app_name="Connect ${safe_device} Display"
	app_path="$APP_DIR_DEFAULT/${app_name}.app"
	launcher_bundle_id="$(safe_identifier "$device_name")"
	if [[ -z "$launcher_bundle_id" ]]; then
		launcher_bundle_id="ipad"
	fi
	launcher_bundle_id="io.github.ipad-display-connector.launcher.$launcher_bundle_id"
	launcher_source="$(/usr/bin/mktemp -t ipad-display-launcher.XXXXXX.applescript)"
	escaped_script_path="$(applescript_escape "$install_dir/lib/connect-ipad-display.applescript")"
	escaped_device="$(applescript_escape "$device_name")"
	
	/bin/mkdir -p "$APP_DIR_DEFAULT"
	/bin/rm -rf "$app_path"
	/bin/cat > "$launcher_source" <<OSA
on run
	set scriptPath to POSIX file "$escaped_script_path"
	set displayScript to load script scriptPath
	run script displayScript with parameters {"$escaped_device", "$attempts", "$retry_delay", "1", "$connect_wait"}
end run
OSA
	/usr/bin/osacompile -o "$app_path" "$launcher_source" >/dev/null 2>&1
	/bin/rm -f "$launcher_source"
	/usr/bin/plutil -replace CFBundleIdentifier -string "$launcher_bundle_id" "$app_path/Contents/Info.plist"
	/usr/bin/plutil -replace CFBundleName -string "$app_name" "$app_path/Contents/Info.plist"
	/usr/bin/plutil -replace LSUIElement -bool true "$app_path/Contents/Info.plist"
	/usr/bin/printf '%s\n' "$app_path"
}

add_login_item() {
	local app_path="$1"
	local app_name="${app_path:t:r}"
	local escaped_app_path escaped_app_name
	escaped_app_path="$(applescript_escape "$app_path")"
	escaped_app_name="$(applescript_escape "$app_name")"
	
	if ! /usr/bin/osascript >/dev/null <<OSA
tell application "System Events"
	repeat with itemIndex from (count of login items) to 1 by -1
		try
			set loginItem to item itemIndex of login items
			if name of loginItem is "$escaped_app_name" then delete loginItem
		end try
	end repeat
	make login item at end with properties {path:"$escaped_app_path", hidden:false}
end tell
OSA
	then
		/usr/bin/printf 'Could not register the login item automatically.\n' >&2
		/usr/bin/printf 'Add this app manually in System Settings > General > Login Items:\n  %s\n' "$app_path" >&2
	fi
}

install_quick_action_workflow() {
	local safe_device service_name service_path command_string
	safe_device="$(sanitize_name "$device_name")"
	service_name="Connect ${safe_device} Display"
	service_path="$SERVICE_DIR_DEFAULT/${service_name}.workflow"
	command_string="$(shell_quote "$install_dir/bin/ipad-display-connect") --device $(shell_quote "$device_name") --attempts "$attempts" --retry-delay "$retry_delay" --connect-wait "$connect_wait" --refresh-control-center"
	
	/bin/mkdir -p "$SERVICE_DIR_DEFAULT"
	/bin/rm -rf "$service_path"
	/bin/cp -R "$PROJECT_DIR/templates/quick-action.workflow" "$service_path"
	/usr/bin/plutil -replace CFBundleName -string "$service_name" "$service_path/Contents/Info.plist"
	/usr/bin/plutil -replace NSServices.0.NSMenuItem.default -string "$service_name" "$service_path/Contents/Info.plist"
	/usr/bin/plutil -replace actions.0.action.ActionParameters.COMMAND_STRING -string "$command_string" "$service_path/Contents/Resources/document.wflow"
	/bin/chmod -R u+rwX,go-rwx "$service_path"
	/usr/bin/killall pbs 2>/dev/null || true
	/usr/bin/printf '%s\n' "$service_path"
}

install_optional_launch_agent() {
	local plist_path command_bin
	plist_path="$HOME/Library/LaunchAgents/io.github.ipad-display-connector.plist"
	command_bin="$install_dir/bin/ipad-display-connect"
	/bin/mkdir -p "$HOME/Library/LaunchAgents" "$log_dir"
	/bin/cp "$PROJECT_DIR/templates/launch-agent.plist" "$plist_path"
	/usr/bin/plutil -replace ProgramArguments.0 -string "$command_bin" "$plist_path"
	/usr/bin/plutil -replace ProgramArguments.2 -string "$device_name" "$plist_path"
	/usr/bin/plutil -replace ProgramArguments.4 -string "$attempts" "$plist_path"
	/usr/bin/plutil -replace ProgramArguments.6 -string "$retry_delay" "$plist_path"
	/usr/bin/plutil -replace ProgramArguments.8 -string "$connect_wait" "$plist_path"
	/usr/bin/plutil -replace RunAtLoad -bool true "$plist_path"
	/usr/bin/plutil -replace StandardOutPath -string "$log_dir/ipad-display-connector.launchd.out.log" "$plist_path"
	/usr/bin/plutil -replace StandardErrorPath -string "$log_dir/ipad-display-connector.launchd.err.log" "$plist_path"
	/bin/launchctl unload "$plist_path" 2>/dev/null || true
	/bin/launchctl load "$plist_path"
	/usr/bin/printf '%s\n' "$plist_path"
}

copy_support_files

login_app_path=""
if [[ "$install_login_item" == "1" ]]; then
	login_app_path="$(compile_login_app)"
	add_login_item "$login_app_path"
fi

quick_action_path=""
if [[ "$install_quick_action" == "1" ]]; then
	quick_action_path="$(install_quick_action_workflow)"
fi

launch_agent_path=""
if [[ "$install_launch_agent" == "1" ]]; then
	launch_agent_path="$(install_optional_launch_agent)"
fi

/usr/bin/printf '\nInstalled iPad Display Connector.\n'
/usr/bin/printf 'Support files: %s\n' "$install_dir"
/usr/bin/printf 'Log file: %s\n' "$log_dir/ipad-display-connector.log"
[[ -n "$login_app_path" ]] && /usr/bin/printf 'Login app: %s\n' "$login_app_path"
[[ -n "$quick_action_path" ]] && /usr/bin/printf 'Quick Action: %s\n' "$quick_action_path"
[[ -n "$launch_agent_path" ]] && /usr/bin/printf 'LaunchAgent: %s\n' "$launch_agent_path"

/usr/bin/printf '\nNext steps:\n'
if [[ -n "$login_app_path" ]]; then
	/usr/bin/printf '1. Enable Accessibility for this login app:\n   %s\n' "$login_app_path"
else
	/usr/bin/printf '1. Enable Accessibility for the app that will run ipad-display-connect.\n'
fi
if [[ -n "$quick_action_path" ]]; then
	/usr/bin/printf '2. Set a keyboard shortcut in System Settings > Keyboard > Keyboard Shortcuts > Services > %s.\n' "${quick_action_path:t:r}"
else
	/usr/bin/printf '2. Run manually with: %s --device %s\n' "$(shell_quote "$install_dir/bin/ipad-display-connect")" "$(shell_quote "$device_name")"
fi
/usr/bin/printf '3. Test device discovery with:\n   %s\n' "$(shell_quote "$install_dir/tools/list-screen-mirroring-devices")"
/usr/bin/printf '4. Test connection with:\n   %s --device %s\n' "$(shell_quote "$install_dir/bin/ipad-display-connect")" "$(shell_quote "$device_name")"
