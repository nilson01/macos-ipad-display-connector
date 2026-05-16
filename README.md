# macOS iPad Display Connector

Automate macOS Screen Mirroring / Sidecar so a Mac can connect to an iPad display target at login or from a keyboard shortcut.

This is useful when the built-in display is broken or hard to use and the iPad is the practical display.

## What It Does

- Opens macOS Screen Mirroring through Control Center.
- Finds the configured iPad by its exact display name.
- Presses the matching Screen Mirroring row.
- Detects common "unable to connect" dialogs.
- Dismisses failures, refreshes Control Center, and retries.
- Installs an optional helper login app so the connection starts after login.
- Installs a Quick Action so users can assign a keyboard shortcut.
- Plays distinct sounds for shortcut feedback.
- Includes a diagnostic command to list the devices macOS exposes in Screen Mirroring.

macOS does not provide a supported public command-line API for Sidecar, so this project uses Accessibility UI automation.

## Requirements

- macOS 14 or later is recommended.
- An iPad that supports Sidecar / Screen Mirroring.
- Mac and iPad signed in to the same Apple Account.
- Wi-Fi, Bluetooth, and Handoff enabled.
- iPad awake, nearby, and available in Screen Mirroring.
- Personal Hotspot and Internet Sharing disabled for the connection attempt.

Apple's setup requirements are documented here:

- [Use your iPad as a second display for your Mac](https://support.apple.com/en-us/102597)
- [Mac User Guide: Use your iPad as a second display](https://support.apple.com/guide/mac-help/use-your-ipad-as-a-second-display-mchlf3c6f7ae/mac)

## Quick Start

Clone the repo and run:

```sh
./install.sh --device "Your iPad Name"
```

Example:

```sh
./install.sh --device "My iPad"
```

The installer creates:

- Support files in `~/Library/Application Support/ipad-display-connector`
- A helper app in `~/Applications`
- A Quick Action in `~/Library/Services`

## One-Time macOS Permissions

Open:

```text
System Settings > Privacy & Security > Accessibility
```

Enable the generated helper app:

```text
~/Applications/Connect Your iPad Name Display.app
```

If you run the command manually from Terminal, enable Terminal too.

The Quick Action opens the generated helper app, so the helper app is the main permission target.

## Keyboard Shortcut

After install:

1. Open `System Settings > Keyboard > Keyboard Shortcuts`.
2. Select `Services`.
3. Find `Connect Your iPad Name Display`.
4. Assign any shortcut you want.

For example, you can assign `Command+0` if that does not conflict with the app you are using.

Shortcut sounds:

- `Ping`: the iPad already appears connected.
- `Pop`: the iPad is not connected, so the connector is starting.
- `Hero`: the connector finished successfully.
- `Basso`: the connector failed or needs permission.

## Startup Behavior

The installer adds a small helper app:

```text
~/Applications/Connect Your iPad Name Display.app
```

It appears in:

```text
System Settings > General > Login Items
```

This app runs after the user logs in. It cannot connect the iPad before the macOS login screen because Sidecar requires an active GUI user session.

## Manual Use

After install:

```sh
"$HOME/Library/Application Support/ipad-display-connector/bin/ipad-display-connect" --device "Your iPad Name"
```

Options:

```sh
ipad-display-connect --device "Your iPad Name" \
  --attempts 6 \
  --retry-delay 5 \
  --connect-wait 35 \
  --refresh-control-center
```

## Diagnostics

List the Screen Mirroring devices macOS exposes through Accessibility:

```sh
"$HOME/Library/Application Support/ipad-display-connector/tools/list-screen-mirroring-devices"
```

This is the first thing to run if the connector cannot find the iPad. It prints rows such as:

```text
Screen Mirroring devices:
  [available] My iPad
  [available] Living Room
```

## Failure Recovery

If the iPad is visible but macOS reports that it cannot connect, the connector:

1. Dismisses the error dialog.
2. Reopens Screen Mirroring.
3. Deselects the target if macOS left it stuck as selected.
4. Closes the panel.
5. Refreshes Control Center.
6. Waits and retries.

By default it tries 6 times, waits 5 seconds between attempts, and waits up to 35 seconds for a selected display to stabilize.

The connector does not toggle Accessibility, Wi-Fi, Bluetooth, Handoff, or Apple Account settings. Those are user-controlled system settings. It logs Mac-side Wi-Fi and Bluetooth state at the start of each run to make troubleshooting easier.

## Uninstall

```sh
./uninstall.sh
```

Logs are intentionally left in `~/Library/Logs`.

The connector log is:

```text
~/Library/Logs/ipad-display-connector.log
```

The helper app / keyboard shortcut log is:

```text
~/Library/Logs/ipad-display-connector-shortcut.log
```

## Project Layout

```text
bin/ipad-display-connect                  Command-line runner
lib/connect-ipad-display.applescript      Screen Mirroring UI automation engine
tools/list-screen-mirroring-devices       Diagnostic wrapper
templates/quick-action.workflow           Automator Services template
templates/launch-agent.plist              Optional launchd template
install.sh                                Installer
uninstall.sh                              Uninstaller
docs/TROUBLESHOOTING.md                   Common issues and fixes
```

## Notes For Contributors

This project intentionally stays dependency-free. It uses macOS built-ins: `zsh`, `osascript`, `osacompile`, `plutil`, `launchctl`, and Automator Services.

Screen Mirroring UI internals can change between macOS releases. The most important implementation detail is that device names may be exposed through Accessibility as:

```text
AXIdentifier = screen-mirroring-device-DEVICE_NAME
```

That is why the connector checks `AXIdentifier` rather than only visible text.
