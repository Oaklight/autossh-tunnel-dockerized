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
- **autossh Container Config Mount**: Changed from read-only (`ro`) to read-write (`rw`) to support Config API writes
- **Web Panel Simplified**: Removed config volume mount and PUID/PGID environment variables - all config operations now go through Config API

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

## [v2.0.0] - 2026-01-30

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

- **Architecture**: Separated web panel into its own container with API-driven design
- **Configuration**: Enhanced YAML configuration with more options
- **Documentation**: Moved docs to dedicated worktrees (docs_en, docs_zh)

### Fixed

- Various bug fixes and stability improvements

## [v1.6.2] - 2025-07-23

### Added

- **Material UI**: Integrated Material Design styles and components for modern UI
- **Data Table**: Material data table with input validation and animated feedback
- **SSH Config Guide**: Comprehensive SSH config usage documentation

### Changed

- **UI Styling**: Center aligned text in table cells and inputs

## [v1.6.1] - 2025-06-22

### Changed

- **Docker Base Image**: Updated Alpine base image version
- **Dockerfile.web**: Updated base image for web panel

### Fixed

- Documentation updates for README (English and Chinese)

## [v1.6.0-fix] - 2025-03-04

### Fixed

- **SSH Tunnel Configuration**: Adjusted SSH tunnel configuration in start_autossh.sh
- **Logging**: Improved logging output
- **Backup Permissions**: Fixed backup folder permission issues
- **Typos**: Minor typo fixes

## [v1.6.0] - 2025-02-12

### Added

- **Web Panel**: Initial web-based configuration interface (migrated from webpanel-golang)

### Changed

- **Version Numbering**: Updated to match version number tradition
- **Permissions**: Use PGID and PUID to fix permission issues

### Fixed

- README redirection issues

## [v1.5.0] - 2025-02-12

### Added

- **Config File Monitor**: Background monitoring of config file changes
- **Auto Reload**: Automatic service reload when configuration changes

## [v1.4.0] - 2025-02-03

### Added

- **Forward Tunneling**: Support for forwarding tunnels to remote host (local_to_remote direction)

## [v1.3.0] - 2025-01-13

### Changed

- **Remote Port Parsing**: Enhanced start_autossh.sh to parse complex remote_port configurations (ip:port format)
- **Makefile**: Added build-test target for local testing

## [v1.2.0] - 2025-01-09

### Added

- **Multi-architecture Support**: Build and push Docker images for multiple architectures (amd64, arm64, arm/v7, arm/v6, 386, ppc64le, s390x, riscv64)
- **Makefile**: Added Makefile for multi-arch Docker image build and push
- **PUID/PGID Environment Variables**: Dynamic user/group ID matching with host

### Changed

- **Entrypoint**: Improved entrypoint.sh for user and group ID matching
- **Non-root User**: Container runs as non-root user (myuser)

### Removed

- Custom Dockerfile and compose file (consolidated into main files)

## [v1.1.1] - 2024-12-29

### Changed

- **Environment Variables**: Renamed to HOST_UID/GID in docs and configs

### Fixed

- **User Creation**: Only create new myuser when provided uid/gid differ from 1000

## [v1.1.0] - 2024-12-28

### Added

- **Custom Dockerfile**: Added custom Dockerfile and compose files for UID/GID matching
- **Auto Restart**: Container auto-restart on failure
- **License**: Added MIT License

## [v1.0.0] - 2024-11-14

### Added

- **Initial Release**: Dockerized SSH tunnel manager with autossh
- **YAML Configuration**: Define multiple SSH tunnel mappings using config.yaml
- **Automatic SSH Maintenance**: autossh keeps tunnels alive
- **Docker Compose**: Easy deployment with docker-compose