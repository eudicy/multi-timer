# ADR 001: Background Timer Reliability with Screen Lock

## Status

Proposed

## Executive Summary

The timer app's gong sound fails to play after 5 minutes when the device screen locks because both iOS and Android suspend background apps, stopping Dart's `Future.delayed()` timers. This affects core app functionality and requires architectural changes.

**Recommended Solution**: Implement OS-native local notifications using `flutter_local_notifications` package. This is the industry-standard approach used by timer apps and provides reliable cross-platform functionality with minimal battery impact.

**Key Trade-offs**: Increased implementation complexity and platform-specific configuration in exchange for reliable timer delivery when screen is locked on both iOS and Android.

## Context

The multi-timer application uses `Future.delayed()` to wait for specific durations (5 minutes, 1 minute, etc.) before playing a gong sound. During testing on iPhone, the gong sound does not play after 5 minutes when the device screen locks automatically after 30 seconds of inactivity.

Both iOS and Android suspend apps when the screen locks to conserve battery. This causes the Flutter engine to pause, stopping Dart timers from counting. The app "freezes" in its current state, and timers never complete.

## Decision Drivers

1. **Reliability** (highest priority): Timer alerts must work consistently when device screen is locked
2. **Cross-platform compatibility**: Solution must work on both iOS and Android
3. **Battery efficiency**: Solution should minimize battery drain
4. **User experience**: Minimal disruption to users (e.g., screen should be allowed to lock)
5. **Development complexity**: Implementation should be maintainable and well-supported

## Considered Options

1. **Implement Local Notifications with `flutter_local_notifications`** (RECOMMENDED)
2. Use `awesome_notifications` Package (Alternative)
3. Keep Screen Awake with `wakelock_plus` (Not Recommended)
4. Do Nothing / Accept Current Behavior (Not Viable)
5. Document Manual Workarounds for Users (Not Recommended)
6. Purchase/Use Existing Timer App (Viable Alternative)
7. Background Audio Session with `audio_session` + `wakelock_plus` (Not Recommended)

## Options Comparison Matrix

| Criteria | Option 1: flutter_local_notifications | Option 2: awesome_notifications | Option 3: wakelock_plus | Option 4: Do Nothing | Option 5: Manual Workarounds | Option 6: Use Existing App | Option 7: Background Audio Session |
|----------|--------------------------------------|--------------------------------|------------------------|---------------------|----------------------------|---------------------------|-----------------------------------|
| **Reliability** | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐ Good (if screen stays on) | ⭐ Poor | ⭐⭐ Poor | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐ iOS: Good with silent loop / Android: Poor (Doze) |
| **Cross-platform** | ⭐⭐⭐⭐⭐ Full support | ⭐⭐⭐⭐⭐ Full support | ⭐⭐⭐⭐⭐ Full support | ⭐⭐⭐⭐⭐ N/A | ⭐⭐ Platform-specific | ⭐⭐⭐⭐⭐ Full support | ⭐⭐ iOS only for screen-lock benefit |
| **Battery Efficiency** | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐⭐ Excellent | ⭐ Very Poor | ⭐⭐⭐⭐⭐ N/A | ⭐ Very Poor | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐ Good on iOS / ⭐ Poor on Android (screen-on or foreground service) |
| **User Experience** | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐ Poor | ⭐ Unacceptable | ⭐⭐ Poor | ⭐⭐⭐⭐ Good (depends on app) | ⭐⭐⭐⭐ Good on iOS / ⭐⭐ Poor on Android |
| **Development Complexity** | ⭐⭐⭐ Moderate | ⭐⭐ Higher | ⭐⭐⭐⭐⭐ Very Simple | ⭐⭐⭐⭐⭐ None | ⭐⭐⭐⭐ Low Code | ⭐⭐⭐⭐⭐ None | ⭐⭐⭐ Moderate (silent loop, session lifecycle, interruption handling) |
| **Maintenance Burden** | ⭐⭐⭐⭐ Low | ⭐⭐⭐ Moderate | ⭐⭐⭐⭐ Low | ⭐⭐⭐⭐⭐ None | ⭐ Very High | ⭐⭐⭐⭐⭐ None | ⭐⭐⭐ Moderate (fragile iOS "hack", Android gap) |
| **Industry Standard** | ⭐⭐⭐⭐⭐ Yes | ⭐⭐⭐⭐ Acceptable | ⭐⭐ Uncommon | ⭐ Unacceptable | ⭐ Unprofessional | ⭐⭐⭐⭐⭐ Standard | ⭐⭐⭐ Used in production but acknowledged as workaround |
| **Overall Recommendation** | **RECOMMENDED** | Alternative | Not Recommended | Not Viable | Not Recommended | Viable Alternative | Alternative for iOS-only scope; not recommended for cross-platform |

## Detailed Options Analysis

### Option 1: Implement Local Notifications with `flutter_local_notifications`

Schedule OS-native notifications at the required times when user starts the timer.

#### Summary

Use the `flutter_local_notifications` package to schedule all 7 timer notifications when the user presses start. The operating system manages timing and delivery, ensuring reliability even when the app is suspended.

#### Positive Consequences

- Highly reliable on both iOS and Android
- Works when app is suspended, backgrounded, or even terminated
- Minimal battery impact (OS-managed)
- Well-established pattern used by most timer apps
- Strong community support and documentation
- Can schedule notifications with custom sounds
- `androidAllowWhileIdle: true` ensures delivery even in Doze mode

#### Negative Consequences

- Requires platform-specific configuration (AndroidManifest.xml, Info.plist)
- Need to manage notification permissions (request from user)
- iOS limits to 64 pending notifications per app
- Sound file format requirements differ by platform (MP3 for Android, AIFF for iOS)
- Notifications appear in notification tray (may be seen as intrusive by some users)
- Requires timezone package dependency for accurate scheduling
- Implementation more complex than simple timer

#### Mitigations for Negative Consequences

- **Platform-specific configuration**: One-time setup with clear documentation and examples available from package maintainer
- **Notification permissions**: Request permission at app launch with clear explanation of why it's needed; standard practice for timer apps
- **iOS 64 notification limit**: Not a concern for this app (only 7 notifications per timer session); can cancel previous notifications if user restarts timer
- **Sound file format differences**: Convert gong sound to both formats once during development; automated tooling available
- **Notifications in tray**: This is expected behavior for timer apps; allows users to see remaining timers at a glance; can be configured as non-persistent
- **Timezone dependency**: Lightweight package (~1MB); widely used and maintained
- **Implementation complexity**: Well-documented package with extensive examples; complexity is one-time investment for reliable functionality

#### Technical Implementation Details

- Use `flutter_local_notifications` package (v9.5.3+1 or later)
- Schedule all 7 notifications upfront at calculated times when user presses "Start"
- Each notification configured with custom gong sound
- OS handles timing and delivery, independent of app state
- Use `androidAllowWhileIdle: true` to ensure delivery even in Doze mode

### Option 2: Use `awesome_notifications` Package

Alternative notification package with more features and customization.

#### Summary

Similar to Option 1 but with more advanced notification UI capabilities. Provides richer customization options at the cost of increased complexity and package size.

#### Positive Consequences

- More customization options for notification appearance
- Rich notification UI capabilities
- Cross-platform support
- Scheduled notifications work when app suspended

#### Negative Consequences

- Heavier package (larger app size)
- More complex API and setup
- Less widely adopted than `flutter_local_notifications`
- May be overkill for simple timer requirements
- Steeper learning curve

#### Mitigations for Negative Consequences

- **Package size**: While heavier, modern devices handle this easily; can evaluate if app size becomes critical concern
- **Complex API**: Documentation is comprehensive; invest time upfront in learning the API
- **Less adoption**: Still has active maintenance and community; viable option if additional features needed
- **Overkill for simple timers**: Consider only if need advanced notification features beyond basic sound alerts
- **Learning curve**: Prototype with simpler `flutter_local_notifications` first; migrate only if advanced features prove necessary

#### Technical Implementation Details

- Use `awesome_notifications` package
- Schedule notifications with advanced UI customization
- Similar OS-native notification approach to Option 1

### Option 3: Keep Screen Awake with `wakelock_plus`

Prevent device screen from locking so current timer implementation continues to work.

#### Summary

Use `wakelock_plus` package to prevent screen from sleeping during timer operation. Allows existing `Future.delayed()` code to work but causes significant battery drain and poor user experience.

#### Positive Consequences

- Simplest implementation (minimal code changes)
- No need to modify notification permissions
- Current timer logic works as-is
- Cross-platform support

#### Negative Consequences

- Significant battery drain (screen stays on continuously)
- Poor user experience (bright screen for 5+ minute durations)
- Users cannot use device normally during timer
- Not standard practice for timer applications
- Does not solve problem if user manually locks screen
- Increases device heat generation
- May cause screen burn-in on OLED displays with prolonged use

#### Mitigations for Negative Consequences

- **Battery drain**: Reduce screen brightness programmatically during timer; partial mitigation only
- **Bright screen UX**: Display dim timer countdown; still disruptive for users wanting to pocket device
- **Device usage restriction**: Cannot be fully mitigated; fundamental limitation of approach
- **Non-standard practice**: No mitigation; accept deviation from industry norms or choose different solution
- **Manual lock problem**: Display prominent warning to users not to lock screen; poor UX
- **Heat generation**: Unavoidable side effect of keeping screen on; reduces device lifespan
- **OLED burn-in**: Animate timer display to move pixels; only partial mitigation; risk remains

**Overall assessment**: Mitigations are insufficient; this approach has fundamental drawbacks that cannot be adequately addressed.

#### Technical Implementation Details

- Use `wakelock_plus` package
- Acquire wake lock when timer starts
- Release when timer completes or user stops
- Current `Future.delayed()` implementation remains unchanged

### Option 4: Do Nothing (Accept Current Behavior)

Continue with current implementation, accept that timer only works with screen unlocked.

#### Summary

Make no changes to the codebase. Document the limitation that users must keep their screen on for timers to function. Not viable for production use.

#### Positive Consequences

- Zero development effort
- No additional dependencies
- Simplest possible approach

#### Negative Consequences

- App does not meet basic user expectations for timer functionality
- Poor user reviews likely
- Users will uninstall or not use the app
- Timer is essentially non-functional for real-world use cases
- Defeats the purpose of having a timer app

#### Mitigations for Negative Consequences

- **User expectations**: Clearly document limitation in app description and first-run tutorial; still results in poor UX
- **Poor reviews**: Proactively explain limitation before users discover it; unlikely to prevent negative feedback
- **User churn**: No effective mitigation; users need working timer functionality
- **Non-functional for real use**: Cannot be mitigated without code changes
- **Defeats purpose**: No mitigation possible; fundamentally fails to solve the core problem

**Overall assessment**: No viable mitigations; this option makes the app unsuitable for its intended purpose.

### Option 5: Investigate Manual Workarounds

Document ways users can configure their devices to keep app running.

#### Summary

Provide documentation instructing users to modify device settings (increase auto-lock time, disable battery optimization) rather than fixing the app. Places unreasonable burden on users and doesn't reliably solve the problem.

#### Positive Consequences

- No code changes required
- Transfers responsibility to users
- May work for technically savvy users

#### Negative Consequences

- Poor user experience (unreasonable burden on users)
- Workarounds may not persist across device restarts
- Different instructions needed per device manufacturer
- Not reliable (users forget, settings reset)
- Still requires screen to stay on (battery drain)
- Does not solve core problem
- Unprofessional solution for a published app

#### Mitigations for Negative Consequences

- **Poor UX**: Create detailed visual guides with screenshots; still places burden on users
- **Settings persistence**: Remind users to check settings periodically; unreliable
- **Manufacturer variations**: Maintain comprehensive documentation for major manufacturers (Samsung, Xiaomi, Huawei, OnePlus, etc.); high maintenance burden
- **Reliability issues**: Add in-app reminders and check settings programmatically; cannot force user compliance
- **Battery drain**: No mitigation; inherent to workaround approach
- **Core problem unsolved**: Combine with other options (e.g., also implement notifications); adds complexity
- **Unprofessional**: Cannot be mitigated; industry expects apps to "just work"

**Overall assessment**: Mitigations add complexity without achieving reliability; not recommended for production apps.

### Option 6: Purchase/Use Existing Timer App

Instead of building custom solution, use existing timer applications.

#### Summary

Abandon custom development and use an existing timer app from the App Store or Play Store. Evaluates trade-off between development effort and control over functionality.

#### Positive Consequences

- Zero development time
- Professional, tested solutions
- Regular updates and support
- Proven reliability
- Additional features may be available

#### Negative Consequences

- Loss of control over features and behavior
- May not match exact requirements (specific interval pattern)
- Ongoing cost if subscription-based
- Privacy concerns with third-party apps
- Cannot customize for specific needs
- Dependency on external vendor
- May include ads or unwanted features

#### Mitigations for Negative Consequences

- **Loss of control**: Evaluate apps thoroughly before committing; choose open-source options if available
- **Feature mismatch**: Test multiple apps to find closest match; may require accepting compromises
- **Ongoing costs**: Prefer one-time purchase or free apps; evaluate cost vs. development time savings
- **Privacy concerns**: Review privacy policies carefully; choose apps with strong privacy ratings
- **Limited customization**: Accept constraints or combine with minimal custom development
- **Vendor dependency**: Keep backup timer app identified; document alternatives
- **Ads/unwanted features**: Look for premium versions or ad-free options; factor cost into decision

**Overall assessment**: Viable option if an existing app meets requirements; evaluate thoroughly before abandoning custom development.

#### Candidate Apps

- Insight Timer (meditation app with interval timers)
- Interval Timer - HIIT Workouts
- MultiTimer by Jee Chul Kim

Requires evaluation for feature fit with specific use case (5-1-5-1-5-2-1 minute pattern).

### Option 7: Background Audio Session with `audio_session` + `wakelock_plus`

Keep the existing timer logic by using the OS audio subsystem to prevent app suspension.

#### Summary

Declare `UIBackgroundModes: audio` in `Info.plist` and configure an `AVAudioSession` with category `.playback` via the `audio_session` package, so iOS treats the app as an audio player and does not suspend it when the screen locks. However, iOS deactivates the session after a few seconds of genuine silence, which freezes `Future.delayed()` — the only workaround is to loop a silent audio file throughout the exercise to keep the session active. On Android, `wakelock_plus` acquires only a screen wake lock (`FLAG_KEEP_SCREEN_ON`) and provides no CPU protection once the screen turns off; reliable Android support additionally requires a foreground service with a CPU partial wake lock (e.g. `flutter_foreground_task`).

#### Positive Consequences

- Screen can lock on iOS without stopping the timer
- No notification permission prompt required on iOS
- Gongs and instructions play as in-app audio with no entries in the notification tray
- Existing `Future.delayed()` timer logic remains largely unchanged on iOS

#### Negative Consequences

- Silent audio looping required on iOS: without it, iOS deactivates the session during 5-minute gaps and freezes the Dart isolate; adds a fragile extra asset and an additional `AudioPlayer` instance
- The silent-loop workaround relies on undocumented Apple behaviour and could break with an OS update
- `wakelock_plus` is screen-only on Android (`FLAG_KEEP_SCREEN_ON`); Doze mode will freeze `Future.delayed()` during gaps once the screen turns off
- Android requires a foreground service with `PARTIAL_WAKE_LOCK` to work correctly, which shows a persistent notification — the same UX cost as Option 1 but with greater implementation complexity
- Incoming calls and audio focus changes can deactivate the iOS session and suspend the timer
- Total complexity (silent loop, interruption handling, session lifecycle, Android foreground service) matches or exceeds Option 1 without its cross-platform reliability

#### Mitigations for Negative Consequences

- **Silent audio looping**: Bundle a short silent `.wav` file and loop it at zero volume with `mixWithOthers` for the duration of the exercise; widely used in production meditation apps
- **iOS interruptions**: Use `audio_session`'s `interruptionEventStream` to reactivate the session after interruptions; recalculate timer progress from elapsed wall-clock time
- **Android Doze mode**: Implement `flutter_foreground_task` with `wakeLock: true`; accept that a persistent foreground notification is visible, equivalent to the notification approach
- **Workaround fragility**: Monitor `audio_session` issue tracker and Apple release notes; have a tested fallback to Option 1 ready

**Overall assessment**: Mitigations bring total complexity close to Option 1 while delivering weaker cross-platform reliability; not recommended when both iOS and Android are in scope.

#### Technical Implementation Details

- Use `audio_session` package for iOS `AVAudioSession` configuration (`AVAudioSessionCategory.playback`, `mixWithOthers`)
- Add `UIBackgroundModes: audio` to `ios/Runner/Info.plist`
- Bundle and loop a silent `.wav` asset to keep the audio session active during silent gaps
- Use `flutter_foreground_task` with `wakeLock: true` for Android background execution
- Subscribe to `audio_session.interruptionEventStream` to handle call interruptions on iOS

## Technical Considerations

### Current Timer Implementation

The app defines a sequence of 7 wait durations:

```dart
final List<int> _waitDurations = [300, 60, 300, 60, 300, 120, 60];
// Translates to: 5 min, 1 min, 5 min, 1 min, 5 min, 2 min, 1 min
```

### Sound Asset Requirements

- **Current format**: MP3 (`assets/gong.mp3`)
- **Android requirement**: MP3 or other Android-supported formats
- **iOS requirement**: AIFF, CAF, or other iOS-supported formats
- **Action needed**: Convert gong.mp3 to gong.aiff for iOS notifications

### Notification Scheduling Pattern

For Options 1 and 2, notifications would be scheduled at cumulative times:

| Notification | Time from Start | Cumulative Seconds |
|-------------|----------------|-------------------|
| 1 | 5 minutes | 300s |
| 2 | 6 minutes | 360s |
| 3 | 11 minutes | 660s |
| 4 | 12 minutes | 720s |
| 5 | 17 minutes | 1020s |
| 6 | 19 minutes | 1140s |
| 7 | 20 minutes | 1200s |

### Permission Requirements by Platform

#### iOS (Option 1 or 2)

- Request notification permission via `UNUserNotificationCenter`
- Users can deny; app must handle gracefully
- Add `UIBackgroundModes` key with `remote-notification` value (optional for better reliability)

#### Android (Option 1 or 2)

- Notification permission required for Android 13+ (API level 33+)
- Need to declare in AndroidManifest.xml:
  - `android.permission.POST_NOTIFICATIONS` (Android 13+)
  - `android.permission.SCHEDULE_EXACT_ALARM` (Android 12+)
  - `android.permission.USE_EXACT_ALARM` (Android 14+)

### Migration Path

If Option 1 is selected, suggested implementation phases:

1. **Phase 1**: Add dependencies and platform configuration
2. **Phase 2**: Implement notification initialization and permission request
3. **Phase 3**: Convert sound file to iOS-compatible format
4. **Phase 4**: Replace `Future.delayed()` loop with notification scheduling
5. **Phase 5**: Test on both iOS and Android with screen locked
6. **Phase 6**: Handle notification cancellation if user stops timer early

## Decision

[To be decided by stakeholder]

## Consequences

[To be completed after decision is made]

## Implementation Notes

[To be completed after decision is made]

## Appendix: Detailed Problem Analysis

### iOS Behavior

When the iPhone screen locks:

- iOS suspends the app to conserve battery
- The Flutter engine is paused
- `Future.delayed()` timers stop counting because they depend on the active Dart isolate
- The app "freezes" at approximately 30 seconds into the timer
- After 5 minutes of wall clock time, only ~30 seconds have elapsed from the app's perspective
- The gong never plays because the timer never completes

### Android Behavior

Android devices exhibit similar issues but with more variability:

- **Doze Mode** (Android 6.0+): When screen is off and device stationary, apps are suspended
- `Future.delayed()` timers also stop in Doze mode
- Behavior varies by manufacturer (Samsung, Xiaomi, Huawei have aggressive battery optimizations)
- May work for several minutes before Doze activates, but unreliable
- No guarantees the timer will complete

### Root Cause

The current implementation lacks:

- Background execution permissions
- OS-native timing mechanisms that work when app is suspended
- Any wake locks or foreground services
- Local notification scheduling
- An active audio session that would grant iOS background execution as an audio app

