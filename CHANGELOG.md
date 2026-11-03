# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-11-03

### Added
- Device list that merges temperature nodes (REST, polled every 30 s) and Modbus gateways (MQTT, live), with problems sorted first.
- Device detail with a 24 h chart for temperature nodes, a live chart and latest values for gateways, and dashed alert limits.
- Local notifications for alert transitions (out of range, not reporting, back to normal), deduplicated by `AlertMonitor`.
- Settings for the API URL, MQTT broker, credentials, base topic, charted metric and gateway alert limit, persisted on the device.
- Unit tests for domain, parsing and REST layers, a widget test with fake repositories, and CI for analyze, test, Android and iOS builds.
