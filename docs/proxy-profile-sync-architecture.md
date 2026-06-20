# Proxy, Profile, And Sync Architecture

Generated path: `/Users/roman/Developer/iosbrowser/docs/proxy-profile-sync-architecture.md`

Desktop profile isolation uses Electron persistent partitions named from profile IDs. Each profile owns cookies, storage, cache namespace, proxy policy, and vault namespace. Proxy credentials are referenced by vault IDs rather than embedded in profile records.

iOS uses WKWebView and must respect platform limits. The starter uses non-persistent `WKWebsiteDataStore` for isolation-oriented profile sessions and avoids Chromium or fingerprint-spoofing claims.

Sync uses append-only mutations with Lamport clocks. Devices fetch mutations after their last clock and publish accepted local mutations through the backend, which fans out validated websocket events.
