# Troubleshooting

## The iPad is visible, but the connector cannot find it

Run:

```sh
"$HOME/Library/Application Support/ipad-display-connector/tools/list-screen-mirroring-devices"
```

Use the exact name printed by the diagnostic command:

```sh
"$HOME/Library/Application Support/ipad-display-connector/bin/ipad-display-connect" --device "Exact Name Here"
```

If the diagnostic command does not list your iPad, macOS is not exposing it in Screen Mirroring. Wake the iPad, bring it near the Mac, and check Wi-Fi, Bluetooth, Handoff, Apple Account, Personal Hotspot, and Internet Sharing.

## Accessibility automation is disabled

Open:

```text
System Settings > Privacy & Security > Accessibility
```

Enable the app that is launching the connector:

- The generated helper app in `~/Applications`
- Terminal, if running manually
- Automator / Services / Shortcuts, only if macOS prompts for them

Accessibility is a macOS security permission. The connector does not and should not try to toggle it automatically.

## The login item does not run before the login screen

This is expected. Sidecar / Screen Mirroring needs a GUI user session. The connector can run after the user logs in, not at the pre-login screen.

## It says "Unable to connect"

The connector treats this as retryable. It dismisses the dialog, refreshes Control Center, waits, and tries again.

If it still fails after all retries, check:

- Mac and iPad are using the same Apple Account.
- Wi-Fi is on.
- Bluetooth is on.
- Handoff is on.
- Personal Hotspot is off.
- Internet Sharing is off.
- The iPad is awake and unlocked.
- The devices are near each other.

## The keyboard shortcut does nothing

Check these in order:

1. `System Settings > Keyboard > Keyboard Shortcuts > Services`
2. The service named `Connect DEVICE_NAME Display` has a shortcut.
3. The shortcut does not conflict with the foreground app.
4. Accessibility is enabled for the generated helper app in `~/Applications`.

Shortcut sounds:

- `Ping`: the iPad already appears connected.
- `Pop`: the connector is starting because the iPad is not connected.
- `Hero`: connection succeeded.
- `Basso`: connection failed or a permission is missing.

You can always run the same command manually:

```sh
"$HOME/Library/Application Support/ipad-display-connector/bin/ipad-display-connect" --device "Your iPad Name"
```

## Where are logs?

The default log file is:

```text
~/Library/Logs/ipad-display-connector.log
```

The helper app / keyboard shortcut log is:

```text
~/Library/Logs/ipad-display-connector-shortcut.log
```

The log includes:

- Target device name
- Mac-side Wi-Fi power status
- Mac-side Bluetooth status
- Retry attempts
- Whether the target was visible
- Whether macOS reported an unable-to-connect dialog

## The Screen Mirroring menu opens, but no labels are visible to the script

Some macOS versions do not expose device names through normal visible text fields. The connector also checks the Accessibility identifier:

```text
screen-mirroring-device-DEVICE_NAME
```

If this changes in a future macOS release, run the diagnostic tool and open an issue with the output.
