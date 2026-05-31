# 0001 - Native SwiftUI/TCA App

## Status

Accepted.

## Context

CommenterV3 is currently an offline browser app in `C:\Commenterv3`. The user
wants a new iPhone-first iOS app, starting in a fresh repo, with native SwiftUI,
TCA, reusable components, HIG-style interaction, and OSS scaffolding where it
helps.

The app handles private student data and must not fake save, import, generation,
export, or share states.

## Decision

Build a fresh native SwiftUI/TCA app in `C:\CommenterIOS`.

Use:

- SwiftUI for UI.
- The Composable Architecture for state/effects/tests.
- A small owned design system.
- Local Swift packages for domain, generation, persistence, import/export, and
  test support.
- A TCA-oriented OSS template as a scaffold seed.

Do not use:

- a web wrapper as the production MVP path
- Firebase/auth/paywall starters
- analytics or telemetry scaffolds
- CloudKit or account sync
- generic starter state that pretends persistence works

## OSS Guidance

Use as foundation:

- `pointfreeco/swift-composable-architecture`
- `ethanhuang13/SwiftUI-TCA-Template`

Use as reference only:

- `pointfreeco/isowords`

Use selectively behind owned wrappers:

- `SwiftUIX`
- `SwiftUI Introspect`

Do not let OSS packages define product behavior or visual language.

## Consequences

The native app will port behavior intentionally rather than copy screens
line-for-line.

This raises the up-front work for data parity, generation parity, and
import/export parity, but it reduces long-term risk and gives a real native
iPhone workflow.

