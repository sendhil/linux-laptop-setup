#!/bin/bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(dirname "$script_dir")
. "$script_dir/test_helper.sh"
. "$repo_root/lib/common.sh"

cd "$repo_root"

expected_common=$(cat <<'EOF'
bash-completion	
bat	
build-essential	
ca-certificates	
curl	
direnv	
fd-find	
fzf	
git	
jq	
kitty	
neovim	0.9.0
pipx	
python3	
ripgrep	
shellcheck	
stow	
tmux	
tree	
zoxide	
zsh	
EOF
)
expected_sway=$(cat <<'EOF'
blueman	
brightnessctl	
dbus-user-session	
fuzzel	
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
xdg-desktop-portal	
xdg-desktop-portal-gtk	
xdg-desktop-portal-wlr	
xwayland	
EOF
)

assert_eq "$expected_common" "$(read_apt_file manifests/apt-common.txt)" "common APT manifest is the reviewed set"
assert_eq "$expected_sway" "$(read_apt_file manifests/apt-sway.txt)" "Sway APT manifest is the reviewed set"
assert_eq '' "$(read_apt_file profiles/work.apt.txt)" "work APT manifest starts empty"
assert_eq '' "$(read_tool_file npm manifests/npm.txt)" "npm manifest starts empty"
assert_eq '' "$(read_tool_file uv manifests/uv-tools.txt)" "uv manifest starts empty"
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
