# First Sway login checklist

Complete this checklist on the physical work laptop. Static and container
tests cannot validate the display stack, peripherals, corporate applications,
or screen-sharing chooser. Keep GNOME available in GDM until every critical
workflow has been exercised.

Before logging in:

- [ ] From this checkout in GNOME, run
  `bin/setup-work-laptop work "$HOME/src/dotfiles-mac"`. Confirm the exact
  `JetBrainsMono Nerd Font Mono` family resolves with `fc-match`, and review
  every audit and doctor warning.
- [ ] If a proprietary NVIDIA driver is detected, do not change it; plan a
  short Sway smoke test and be ready to select GNOME again in GDM. On Ubuntu
  22.04, validate the Sway config with `sway --unsupported-gpu --validate -c
  ~/.config/sway/config`, then run `bin/install-sway-nvidia-session` and select
  **Sway (NVIDIA test)** rather than modifying the standard session.
- [ ] Confirm the coordinator preflights and links the separate cross-platform
  dotfiles checkout without deleting an existing home-directory file.

Choose Sway from GDM's session menu, then verify:

- [ ] Rerun the same command inside Sway. Confirm its local profile targets
  only the selected built-in keyboard, leaves external keyboards unchanged,
  and sets the local WezTerm font size to 17.
- [ ] Sway reaches a stable desktop and logout returns to GDM.
- [ ] GNOME can still be selected and reaches a stable desktop.
- [ ] `Alt+Enter` opens WezTerm and `Alt+Space` opens the application launcher.
- [ ] The physical Command key uses the shared WezTerm shortcuts: `Super+T`
  opens a tab, `Super+N` opens a window, `Super+W` closes the current tab with
  confirmation, `Super+C` copies, `Super+V` pastes, and `Super+F` searches;
  Ctrl remains terminal input.
- [ ] Mirrored focus, move, resize, fullscreen, scratchpad, monitor, and
  workspace 1–20 bindings behave as documented by the dotfiles repository.
- [ ] Built-in and attached displays use the expected resolution, scale,
  position, refresh rate, and lid behavior.
- [ ] Verify brightness/backlight controls and laptop brightness keys change the
  built-in display smoothly across a usable range.
- [ ] Waybar shows workspaces and useful laptop status without errors.
- [ ] Mako displays and dismisses test notifications.
- [ ] Copy and paste work between native Wayland applications, terminal
  applications, and XWayland applications.
- [ ] Region and full-screen screenshots capture the intended pixels and copy
  or save successfully.
- [ ] Manual locking works, idle locking triggers, and resume accepts the
  expected credentials without exposing the session.
- [ ] Suspend and resume once. If WezTerm exits or displays a rendering error,
  capture the occurrence before restarting it with
  `journalctl --user -b --since "-10 minutes" -o short-precise | rg -i
  'wezterm|wayland|gpu|egl|vulkan|drm'` and preserve the complete output for
  workplace IT or a reproducible follow-up. Do not change the graphics driver
  from this checklist.
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
