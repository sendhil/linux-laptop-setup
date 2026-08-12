# First Sway login checklist

Complete this checklist on the physical work laptop. Static and container
tests cannot validate the display stack, peripherals, corporate applications,
or screen-sharing chooser. Keep GNOME available in GDM until every critical
workflow has been exercised.

Before logging in:

- [ ] Run `bin/audit work` and confirm the owned manifests are converged.
- [ ] Run `bin/doctor work` from GNOME or a terminal and review every warning.
- [ ] If a proprietary NVIDIA driver is detected, do not change it; plan a
  short Sway smoke test and be ready to select GNOME again in GDM.
- [ ] Run `make preflight-ubuntu` and `make stow-ubuntu` from the separate
  cross-platform dotfiles checkout.

Choose Sway from GDM's session menu, then verify:

- [ ] Sway reaches a stable desktop and logout returns to GDM.
- [ ] GNOME can still be selected and reaches a stable desktop.
- [ ] `Alt+Enter` opens the terminal and `Alt+d` opens the application launcher.
- [ ] Mirrored focus, move, resize, fullscreen, scratchpad, monitor, and
  workspace 1–20 bindings behave as documented by the dotfiles repository.
- [ ] Built-in and attached displays use the expected resolution, scale,
  position, refresh rate, and lid behavior.
- [ ] Waybar shows workspaces and useful laptop status without errors.
- [ ] Mako displays and dismisses test notifications.
- [ ] Copy and paste work between native Wayland applications, terminal
  applications, and XWayland applications.
- [ ] Region and full-screen screenshots capture the intended pixels and copy
  or save successfully.
- [ ] Manual locking works, idle locking triggers, and resume accepts the
  expected credentials without exposing the session.
- [ ] Speakers, headphones, microphone input, mute keys, and volume keys work.
- [ ] Network status is visible and Wi-Fi can disconnect and reconnect.
- [ ] Bluetooth can discover and reconnect a trusted peripheral.
- [ ] Policy prompts appear for an action that legitimately needs elevation.
- [ ] Slack and Zoom launch, display correctly, and can access the microphone
  and camera according to workplace policy.
- [ ] Slack and Zoom screen sharing opens the desktop portal chooser and
  shares the selected display or window rather than a blank frame.
- [ ] An incoming SSH session from the work Mac starts Bash/Zsh cleanly, works
  without a graphical environment, and supports terminal copy behavior.
- [ ] `bin/doctor work` inside Sway reports working portals, audio session
  services, and policy-agent integration; investigate every `FAIL`.
- [ ] Logout works without a forced reboot, and both Sway and GNOME remain in
  the next GDM session menu.

If a critical item fails, record whether the application is native Wayland or
XWayland, log out normally, and select GNOME in GDM. Do not replace workplace
drivers, desktop packages, or IT-owned services as a troubleshooting shortcut.
