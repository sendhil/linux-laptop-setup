# Linux laptop setup

This repository has one supported path: an additive, reviewable setup for an
Ubuntu work laptop. It prepares command-line tools and a Sway session while
leaving the workplace-managed GNOME desktop available as the GNOME fallback.
It does not remove packages, upgrade Ubuntu, manage graphics drivers, or
enable, disable, start, or stop services.

**Fedora and Lima:** the material under `fedora/`, `lima/`, and
`init/fedora.sh` is historical and unsupported. Do not use it as an
installation guide. No package or behavior from those directories is part of
the supported Ubuntu setup.

## Clean Ubuntu workflow

Clone this repository on the laptop and run these commands from its root:

```bash
bin/bootstrap
bin/audit work
bin/apply work
bin/audit work
bin/doctor work
```

`bin/bootstrap` detects Ubuntu, architecture, and visible graphics hardware,
then installs only Git and CA certificates when they are missing. It may ask
for `sudo`; it never downloads or executes an installer script.

The first `bin/audit work` is read-only. On a clean laptop it normally reports
drift and exits `1`. Review that report and the manifests before running
`bin/apply work`. Apply validates its complete plan first, installs only
missing declared packages, and is safe to rerun. The second audit should
converge. `bin/doctor work` checks commands, shell startup, external
assumptions, and—when invoked inside Sway—session services and the policy
agent. Warnings and skips remain visible but do not by themselves fail doctor.

Compatibility entry points remain for older callers: `init/ubuntu.sh`
delegates to bootstrap and `install-software.sh work` delegates to apply. New
workflows should use the `bin/` commands directly.

## Command contracts and exit codes

| Command | `0` | `1` | `2` |
| --- | --- | --- | --- |
| `bin/bootstrap` | prerequisites are ready | prerequisite installation failed | usage, platform, inventory, or privilege prerequisite error |
| `bin/audit work` | declared state is converged | missing or incompatible declared software | invalid configuration or unavailable/broken inventory manager |
| `bin/apply work` | plan applied or already converged | a package/tool installation failed | usage, manifest, platform, inventory, candidate, or privilege preflight error |
| `bin/doctor work` | no owned operational check failed | one or more owned operational checks failed | usage, manifest, or platform configuration error |
| `bin/install-sway-nvidia-session` | separate GDM session installed or already present | session installation or verification failed | usage, platform, dependency, hardware, conflict, or privilege error |

An apply failure prints a rerun command. Fix the reported problem and rerun;
completed work is discovered from current inventory rather than repeated.

If apply exposes a pre-existing Wine dependency conflict, collect a read-only
diagnostic before attempting any repair:

```bash
bin/audit-wine
```

The command reports dpkg state, held packages, relevant Wine and `bat` package
policy, and an `apt-get --simulate --fix-broken` plan. It never invokes `sudo`
or changes package state. Exit `0` means no repair action was found, exit `1`
means the simulated plan needs review, and exit `2` means the diagnostic could
not complete. Do not run a non-simulated repair until its proposed removals,
installs, and upgrades have been reviewed; Wine remains outside this
repository's ownership.

## Ownership and manifests

The supported profile is assembled from small reviewed manifests:

- `manifests/apt-common.txt` owns shared command-line and development packages.
- `manifests/apt-sway.txt` owns the Sway session and laptop integration packages.
- `profiles/work.apt.txt` is reserved for workplace-specific APT packages this
  repository has explicitly agreed to own.
- `manifests/npm.txt` and `manifests/uv-tools.txt` own reviewed developer tools
  installed through their respective managers.
- `profiles/work.external.txt` lists externally managed commands. Docker,
  Kubernetes tooling, Slack, and Zoom are diagnosed but never installed,
  upgraded, configured, or started here.

Ubuntu and workplace IT continue to own the rest of the machine. Unlisted
system packages are not drift. Corporate agents, VPNs, GNOME, GDM, graphics
drivers, privileged container runtimes, and workplace applications stay under
external ownership.

Package-source policy is deliberately conservative: prefer Ubuntu packages
for system and desktop integration; use npm or uv only for reviewed manifests;
do not add a PPA, vendor repository, or source build silently. If Ubuntu cannot
meet a declared version floor, audit reports the incompatibility and apply
stops before mutation. Resolve that case explicitly with IT or update the
reviewed manifest.

## Dotfiles handoff

Software setup belongs here; user configuration belongs in the cross-platform
dotfiles repository. After this repository converges, clone the dotfiles
repository, inspect its read-only Ubuntu preflight, and then link it:

```bash
make preflight-ubuntu
make stow-ubuntu
```

Run those commands from the dotfiles checkout. Do not use a cleanup script to
delete existing home-directory files; resolve every reported Stow conflict
explicitly. The dotfiles setup provides the Sway configuration and portable
local/SSH shell behavior.

## Sway, GDM, and GNOME

Log out, use GDM's session chooser on the login screen, and select Sway. GDM
remembers the last chosen session, but GNOME remains installed and selectable
at every login. Use GNOME immediately if Sway, screen sharing, or a corporate
application prevents work. Follow [the first Sway login checklist](docs/first-sway-login.md)
before relying on the session.

> **NVIDIA warning:** the proprietary NVIDIA driver is not officially
> supported by Sway. `bin/bootstrap` reports discoverable graphics hardware and
> `bin/doctor work` prints a prominent warning when it detects that driver. Do
> not change a workplace driver. Smoke-test Sway and retain GNOME as the
> fallback; ask IT for help if the session is unreliable.

Ubuntu 22.04's Sway package refuses to start with the proprietary NVIDIA
driver unless the unsupported-GPU flag is explicitly enabled. After the normal
Sway configuration validates, install a separate, clearly labeled GDM test
session with:

```bash
bin/install-sway-nvidia-session
```

The command is Ubuntu-only and opt-in. It requires a loaded proprietary NVIDIA
module and an installed `/usr/bin/sway`, validates the tracked desktop entry,
and uses `sudo` only to add
`/usr/share/wayland-sessions/sway-nvidia.desktop`. It never changes the standard
Sway session or graphics driver, refuses to overwrite a differing file, and is
safe to rerun. Select **Sway (NVIDIA test)** in GDM and keep GNOME available.

## Optional container smoke test

Docker is an optional local test harness for checking this repository against
a disposable Ubuntu userspace. It does not replace the physical Sway login
checklist, exercise graphics or session integration, or apply laptop state.
If Docker is already installed and its daemon is available, run:

```bash
tests/container-smoke.sh
```

Pass an image name to override the default `ubuntu:24.04`, for example
`tests/container-smoke.sh ubuntu:26.04`. Image references must begin with an
ASCII letter or digit and contain only letters, digits, `.`, `_`, `/`, `:`,
`@`, or `-`; option-like input is rejected. The harness mounts this repository
read-only, runs the host-independent test suite, and checks the supported
command scripts for Bash syntax. Any Git safe-directory override exists only
in the disposable container process. This setup does not install or start Docker.
If Docker is unavailable, skip the container smoke test; do not
install or start a workplace-managed runtime for this repository.

## Recovery

The annotated tag `pre-modernization-2026-08-11` points to the repository
before this Ubuntu modernization. Inspect it with:

```bash
git show pre-modernization-2026-08-11
```

The tag is a reference for recovery and comparison, not a supported installer.
Preserve current work before switching commits or restoring individual files.
