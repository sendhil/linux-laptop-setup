#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(dirname "$script_dir")
. "$script_dir/test_helper.sh"
. "$repo_root/lib/common.sh"

cd "$repo_root"

expected_common=$(awk '{ printf "%s\t%s\n", $1, $2 }' <<'EOF'
bash-completion
bat
build-essential
ca-certificates
curl
direnv
fd-find
fzf
gh
git
git-lfs
httpie
jq
kitty
libatomic1
lnav
neovim 0.9.0
pipx
python3
ripgrep
shellcheck
stow
tmux
tree
unzip
wezterm
zoxide
zsh
EOF
)
expected_sway=$(awk '{ printf "%s\t%s\n", $1, $2 }' <<'EOF'
blueman
brightnessctl
dbus-user-session
grim
libnotify-bin
mako-notifier
network-manager-gnome
pipewire
playerctl
policykit-1-gnome
slurp
sway
swayidle
swaylock
waybar
wireplumber
wl-clipboard
wofi
xdg-desktop-portal
xdg-desktop-portal-gtk
xdg-desktop-portal-wlr
xwayland
EOF
)

assert_eq "$expected_common" "$(read_apt_file manifests/apt-common.txt)" "common APT manifest is the reviewed set"
assert_eq "$expected_sway" "$(read_apt_file manifests/apt-sway.txt)" "Sway APT manifest is the reviewed set"
assert_contains "$(read_apt_file manifests/apt-sway.txt)" $'wofi\t' \
  'Sway manifest owns the Jammy-compatible Wofi launcher'
case $(read_apt_file manifests/apt-sway.txt) in
  *$'fuzzel\t'*) fail 'Sway manifest contains Fuzzel, which has no Jammy candidate' ;;
esac
assert_eq '' "$(read_apt_file profiles/work.apt.txt)" "work APT manifest starts empty"
assert_eq '' "$(read_tool_file npm manifests/npm.txt)" "npm manifest starts empty"
assert_eq '' "$(read_tool_file uv manifests/uv-tools.txt)" "uv manifest starts empty"
expected_work_tools=$(cat <<'EOF'
bun
bunx
code
difft
dust
eza
go
herdr
obsidian
pi
pnpm
uv
uvx
ya
yazi
EOF
)
assert_eq "$expected_work_tools" "$(read_tool_file command manifests/work-tools.txt)" "official work-tool manifest is reviewed"

if grep -Rin 'lazygit' README.md bin manifests profiles docs >/dev/null 2>&1; then
  fail 'lazygit remains in the supported setup'
fi

assert_eq "$(printf 'command\tdocker\ncommand\tkubectl\ncommand\tslack\ncommand\tzoom')" "$(load_external_assumptions work)" "work externals remain diagnostic-only"

for apt_manifest in manifests/apt-*.txt profiles/*.apt.txt; do
  normalized=$(read_apt_file "$apt_manifest")
  assert_eq "$normalized" "$(printf '%s\n' "$normalized" | LC_ALL=C sort -u)" "$apt_manifest is normalized and unique"
  case "$normalized" in
    *$'slack\t'*|*$'zoom\t'*|*$'docker\t'*|*$'containerd\t'*|*$'kubelet\t'*|*$'minikube\t'*)
      fail "$apt_manifest contains an externally managed or legacy package"
      ;;
  esac
done

printf 'ok - manifest hygiene\n'
