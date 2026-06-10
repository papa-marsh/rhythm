# Releasing Rhythm

How to ship an update to the App Store. For build/test commands and architecture, see the root `AGENTS.md`.

## Identities

| | Debug (Xcode run) | Release (TestFlight / App Store) |
|---|---|---|
| Bundle ID | `com.marshallwarners.Rhythm.dev` | `com.marshallwarners.Rhythm` |
| Home screen name | Rhythm Dev | Rhythm |
| CloudKit environment | Development | **Production** |

Both configurations use the container `iCloud.marshallwarners.RhythmData`, but CloudKit keeps the two environments fully separate. Consequences:

- Running from Xcode installs side-by-side with the App Store app and can never see or damage production data.
- **TestFlight builds are Release builds** — they run against the production CloudKit environment and replace the App Store install. Treat TestFlight like production.

## Update workflow

### 1. Pre-flight

- Tests pass: `xcodebuild ... test -only-testing:RhythmTests` (see `AGENTS.md`).
- Bump versions in the Rhythm target (Xcode → target → General, or `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in the pbxproj):
  - `MARKETING_VERSION` — the user-visible version (e.g. `1.1`). Bump for every App Store release.
  - `CURRENT_PROJECT_VERSION` — the build number. Must be unique per upload; bump it every time you upload, including re-uploads of the same marketing version.

### 2. Promote CloudKit schema (only if models changed)

Dev builds register schema changes in the **Development** environment as you use them. Production knows nothing about them until you deploy the schema, and a release whose models reference undeployed record fields will fail to sync.

1. [CloudKit Console](https://icloud.developer.apple.com) → container `iCloud.marshallwarners.RhythmData`
2. Run the new build in Development at least once (so the new fields exist in the Dev schema)
3. **Deploy Schema Changes** → review the diff → deploy to Production

Schema deploys are additive-only, and so are the model rules (see `AGENTS.md` → Models): new properties must be optional or defaulted; never rename or retype existing ones.

### 3. Archive and upload

In Xcode: select the **Rhythm** scheme, destination **Any iOS Device (arm64)** → Product → **Archive** → Organizer opens → **Distribute App** → **App Store Connect** → Upload. Automatic signing handles certificates and profiles.

Wait for the build to finish processing in App Store Connect (~5–30 min; email arrives when done).

### 4. Submit in App Store Connect

1. [App Store Connect](https://appstoreconnect.apple.com) → Rhythm → **+** new version (matching `MARKETING_VERSION`)
2. Write "What's New" release notes
3. Select the processed build
4. Update screenshots/description if the UI changed
5. **Add for Review** → submit

Review typically takes 1–2 days. Release is automatic on approval unless you chose manual release.

### 5. Verify

After release, update the App Store install on a real device and confirm new/changed data still syncs (CloudKit Console → Records → **Production** → Private DB → "Act as iCloud account" → zone `com.apple.coredata.cloudkit.zone` is the ground truth for what's server-side).

## Debugging production sync

Record types mirrored by SwiftData are named `CD_<Model>` and live in zone `com.apple.coredata.cloudkit.zone` of the private database. The Console can only *query* records if the type has a queryable index on `recordName` — add it under Schema (Development) → Indexes, then deploy to Production. Indexes are additive and safe.
