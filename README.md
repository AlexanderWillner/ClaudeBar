# ClaudeBar

[![Build](https://github.com/tddworks/ClaudeBar/actions/workflows/build.yml/badge.svg)](https://github.com/tddworks/ClaudeBar/actions/workflows/build.yml)
[![Tests](https://github.com/tddworks/ClaudeBar/actions/workflows/tests.yml/badge.svg)](https://github.com/tddworks/ClaudeBar/actions/workflows/tests.yml)
[![codecov](https://codecov.io/gh/tddworks/ClaudeBar/graph/badge.svg)](https://codecov.io/gh/tddworks/ClaudeBar)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2015-blue.svg)](https://developer.apple.com)

A macOS menu bar application that monitors AI coding assistant usage quotas. Keep track of your Claude, Codex, and Gemini usage at a glance.

![ClaudeBar Screenshot](docs/Screenshot.png)

## Features

- **Multi-Provider Support** - Monitor Claude, Codex, and Gemini quotas in one place
- **Real-Time Quota Tracking** - View Session, Weekly, and Model-specific usage percentages
- **Visual Status Indicators** - Color-coded progress bars (green/yellow/red) show quota health
- **System Notifications** - Get alerted when quota status changes to warning or critical
- **Auto-Refresh** - Automatically updates quotas at configurable intervals
- **Keyboard Shortcuts** - Quick access with `⌘D` (Dashboard) and `⌘R` (Refresh)

## Quota Status Thresholds

| Remaining | Status | Color |
|-----------|--------|-------|
| > 50% | Healthy | Green |
| 20-50% | Warning | Yellow |
| < 20% | Critical | Red |
| 0% | Depleted | Gray |

## Requirements

- macOS 15+
- Swift 6.2+
- CLI tools installed for providers you want to monitor:
  - [Claude CLI](https://claude.ai/code) (`claude`)
  - [Codex CLI](https://github.com/openai/codex) (`codex`)
  - [Gemini CLI](https://github.com/google-gemini/gemini-cli) (`gemini`)

## Installation

```bash
git clone https://github.com/tddworks/ClaudeBar.git
cd ClaudeBar
swift build -c release
```

## Usage

```bash
swift run ClaudeBar
```

The app will appear in your menu bar. Click to view quota details for each provider.

## Development

```bash
# Build the project
swift build

# Run all tests
swift test

# Run tests with coverage
swift test --enable-code-coverage

# Run a specific test
swift test --filter "QuotaMonitorTests"
```

## Architecture

ClaudeBar follows Clean Architecture with hexagonal/ports-and-adapters patterns:

```
┌─────────────────────────────────────────────────┐
│                   App Layer                     │
│     SwiftUI Views + @Observable AppState        │
└─────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────┐
│                 Domain Layer                    │
│  Models: UsageQuota, UsageSnapshot, QuotaStatus │
│  Ports: UsageProbePort, QuotaObserverPort       │
│  Services: QuotaMonitor (Actor)                 │
└─────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────┐
│              Infrastructure Layer               │
│  CLI Probes: Claude, Codex, Gemini              │
│  PTYCommandRunner, NotificationObserver         │
└─────────────────────────────────────────────────┘
```

### Key Design Decisions

- **Rich Domain Models** - Business logic lives in domain models, not ViewModels
- **Actor-Based Concurrency** - Thread-safe state management with Swift actors
- **Protocol-Driven Testing** - `@Mockable` protocols enable easy test doubles
- **No ViewModel Layer** - SwiftUI views directly consume domain models

## Dependencies

- [Sparkle](https://sparkle-project.org/) - Auto-update framework
- [Mockable](https://github.com/Kolos65/Mockable) - Protocol mocking for tests

## License

MIT
