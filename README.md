# odyssey

odyssey is a Quickshell desktop shell for Hyprland built around a contextual top-center system surface. It brings everyday controls, information, and workflows into one focused interface.

> Minimal when idle. Informational when needed. Powerful when requested. Intelligent when useful.

> [!NOTE]
> odyssey is currently a **public alpha**. Core functionality is usable today, but features, appearance, configuration, and installation behavior may continue to evolve.

## Your system, your configuration

odyssey is designed to integrate with your system, not take ownership of it.

You remain free to manage your own Hyprland configuration, shell, applications, packages, and system setup. odyssey provides the configuration and integration required for its desktop experience, while keeping user-owned configuration and system management in your control.

The installer supports preserving existing configuration, and files that odyssey needs to modify or replace are backed up before changes are made.

odyssey should be something you can build your setup around — not something that prevents you from making the setup your own.

## Highlights

### A contextual system surface

odyssey's Dynamic Island stays compact at rest and expands contextually as you interact with the system.

It provides access to notifications, media, workspaces, device status, system controls, and focused OSD feedback for volume, microphone, brightness, and power changes without permanently occupying additional screen space.

<img width="1280" height="720" alt="overview" src="https://github.com/user-attachments/assets/4e345f7e-493a-454d-a7df-b100ffbcaf7d" />

### Dashboard and insights

The expanded Dashboard brings together time, weather, calendar, recent notifications, media, quick controls, and system information in one view.

Weather is unconfigured by default. Set your location under **Settings → Dashboard** to enable current conditions and forecasts.

<img width="1280" height="720" alt="insight1" src="https://github.com/user-attachments/assets/0e6b67c2-d6c9-476f-97b5-847cc4a05296" />

### Launcher and command palette

Search and launch applications, switch Hyprland workspaces, or execute odyssey actions from a keyboard-friendly launcher and command palette.

<img width="1280" height="720" alt="launcher" src="https://github.com/user-attachments/assets/471655d0-56fb-40ec-a13d-6db0b48d460d" />

### Control Center

Manage common desktop controls without leaving the shell, including:

- volume and microphone
- display brightness
- Wi-Fi and network information
- Bluetooth
- battery status
- power profiles
- do-not-disturb

<img width="1280" height="720" alt="control" src="https://github.com/user-attachments/assets/6eee267d-a357-4bcb-a387-5c6f3982df56" />

### Notifications and media

odyssey provides its own notification service with contextual previews and notification history.

Active media is integrated directly into the island and Dashboard, providing playback information and controls without requiring a separate widget or panel.

<img width="1280" height="720" alt="notify" src="https://github.com/user-attachments/assets/5f120182-01d5-4802-85c0-7b34e173f7d2" />

### Wallpapers and adaptive theming

Browse and apply wallpapers per monitor directly from odyssey.

odyssey uses **Matugen** to generate an adaptive color palette from your wallpaper and propagate it throughout the shell and supported desktop integrations for a cohesive appearance.

<img width="1280" height="720" alt="wallpaper" src="https://github.com/user-attachments/assets/2647efb7-75a2-4f13-9135-6187a74872f9" />

## Features

odyssey currently includes:

- contextual Dynamic Island and system OSDs
- application launcher and command palette
- Hyprland workspace integration
- Dashboard and system insights
- notification service and notification history
- media playback controls
- Wi-Fi and network controls
- Bluetooth controls
- audio and microphone controls
- brightness and power controls
- weather and forecasts
- calendar views
- wallpaper management
- Matugen-powered adaptive theming
- system monitoring
- configurable odyssey settings
- stable IPC commands for scripting and custom keybindings
- optional matching SDDM theme

## Installation

odyssey currently targets **Arch Linux with Hyprland and Quickshell**.

Clone the repository and run the guided installer:

```bash
git clone https://github.com/sud0-L/odyssey.git
cd odyssey
./install.sh
```

The installer checks required dependencies, prepares the odyssey runtime, configures startup integration, installs odyssey's managed configuration, and creates backups before replacing existing files.

### Managed vs. preserve configuration

> [!IMPORTANT]
> odyssey is opinionated about desktop configuration. The default **managed** installation deploys odyssey's packaged configuration for supported components.

Managed mode may replace odyssey-managed configuration for components such as:

- Hyprland
- Hypridle
- Kitty
- Starship
- Fastfetch

Existing files are backed up before odyssey replaces or modifies them.

Zsh and Oh My Zsh are an optional enhancement. Interactive installs offer an
explicit opt-in; non-interactive `--yes` installs do not enable it. To opt in
non-interactively, use `./install.sh --yes --with-zsh`. Bash, Fish, and other
login shells do not require Zsh.

If you already have a configured Hyprland environment and want to retain your existing desktop configuration, choose **preserve configuration** in the guided installer or run:

```bash
./install.sh --preserve-config
```

Preserve mode keeps your existing configuration wherever possible while adding the integration required to run odyssey.

## IPC and custom keybindings

odyssey exposes a stable IPC interface for shell actions.

For example:

```bash
odyssey ipc launcher toggle
odyssey ipc control-center toggle
odyssey ipc audio increment 3
odyssey ipc audio decrement 3
odyssey ipc audio mute
odyssey ipc audio micmute
```

These commands can be used from Hyprland keybindings, scripts, or other desktop integrations.

odyssey resolves its active runtime internally, so custom bindings do not need to reference versioned release directories or internal Quickshell paths.

## Things to know

### Notifications

odyssey provides its own freedesktop notification service. Running another notification daemon at the same time may cause conflicts.

### Configuration backups

Before modifying existing user-owned configuration, odyssey creates backups under:

```text
~/.local/state/odyssey/backups/
```

Keep these backups while evaluating the alpha, particularly if you install using managed configuration.

### Weather

Weather is intentionally unconfigured on a fresh installation. Configure your location from **Settings → Dashboard** after odyssey is running.

## CLI & Lifecycle Management

odyssey includes a lifecycle manager for inspecting, maintaining, repairing, and updating an installation.

### Common commands

| Command | Description |
| --- | --- |
| `odyssey status` | Reports installation, activation, launcher, service, and runtime state without making changes. |
| `odyssey doctor` | Diagnoses lifecycle and service problems and suggests remediation without making changes. |
| `odyssey repair` | Repairs odyssey-owned operational state without resetting user configuration. |
| `odyssey config reset` | Backs up odyssey-managed configuration and restores the packaged defaults. |
| `odyssey update` | Updates odyssey using a verified release artifact or configured release source. |
| `odyssey rollback` | Reactivates the previous known-good release when one is available. |
| `odyssey version` | Shows the lifecycle manager version and source identity. |
| `odyssey dependencies` | Checks required packages and runtime dependencies, including Quickshell health. |
| `odyssey preflight` | Performs a read-only inspection of the platform, paths, dependencies, and release payload. |

### Diagnose an installation

```bash
odyssey status
odyssey doctor
```

Both commands are read-only and can be used to inspect an installation without changing anything.

### Repair an installation

```bash
odyssey repair
```

`repair` restores odyssey-owned operational and lifecycle state for the currently installed release.

This includes activation links, the odyssey launcher, interrupted lifecycle operations, systemd units, services, and startup integration.

**Repair does not reset preserved user configuration.**

Changes require confirmation before they are applied.

### Reset odyssey configuration

```bash
odyssey config reset
```

`config reset` is intentionally separate from `repair`.

It backs up existing odyssey-managed configuration and restores the packaged defaults for the currently installed release. The installed release itself is not replaced.

Use this when you intentionally want to return odyssey's configuration to its default state.

Changes require confirmation before configuration is replaced.

### Update odyssey

```bash
odyssey update
```

The update lifecycle validates the candidate release and runtime dependencies before activation, activates the shell and lifecycle manager together, reconciles services, and retains the previous known-good release for rollback.

> [!NOTE]
> Automatic remote release discovery is not currently configured. Updates from supplied verified release artifacts are supported. Automatic updates will become available once a release source is configured.

### Roll back

```bash
odyssey rollback
```

When a previous known-good release is available, odyssey can reactivate it using the existing lifecycle and activation infrastructure.

### Advanced lifecycle commands

Additional commands are primarily intended for installation, development, recovery, or advanced management:

| Command | Purpose |
| --- | --- |
| `odyssey artifact` | Builds or verifies `.ody` release artifacts. |
| `odyssey bootstrap` | Performs initial installation or converges an installation to a supplied release artifact. |
| `odyssey install` | Installs a verified release artifact. Automatic remote installation requires a configured release source. |
| `odyssey uninstall` | Removes odyssey-owned lifecycle payload and startup integration while preserving user data. |
| `odyssey cleanup` | Removes completed lifecycle-operation journals while retaining releases and user data. |

The `backup`, `restore`, `startup`, and `component` commands are currently reserved and are not exposed as functional public workflows.

### Existing Hyprland configurations

If you have a heavily customized Hyprland setup, **preserve configuration is recommended for your first installation**.

You can then integrate odyssey into your existing environment without replacing the rest of your desktop configuration.

## Requirements

- Arch Linux
- Hyprland
- Quickshell
- systemd

Supported required dependencies are detected and installed by the odyssey installer. Optional enhancements are handled separately during guided installation when available.

## Optional SDDM Theme

odyssey includes a matching SDDM theme under `sddm/`.

The SDDM theme is intentionally not installed automatically. Review and install it separately if you want a consistent odyssey login experience.

## Issues and feedback

odyssey is under active development and feedback during the public alpha is welcome.

When reporting an issue, please include:

- a description of the problem
- steps to reproduce it
- relevant terminal or journal output
- your Hyprland version
- your Quickshell version
- whether odyssey was installed using managed or preserve configuration

## Status

odyssey is a **public alpha**.

The core desktop experience is functional, but some areas remain under active development and features or configuration may change between releases.

Expect occasional rough edges while the project matures.

## License

odyssey is licensed under the [GNU General Public License v3.0](LICENSE).
