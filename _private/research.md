# Report by GPT

I’ll explore robust alternative ways to dynamically adjust macOS pointer speed—especially in the background when the `fn` key is held. This includes investigating HIDEventSystemClient APIs, IOHID techniques, and system-wide overrides through private frameworks or background daemons (excluding anything that requires SIP to be disabled).

I’ll look for solutions that:

* Actually affect system cursor speed on modern macOS versions (13+)
* Work reliably even when the app is in the background
* Do not require disabling SIP or using unstable hacks

I’ll let you know what I find.


**1. Using IOKit to adjust pointer acceleration:** macOS’s pointer speed is governed by an acceleration setting in the IOHID system. By programmatically tweaking this, you can slow the cursor when `Fn` is held. For example, the (deprecated) IOKit call `IOHIDSetAccelerationWithKey` (or the private `IOHIDEventSystemClient` API) allows changing the mouse or trackpad acceleration on the fly. Setting a lower acceleration value (even down to 0 for no acceleration) makes the pointer move more slowly for a given physical movement. In practice, you’d detect the `Fn` key down (e.g. via a global event tap or IOHIDManager for the keyboard) and then call:

```swift
// Pseudo-code Swift example
let slowSpeed = 0.2   // desired slow speed (floating-point)
let normalSpeed = 0.6875  // default speed (example)
// On Fn down:
IOHIDSetAccelerationWithKey(NXOpenEventStatus(), kIOHIDMouseAccelerationType as CFString, slowSpeed)
// On Fn up:
IOHIDSetAccelerationWithKey(NXOpenEventStatus(), kIOHIDMouseAccelerationType as CFString, normalSpeed)
```

*(In modern macOS, use `IOHIDEventSystemClientCreateWithType` with `kIOHIDEventSystemClientTypeAdmin` to get an “admin” client that can set system HID properties. Then use `IOHIDEventSystemClientSetProperty` for keys like `"HIDMouseAcceleration"`, `"HIDTrackpadAcceleration"`, or the general `"HIDPointerAcceleration"`.)*

This approach doesn’t require disabling SIP – it uses Apple’s own (albeit undocumented) interfaces to mimic what System Preferences does. It affects both mouse and trackpad if you set the appropriate properties (macOS has separate acceleration settings for mice vs trackpads). The change takes effect immediately and works in the background as long as your app has the right privileges (it will need **Input Monitoring/Accessibility** permission to listen for `Fn` and perhaps to call these APIs). The trade-off is that these APIs are **private/deprecated** – Apple hasn’t provided a public replacement. They are known to work on Ventura 13+, but there’s a slight risk of breaking changes in future macOS updates. In practice, many tools (like mouse utilities and games) use this method. It’s fairly reliable and efficient, since the OS is doing the cursor scaling natively. Just remember to restore the user’s normal setting when `Fn` is released, and handle edge cases (e.g. if the user opens System Settings > Mouse while your app is running, their adjustments might conflict with yours).

**2. Tweaking global preferences on the fly:** Another idea is to temporarily override the system’s tracking speed setting via the user defaults (CFPreferences). macOS stores mouse speed in the `.GlobalPreferences` domain (e.g. `com.apple.mouse.scaling` for mice, and `com.apple.trackpad.scaling` for trackpads). Writing a lower value to these will slow the pointer. For example:

```bash
# Terminal command to slow down mouse speed to near minimum:
defaults write -g com.apple.mouse.scaling -float 0.1
```

In practice you’d do this from your app (using `CFPreferencesSetAppValue` or `NSUserDefaults` APIs) when `Fn` is pressed, then reset it on release. **However,** simply writing the default may not take effect immediately – the new value often requires the system to reload preferences. One hack is to kill the user’s preferences daemon or relevant agents to force a refresh (e.g. `killall cfprefsd` or even `killall Finder` in a pinch). System Preferences itself does more: it calls `CFPreferencesAppSynchronize`, posts distributed notifications, etc., to propagate changes. Even then, some changes only apply after re-login because the IOHID system might cache the setting at session start.

**Trade-offs:** This method avoids private APIs, but it’s **hacky and potentially slow.** There may be a noticeable delay or momentary glitch when updating the setting (especially if you restart `cfprefsd`). It also globally alters the user’s preference. If your app crashes while `Fn` is down, the setting might stick on “slow” until the user notices. Sandboxed apps cannot write to global defaults or kill system processes, so this approach effectively requires a non-sandboxed context or a helper tool. In short, it’s not the most elegant solution for real-time input changes – it was more useful for one-off tweaks (like permanently disabling acceleration). Reliable real-time toggling via this method is limited. (It might be acceptable as a fallback if other techniques fail, but you’d need to clearly restore the original setting to avoid side effects.)

**3. More privileged event filtering or injection:** Since the CGEventTap approach proved unreliable, you could go **lower-level** to intercept and modify mouse movement events. One route is implementing a **HID event filter driver** (in a Kernel Extension or DriverKit system extension). For example, Apple’s IOHID family supports filter plug-ins that can manipulate HID events before they reach user space. A custom driver could watch for the `Fn` key (from the keyboard HID stream) and scale down pointer motion events (from the mouse/trackpad HID stream) when the modifier is active. This is essentially how Karabiner-Elements works for keyboard events – it installs a virtual HID device and intercepts the real device’s events. For pointer devices, a filter driver could similarly inject a modified acceleration curve or apply a scaling factor in kernel space. The **benefit** is maximum reliability and control: running as a trusted input driver means your modifications apply even at the lowest level and even if your main app isn’t frontmost. You’re not reliant on high-level event taps, so you won’t drop events under load as easily.

**However, the drawbacks are significant:** Writing a kext or DriverKit extension is complex and requires code-signing and user approval. On modern macOS (especially Apple Silicon), the user must explicitly approve loading your extension (and *full* kernel extensions often require reduced security settings – though DriverKit mitigates this). Maintaining a custom driver across OS updates is non-trivial – Apple’s HID internals can change, and there’s no official support if you’re using private hooks. Also, a buggy driver can kernel panic or hang input. In fact, one developer who tried to fully customize macOS pointer acceleration noted that the only route was to *“write a driver and copy over the IOHIDPointerScrollFilter code”* (the part of macOS that handles pointer acceleration). This illustrates both the power and the complexity of the approach. In summary, a driver-level solution *can* achieve the effect robustly, but it’s likely overkill just to slow the cursor on `Fn` – use it only if user-space solutions prove inadequate.

**4. High-level event re-injection (not ideal):** For completeness, one could attempt a purely user-space workaround by capturing and re-posting events. For example, your app could intercept raw HID events with **IOHIDManager** (grabbing exclusive access to the mouse/trackpad), then, when `Fn` is down, scale the delta movement and emit new cursor events (using Quartz `CGEventPost` or an `IOHIDUserDevice` virtual mouse). In effect, the real device’s motion would be suppressed and you’d drive the cursor with your own slower-motion events. This approach *avoids* modifying system settings and stays in user-space, but it has serious downsides. First, taking exclusive control of the input device means if your app misbehaves, the user loses their mouse until it’s released – risky for obvious reasons. Second, synthesizing motion via `CGEventPost` has known performance and compatibility problems. The developers of *SmoothMouse* (a mouse utility) note that relying on `CGEventPost` caused skipped or choppy movement under high load and didn’t play well with apps that lock the cursor (like games or CAD software). That’s why they switched to the IOHID driver approach, which was much smoother. In our case, trying to constantly inject a stream of modified mouse events when `Fn` is held could lead to lag or erratic behavior, especially if the system is busy. Finally, a sandboxed app cannot use IOHIDManager to seize devices *nor* post global mouse events without Accessibility privileges, so this technique again demands a trusted, non-sandbox context. Given these issues, direct event injection is generally **less reliable** than the IOKit property method (#1). It’s usually a last resort if you absolutely cannot use the official acceleration setting.

**Summary of trade-offs:** The **IOHIDSystem property approach** is the most straightforward: it uses Apple’s built-in mechanism for pointer speed, and many find it reliable (tools like `hidutil` can script it, and it doesn’t require messing with the kernel). You’ll need to run your app with the right permissions (Input Monitoring) but not root or SIP disablement. The downside is using an undocumented API and affecting a global state. The **preferences hack** is simple but not well-suited to real-time changes – it’s more of a static tweak and can be slow or require logout. **Kernel/Driver solutions** can definitely work on Ventura+ (Karabiner-Elements and others prove that low-level event manipulation is possible within Apple’s security model), but they introduce significant complexity and maintenance burden. They’re also not allowed in the App Store and would require user approval to install. **Event re-injection** at user-level is possible but prone to the same issues that likely made the original CGEventTap solution “not reliable” (timing and dropped events).

In practice, **using the IOHID APIs to adjust tracking speed on the fly** is likely the best path. This could mean calling `IOHIDSetAccelerationWithKey`/`IOHIDEventSystemClientSetProperty` when `Fn` is pressed and released. Developers have used this method for similar “slow cursor” or “fast cursor” features (for example, increasing speed with a modifier) with success. It respects SIP, works in the background, and doesn’t require continuously injecting events. Just be mindful that your app will need appropriate privileges (Accessibility/automation permission to monitor keys and change system state), and always restore the original settings to avoid “stuck” slow cursor if something goes wrong. Overall, this approach provides a good balance of reliability and complexity for achieving Dragoboo’s functionality.

**Sources:**

* Apple IOKit HID references for pointer acceleration (StackOverflow/Apple docs)
* Example Swift code toggling acceleration on a modifier key
* Discussion of using `IOHIDEventSystemClient` with admin privileges for system HID settings
* macOS defaults for mouse/trackpad scaling and their behavior
* SmoothMouse developer on drawbacks of CGEvent-based injection vs. IOHID (performance issues)
* Technical exploration of custom HID filters and the need for driver-level injection for advanced cases

# Report by Claude 3.5 Sonnet

## Modifying mouse cursor speed on modern macOS beyond CGEventTap

CGEventTap modifications are increasingly being ignored on modern macOS versions, particularly in Sequoia (15.x), due to **strict timestamp validation** that silently rejects events with invalid timestamps. The primary workaround is using `CGEvent.mouseEvent()` or setting proper timestamps with `clock_gettime_nsec_np(CLOCK_UPTIME_RAW)`, but even this may not fully resolve the issue as Apple continues tightening security restrictions around event modification.

## Why CGEventTap modifications fail on modern macOS

### Timestamp validation breaks event modification
macOS Sequoia introduced mandatory timestamp validation that causes CGEventTap modifications to be silently ignored. Events created without proper timestamps or modified events that don't maintain valid timestamp chains are rejected by the system. This represents a fundamental shift in how macOS handles event security - even with full Accessibility permissions, the system now validates event authenticity through temporal consistency checks.

The security model has evolved significantly since Big Sur. System Integrity Protection (SIP) prevents modification of system processes, the sealed system volume blocks file-level changes, and the Transparency, Consent, and Control (TCC) framework requires explicit user permission for event monitoring and modification. Even when permissions are granted, macOS applies additional validation layers including event source verification and timestamp consistency checks.

### Permission complexity increases with each release
Modern macOS distinguishes between Input Monitoring permission (for observing events) and Accessibility permission (for modifying events). The `kCGEventTapOptionDefault` flag requires Accessibility permission, while `kCGEventTapOptionListenOnly` needs only Input Monitoring. However, even with proper permissions, sandboxed apps cannot use event modification taps, and the TCC database can become corrupted, causing permissions to appear granted while being non-functional.

## Alternative APIs for controlling mouse speed

### IOKit framework offers direct hardware control
The IOKit framework provides the most direct approach to mouse speed modification through IOHIDSystem parameters. While many legacy APIs like `IOHIDGetAccelerationWithKey` were deprecated in macOS 10.12, the IORegistry interface remains functional:

```c
io_service_t service = IORegistryEntryFromPath(kIOMasterPortDefault, 
    kIOServicePlane ":/IOResources/IOHIDSystem");
CFDictionaryRef parameters = IORegistryEntryCreateCFProperty(service, 
    CFSTR(kIOHIDParametersKey), kCFAllocatorDefault, kNilOptions);
```

This approach requires Accessibility permissions but works across all modern macOS versions. The limitation is that it can only modify existing acceleration curves rather than implementing custom algorithms.

### HIDDriverKit enables user-space driver development
Apple's DriverKit framework, introduced in macOS 10.15, represents the future of input device control. By creating a HIDDriverKit system extension, developers can implement virtual HID devices that intercept and modify mouse input at the driver level. This approach requires special entitlements from Apple:

- `com.apple.developer.driverkit.family.hid.device`
- `com.apple.developer.driverkit.family.hid.eventservice`
- `com.apple.developer.driverkit.userclient-access`

While more complex to implement, DriverKit solutions are App Store compatible with proper entitlements and provide the most comprehensive control over input devices. The main drawback is Apple's approval process for DriverKit entitlements, which can be lengthy and requires clear justification.

### User-space event interception remains viable
For many applications, user-space solutions using IOHIDManager combined with Quartz Event Services provide sufficient control. This approach intercepts mouse events, applies custom acceleration algorithms, and posts modified events:

```c
IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
// Configure manager to capture mouse events
// Apply custom acceleration in callback
// Post modified events using CGEventPost
```

This method requires Input Monitoring and Accessibility permissions but avoids kernel-level complexity and remains App Store compatible.

## Working implementations demonstrate success

### LinearMouse leads open-source solutions
LinearMouse (https://github.com/linearmouse/linearmouse) successfully modifies mouse behavior on all modern macOS versions including Sequoia. It uses IOHIDEventSystemClient API with administrative access to disable pointer acceleration while maintaining tracking speed. The project demonstrates that with proper implementation, mouse speed modification remains achievable despite CGEventTap limitations.

### Mac Mouse Fix innovates with gesture support
Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix) takes a comprehensive approach by capturing and simulating mouse events rather than modifying them in-place. It implements custom acceleration curves via HIDPointerAccelerationTable and adds trackpad-like gestures to mice. The project's evolution from free to freemium demonstrates the ongoing maintenance burden of keeping pace with macOS changes.

### Commercial solutions prove long-term viability
SteerMouse and CursorSense from PLENTYCOM SYSTEMS continue to function across all modern macOS versions, demonstrating that sustainable mouse modification is possible. These applications use traditional IOKit HID driver modification approaches with proper code signing and notarization, proving that Apple hasn't completely blocked mouse customization functionality.

## System-level approaches require careful consideration

### Virtual HID devices offer maximum flexibility
Creating virtual HID devices through DriverKit represents the most flexible approach for mouse speed modification. Projects like Karabiner-DriverKit-VirtualHIDDevice show how virtual devices can intercept all mouse input, apply arbitrary transformations, and present modified input to the system. This approach requires:

- DriverKit system extension with HID entitlements
- Root-privileged daemon for device communication
- Client application with Input Monitoring permission

While complex to implement, virtual HID devices bypass CGEventTap limitations entirely by operating at the driver level.

### System preferences modification provides simplicity
For applications requiring only basic speed adjustment, modifying system preferences through `defaults write` commands offers the simplest solution:

```bash
# Set custom mouse speed
defaults write -g com.apple.mouse.scaling 5.0
# Disable acceleration entirely
defaults write -g com.apple.mouse.scaling -1
```

This approach requires no special permissions and works across all macOS versions, though changes require logout or restart to take effect.

### Kernel extensions remain technically possible
While deprecated since macOS 10.15, kernel extensions (kexts) can still modify mouse behavior on Intel Macs with SIP disabled. Apple Silicon Macs require "Reduced Security" mode. However, kexts are incompatible with the App Store, require frequent updates for new OS versions, and Apple actively discourages their use. For new development, DriverKit is the clear successor.

## Conclusion

Modern macOS presents significant challenges for mouse speed modification, but viable solutions exist at every level of complexity. For App Store distribution, user-space event interception or IOKit parameter modification provide the best balance of functionality and compatibility. For maximum control, DriverKit system extensions represent Apple's endorsed path forward, though with higher implementation complexity. The key is choosing an approach that matches your application's distribution model, maintenance resources, and user experience goals while accepting that Apple's security model will continue evolving to restrict low-level system modifications.