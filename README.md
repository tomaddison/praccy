# Praccy

### The practice companion that keeps teacher and student in sync.

Praccy is an iOS app for music teachers and their students. Teachers assign tasks and goals; students see them on a "today" screen, practise, and tick them off. Teachers get an overview of progress, and students gamify their practice with daily streaks.

<img width="1400" height="735" alt="hero" src="https://github.com/user-attachments/assets/6d7e93a1-abd2-4f87-8bb8-3df414c4d303" />

---

## Features

- **Today screen** - Mascot-led student home with a progress ring, today's teacher-assigned tasks, and a collapsible done section.
- **Teacher roster** - Students sorted active before pending. Per-student detail shows task and goal history.
- **Join-code linking** - Six-character codes redeem against a CloudKit public record, then promote to a private CKShare for ongoing sync.
- **Practice streak** - Flame pill in the header opens a celebration sheet.
- **On-device recordings** - `.m4a` capture per task, stored under `Documents/recordings/{taskID}/` and attached to records as `CKAsset`.
- **Accent-pattern metronome** - Driven by `AVAudioSourceNode` with no queued-buffer drift. Per-beat accent customisation.
- **Drone tuner** - Tunable A440.
- **Onboarding** - Eight-step flow with Sign in with Apple. Replays cleanly via `-ForceOnboarding`.

---

## Stack

| Layer         | Technology                                                              |
| ------------- | ----------------------------------------------------------------------- |
| UI            | SwiftUI                                                                 |
| Persistence   | SwiftData (local-only, `cloudKitDatabase: .none`)                       |
| Sync          | CloudKit (custom `CloudKitBackend` + `BackendOperationQueue`)           |
| Auth          | Sign in with Apple, Keychain-stored identifier                          |
| Audio         | AVAudioSourceNode (metronome + tuner drone), AVAudioRecorder            |
| Pitch         | FFT-based detection (`Tuner.swift`)                                     |
| Haptics       | UIImpactFeedbackGenerator                                               |
| Fonts         | Nunito (Bold / ExtraBold / Black)                                       |
| Min iOS       | iOS 17                                                                  |

---

## Getting Started

1. Clone the repository
2. Open `Praccy.xcodeproj` in Xcode 16 or later
3. Pick a scheme:
   - **`Praccy`**: student side. Pass `-SeedStudent YES` to land on a populated home with a mock teacher and a week of tasks.
   - **`Praccy (Teacher)`**: teacher side. Pass `-SeedTeacher YES` for a 3–4 student roster.
   - Add `-ForceOnboarding YES` to either scheme to replay onboarding without wiping the simulator.
4. Build and run with `⌘R`.

The MockBackend keeps things working in DEBUG; `CloudKitBackend` is bound to `iCloud.tomaddison.Praccy`.

---

## Docs

- [`Docs/DESIGN.md`](Docs/DESIGN.md): design principles, typography, palette, voice rules
- [`Docs/ARCHITECTURE.md`](Docs/ARCHITECTURE.md): folder layout and the SwiftData / CloudKit split
- [`Docs/TODO.md`](Docs/TODO.md): roadmap, blocking work, done log
- [`Docs/Voice.md`](Docs/Voice.md): copy and tone rules
