# Desktop-First Plan

Generated path: `/Users/roman/Developer/iosbrowser/docs/desktop-first-plan.md`

The first implementation milestone is the Electron desktop browser. Desktop work should harden the shared contracts that iOS later consumes.

## Phase 1

Make `apps/desktop` build and run with a secure Electron shell, typed preload bridge, React workspace, and one profile-backed browser tab.

## Phase 2

Add multiple tabs, deterministic profile partitions, profile switching, proxy policy application, and isolation tests.

## Phase 3

Add the AI sidebar with page summarization, permissioned action requests, audit events, and backend sync hooks.

## Phase 4

Package for macOS with signing, notarization, hardened runtime, crash reporting, and Keychain-backed vault integration.

## iOS dependency

iOS starts after shared contracts for profiles, sync, AI permissions, vault references, and subscription entitlement are stable enough to avoid duplicating product logic.
