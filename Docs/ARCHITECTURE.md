# Architecture

Praccy is organised feature-first. Shell-level wiring lives in `App/`, side-effect singletons in `Services/`, reusable views in `Components/`, cross-cutting helpers in `Extensions/`, design tokens in `App/Constants.swift`. Each `Features/<Feature>/` folder is self-contained; nested `Components/` subfolders hold screen-specific subviews.

```
Praccy/
├── App/                              # App shell
│   ├── PraccyApp.swift               # @main entry point, ModelContainer, DEBUG launch args
│   ├── AppShell.swift                # splash → onboarding → main state machine
│   ├── RootView.swift                # tab bar, task-detail sheet, settings sheet
│   ├── Navigation.swift              # StudentTab / TeacherTab enums
│   ├── Constants.swift               # PraccyLayout, PraccyAnimation, AccentPalette
│   └── Environment/
│       └── BackendEnvironment.swift  # @Environment keys for backend + retry queue
│
├── Models/                           # SwiftData models
│   ├── PraccySchema.swift            # Single container source of truth (cloudKitDatabase: .none)
│   ├── PracticeTask.swift            # Per-day teacher-assigned task
│   ├── Goal.swift                    # Teacher-authored aspiration
│   ├── Recording.swift               # Audio capture metadata
│   ├── TeacherLink.swift             # Student's view of linked teacher
│   ├── StudentLink.swift             # Teacher's view of linked student (asymmetric: only this side carries lastSeenAt)
│   ├── UserSettings.swift            # Singleton prefs row
│   ├── Enums.swift                   # UserRole, LinkState
│   ├── Repositories.swift            # ModelContext query helpers (currentStreak, tasks(on:), …)
│   └── SeedData.swift                # DEBUG seed helpers
│
├── Services/
│   ├── Metronome.swift               # AVAudioSourceNode, accent pattern
│   ├── Tuner.swift                   # FFT pitch detection + A440 drone
│   ├── Recorder.swift                # AVAudioRecorder, per-task .m4a files
│   └── Backend/
│       ├── PraccyBackend.swift       # Protocol + 17 DTOs
│       ├── MockBackend.swift         # DEBUG in-memory backend
│       ├── CloudKitBackend.swift     # Production: Public + Private + Shared DBs
│       ├── BackendOperationQueue.swift # Disk-backed retry queue (~/Documents/.praccy-queue.json)
│       ├── SyncCoordinator.swift     # Applies ReconcileChangeSet into SwiftData
│       ├── AppleSignInService.swift  # ASAuthorizationController wrapper
│       ├── KeychainStore.swift       # SecItem wrapper for the user identifier
│       └── JoinCodeGenerator.swift   # Six-character alphanumeric codes
│
├── Components/                       # Reusable views, no feature coupling
│   ├── PraccyHeader.swift            # Top bar: role + streak pill + settings
│   ├── PraccyTabBar.swift
│   ├── PraccySheetHeader.swift
│   ├── PraccyMascot.swift            # Tempo, with mood + pendulum
│   ├── PraccyIcon.swift              # SF Symbol wrapper enum
│   ├── PraccyCheck.swift             # Checkbox toggle
│   ├── PraccyCircleButton.swift      # 44×44pt round button
│   ├── PraccyRing.swift              # Progress ring
│   ├── PraccyPress.swift             # Press animation button style
│   ├── ConfettiBurst.swift
│   ├── StreakPill.swift
│   ├── PlaceholderTitle.swift
│   ├── NavigationAppearance.swift    # UINavigationBar theming
│   └── DesignSystemGallery.swift     # DEBUG component preview gallery
│
├── Extensions/
│   ├── Color+Praccy.swift            # PraccyColor tokens, RGB helper, hex init
│   ├── Font+Praccy.swift             # PraccyFont scale + Text/View modifiers
│   └── View+PraccyShadow.swift       # praccySolidShadow
│
├── Features/
│   ├── Calendar/                     # Month grid + selected-day detail
│   ├── Goals/                        # Read-only goal list + detail
│   ├── Home/                         # Student today screen
│   │   ├── HomeScreen.swift
│   │   └── Components/               # MascotHero, ProgressCard, TaskCard, etc.
│   ├── Onboarding/                   # 8-step setup flow
│   │   ├── OnboardingFlow.swift
│   │   ├── Components/
│   │   └── Steps/
│   ├── Settings/
│   │   ├── SettingsSheet.swift
│   │   ├── Components/
│   │   └── Sections/
│   ├── Streak/                       # Practice streak celebration sheet
│   ├── Students/                     # Teacher roster + per-student detail (teacher-only)
│   │   ├── Components/
│   │   └── Rows/
│   ├── TaskDetail/                   # Practice task detail + recording
│   │   ├── TaskDetailOverlay.swift
│   │   └── Components/
│   └── Toolkit/                      # Metronome + tuner UI
│       └── Components/
│
├── Resources/Fonts/                  # Nunito TTFs (registered via UIAppFonts)
├── Assets.xcassets/
├── Docs/                             # DESIGN.md, ARCHITECTURE.md, TODO.md, Voice.md
├── Info.plist
└── Praccy.entitlements
```

## Data flow

SwiftData is the local source of truth. `PraccySchema` pins `cloudKitDatabase: .none`; sync is `CloudKitBackend`'s job, not SwiftData's. The flow:

1. **Local writes** go straight to SwiftData via `ModelContext`.
2. **Outbound sync** is enqueued on `BackendOperationQueue`, which retries transient failures from disk and drops permanent ones.
3. **Inbound sync** runs on foreground via `RootView.reconcileOnce()` → `CloudKitBackend.reconcile` (`CKFetchRecordZoneChangesOperation`, per-DB and per-zone change tokens persisted under `UserDefaults`) → `SyncCoordinator` applies the resulting `ReconcileChangeSet` into SwiftData.
4. **Recordings** are local-first: `.m4a` files live under `Documents/recordings/{taskID}/`, and uploads attach a `CKAsset` to the corresponding task record.

`StudentLink` carries `lastSeenAt` (the teacher needs to know when each student was last active). `TeacherLink` is intentionally asymmetric; students don't surface a "last seen" for their teacher.

## Two schemes

- **`Praccy`** (student): `-SeedStudent YES` wipes and seeds a student with one active `TeacherLink`, goals, and a week of tasks.
- **`Praccy (Teacher)`**: `-SeedTeacher YES` seeds a 3–4 student roster with varied state.
- **`-ForceOnboarding YES`** (orthogonal) replays onboarding without `xcrun simctl erase`.

`MockBackend` is per-process in-memory, so two simulators see their own seeded worlds. Real cross-device sync needs CloudKit Production + two iCloud sandbox accounts.

## Audio thread invariants

`Metronome` and `Tuner` use `AVAudioSourceNode`. Their render-state structs (`MetronomeRenderState`, `TunerRenderState`) are `@unchecked Sendable`: the audio thread reads target scalars and the main actor writes them. **Do not introduce regular Swift locks on the audio thread**: priority-inversion risk.

The shared `AVAudioSession` is activated in `PraccyApp.init()` so the session is hot before the first tool start. `Recorder` flips the session to `.playAndRecord` at start and back to `.playback` at stop, so metronome/tuner survive a recording.

## Keychain + identity

`ASAuthorizationAppleIDCredential.user` (the Apple Sign-In identifier) and `CKContainer.userRecordID().recordName` (the CloudKit record name) are different strings. Both are needed and both are stored: the Apple identifier in the Keychain (`KeychainStore`, service `app.praccy.identity`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), CloudKit record name on `UserSettings`.
