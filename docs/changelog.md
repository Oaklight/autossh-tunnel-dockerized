# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v2.1.0] - 2026-02-03

### Added

- **Config API**: New RESTful API for configuration management (`/config` endpoints)
    - `GET /config` - Get all tunnel configurations
    - `GET /config/<hash>` - Get single tunnel configuration
    - `POST /config` - Replace all configurations
    - `POST /config/new` - Add new tunnel
    - `POST /config/<hash>` - Update single tunnel
    - `DELETE /config/<hash>` - Delete tunnel
    - `POST /config/<hash>/delete` - Delete tunnel (POST alternative)
- **Tunnel Detail Page Config Editing**: Edit tunnel configuration directly from the detail page
- **Per-Row Save Button**: Save individual tunnel configurations without affecting others
- **Localized External Resources**: Material Design CSS/JS and fonts are now served locally
- **Enhanced Status Visualization**: Improved tunnel status display in the detail page
- **Hash Prefix Matching**: Support 8+ character hash prefixes for tunnel identification
- **Refresh Interval Label**: Added refresh interval to auto-refresh label in i18n

### Changed

- **API Modularization**: Refactored `api_server.sh` into separate modules for better maintainability
- **Config API Integration**: Web panel now uses Config API instead of direct file access
- **Optimized Row Updates**: Only update saved row instead of full page refresh

### Fixed

- **Loading Indicator**: Show hourglass loading indicator on main page status column
- **i18n Ready Check**: Check `i18n.isReady` before calling `t()` to prevent showing raw keys
- **Control Buttons**: Re-enable control buttons before replacing them
- **Save Delay**: Increased delay after save to wait for file monitor restart
- **Fast Retry**: Added fast retry for status fetching on initial load
- **Config Save UX**: Improved config save user experience and added request logging
- **Config API Path**: Use `/etc/autossh/config/` as default path
- **JSON Output**: Fixed JSON output and logging issues in config API
- **Tunnel Status**: Fixed internal tunnel status state updates in detail page
- **Status Identification**: Improved tunnel status identification and handling
- **Hash Mapping**: Use hash instead of name for tunnel status mapping

## [v2.0.0] - 2026-01-25

### Added

- **Web Panel**: Full-featured web-based management interface
- **HTTP API**: RESTful API for programmatic tunnel control
- **CLI Tool (autossh-cli)**: Command-line interface for tunnel management
- **Individual Tunnel Control**: Start, stop, and manage each tunnel independently
- **Bearer Token Authentication**: Optional API authentication support
- **Tunnel Direction Modes**: Support for both default (service-oriented) and SSH-standard modes
- **Internationalization**: Multi-language support for web panel
- **Automatic Backup**: Configuration backup before modifications

### Changed

- **Architecture**: Separated web panel into its own container
- **Configuration**: Enhanced YAML configuration with more options

### Fixed

- Various bug fixes and stability improvements

## [v1.0.0] - Initial Release

### Added

- Docker-based SSH tunnel management with autossh
- YAML configuration file support
- Automatic SSH connection maintenance
- Dynamic UID/GID support
- Multi-architecture support
- Automatic reload on configuration changes