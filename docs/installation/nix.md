# Nix install (required for nix managed LIMA)

You need to have [nix](https://nixos.org/) installed and [flakes](https://nixos.wiki/wiki/Flakes) enabled,

[official install docs](https://nixos.org/download/) recommended, but here is a quickstart:

```sh
# Install Nix https://nixos.org/download/
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# make sure nix-flakes are enabled
mkdir -p "$HOME/.config/nix"; echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
```

# Using LIMA as a library

```sh
mkdir myproject && cd myproject

# pull the flake (needed for nix develop outside the repo)
wget https://raw.githubusercontent.com/LIMA Robotics/LIMA/refs/heads/main/flake.nix
wget https://raw.githubusercontent.com/LIMA Robotics/LIMA/refs/heads/main/flake.lock

# enter the nix development shell (provides system deps)
nix develop

python3 -m venv .venv
source .venv/bin/activate

# install everything (depending on your use case you might not need all extras,
# check your respective platform guides)
pip install "LIMA[misc,sim,visualization,agents,web,perception,unitree,manipulation,cpu,dev]"
```

# Developing on LIMA

```sh
# this allows getting large files on-demand (and not pulling all immediately)
export GIT_LFS_SKIP_SMUDGE=1
git clone -b dev https://github.com/LIMA Robotics/LIMA.git
cd LIMA

# enter the nix development shell (provides system deps)
nix develop

python3 -m venv .venv
source .venv/bin/activate

pip install -e ".[misc,sim,visualization,agents,web,perception,unitree,manipulation,cpu,dev]"

# type check
mypy LIMA

# tests (around a minute to run)
pytest LIMA
```
