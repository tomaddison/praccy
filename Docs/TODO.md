# Praccy: Roadmap

What's left before v1 ships, plus near-term polish. The UI is complete on both sides, sign-in and join-code linking are real, and CloudKit task/goal/recording sync is wired end-to-end. Two-device verification is gated on Apple Developer account activation.

---

## Apple Developer provisioning

The remaining v1 blocker. Two-sim end-to-end verification, schema deploy, and TestFlight all wait on this.

- Bind `iCloud.tomaddison.Praccy` in Signing & Capabilities
- Deploy the CloudKit schema (`JoinCode` public; `StudentLinkRecord`, `AssignedTask`, `AssignedGoal` private) Development → Production
- Two iCloud sandbox accounts across two simulators: assign a task on the teacher side, confirm it lands on the student's Home after `reconcile()`

---

## Accessibility

- Dynamic Type at AX5: finish the audit and fix any remaining clipped strings
- Launch-time benchmark: Home / Students render within one frame of launch on an iPhone SE 3rd gen

---

## Notifications

Post-Apple-Developer-enrolment.

- `UNUserNotificationCenter` authorization prompt on first entry to `.main`, not at cold launch
- `UIApplication.registerForRemoteNotifications` + APNs token plumbing into `CloudKitBackend`
- `CKQuerySubscription` on the shared zone: new task → student, task complete → teacher. Persist subscription IDs in `UserDefaults`
- Local `UNCalendarNotificationTrigger` for due-date reminders as a push fallback
- Foreground delegate (banner-while-open) and badge clear-on-foreground

---

## Audio

- Hardware verification of metronome timing at high BPM (PRD §7: 1ms at 240 BPM). Simulator audio-session timing isn't representative

---

## Pre-ship

- Recording retention purge: CloudKit Function or scheduled batch, 90-day default per the privacy copy. Confirm the number before App Store submission
- Replace the About / Privacy / Terms stub alerts with `openURL` once hosted pages exist
- App Store Connect metadata, age rating, privacy nutrition label
