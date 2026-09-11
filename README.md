# matteing/nix

Declarative configuration for Sergio's Mac and bare-metal NixOS server.

This source is intended for public sharing as a reference for a personal setup.
Using the complete configurations requires the owner's decryption key or your
own private modules. A locked module deliberately prevents evaluation.

## Systems

| Output | Platform | Purpose |
| --- | --- | --- |
| `darwinConfigurations.matteing-mbp` | `aarch64-darwin` | Personal Mac workstation |
| `nixosConfigurations.homelab` | `x86_64-linux` | Lightweight physical container server |

There is no VM host or test operating system in this repository. The homelab
configuration is the bare-metal configuration and contains the generated
hardware facts for the HP EliteDesk.

## Layout

```text
flake.nix                         exports the machines
inventory.nix                     hosts, architectures, channels, and identity
lib/mk-host.nix                   nix-darwin/NixOS construction only
home/common.nix                   Home Manager policy shared by both machines
home/macos.nix                    Mac-only development environment
hosts/matteing-mbp/default.nix    complete Mac composition
hosts/matteing-mbp/apps.nix       public loader for the local app module
hosts/matteing-mbp/apps.nix.age   encrypted Mac apps and app-specific settings
hosts/matteing-mbp/apps.local.nix decrypted app module (ignored by Git)
hosts/matteing-mbp/apps.local.state
                                  local synchronization receipt (ignored by Git)
hosts/matteing-mbp/settings.nix   general macOS defaults and wallpaper
hosts/homelab/default.nix         complete handwritten server policy
hosts/homelab/network.nix         public loader for private network settings
hosts/homelab/network.nix.age     encrypted network name and PSK reference
hosts/homelab/network.local.nix   decrypted network module (ignored by Git)
hosts/homelab/network.local.state
                                  local synchronization receipt (ignored by Git)
hosts/homelab/hardware-configuration.nix
                                  generated EliteDesk hardware facts
keys/sergio.pub                   public SSH key
assets/                           files used by the Mac configuration
```

The import graph is deliberately shallow: `flake.nix` reads the inventory, the
builder selects the platform, and each host owns its policy. Only behavior used
by both machines lives in `home/common.nix`; new reusable modules should be
extracted only when a second host actually needs them.

The homelab configuration keeps Docker, OpenSSH, Tailscale, mDNS, its firewall,
user account, packages, and garbage collection together in one file. It does
not override the kernel's CPU governor, firmware policy, filesystem trimming,
documentation, or Docker logging defaults. Git, GitHub CLI, Codex CLI, Make,
and tmux are available on the server. Application language runtimes and
dependencies belong in Docker containers rather than on the host. Garbage
collection runs weekly and removes store paths and old generations that have
been unreachable for more than 30 days.

The Mac imports the Mise development profile with pinned Node, Erlang, Elixir,
Python, pnpm, and uv versions. Mise is intentionally not installed on the
homelab.

## Everyday commands

Make is the repository task runner on both machines. Mise manages development
runtimes only on the Mac.

The current hostname is used by default. Override it with `HOST=<name>`.

```console
make fmt
make check-host
make check
make build
make test
make switch
```

On NixOS, `make test` activates a generation until reboot; `make switch` also
makes it the boot default.

`make check-host` evaluates only the selected host and ensures its private module
is unlocked. `make check` evaluates all configurations and requires both private
modules. A fresh checkout needs either the matching decryption key or securely
transferred plaintext modules and receipts matching its encrypted files.

## Private configuration

### Unlock once, then work normally

This uses ordinary age on both macOS and Linux. There is no Keychain, GPG,
Touch ID plugin, background agent, or custom encryption binary to configure.

On a fresh checkout, restore the **existing matching private key** from your
backup to `~/.ssh/matteing-2026` (mode `0600`), or point `PRIVATE_IDENTITY` at its
location outside the checkout. A newly generated SSH key will not unlock these
files. The public key committed in `keys/sergio.pub` is not enough to decrypt.

Install Git and Bash, plus either [age](https://github.com/FiloSottile/age#installation)
or [Nix](https://nix.dev/install-nix). If age is absent, the helper runs the
flake's pinned age through Nix automatically; it does not require the host
configuration to be unlocked first. The age tool output supports Apple Silicon
and Intel Macs, and ARM64 and x86-64 Linux. On macOS, Apple's Command Line Tools
provide Git and Make. On Linux, use your distribution's packages for Git, Make,
and age, or install Nix. For the complete Mac setup, `make bootstrap` below
installs Nix before unlocking, so no separate age installation is necessary.
Age alone is enough to unlock and encrypt; formatting, evaluation, and rebuilds
require Nix. The repository commands enable the required Nix features themselves.

Then select the module explicitly; a new computer may not yet have the
configured hostname:

```console
git clone https://github.com/matteing/nix ~/nix
cd ~/nix
make unlock HOST=matteing-mbp
# Or, for the server module (from either macOS or Linux):
make unlock HOST=homelab
```

If Make is not installed, the equivalent is
`bash scripts/private-config unlock matteing-mbp` or
`bash scripts/private-config unlock homelab`. If using a key at another path,
prefix the command with `PRIVATE_IDENTITY=/external/path/to/existing-key`.
Enter its passphrase locally in the terminal when prompted.

Keep the decrypted `.local.nix` file **and** its `.local.state` receipt. Both
remain Git-ignored, mode `0600`, and persist across reboots. Subsequent checks,
builds, and edits reuse them without a key or a password prompt. After editing
and formatting, save the encrypted version with `make encrypt HOST=<host>`;
encryption needs only the public key and age, not the private key or passphrase.
The existing `make apps-unlock` / `make apps-encrypt` commands still work.

You decrypt again only when the local files are missing or incoming ciphertext
has changed. Pulling unrelated changes does not prompt. If both encrypted and
local versions changed, the helper stops for conflict resolution instead of
overwriting your work. Do not delete the local files between builds.

This protects what is published to Git, not the running machine: plaintext
remains on disk and enters the world-readable Nix store. The portable unlock
workflow does not make the complete machine profiles portable: the Mac profile
still targets an Apple Silicon Mac and the `sergio` account; `homelab` is a
specific x86-64 NixOS machine. Unlocking on Ubuntu, for example, does not install
or activate the NixOS profile.

### Files and everyday edits

Private configuration is encrypted with age for the SSH public key in
`keys/sergio.pub`. Each public loader imports a decrypted `.local.nix` module;
that module and its `.local.state` synchronization receipt are ignored by Git.

The Mac's `apps.nix.age` contains its application inventory, app-specific Dock
and preference settings, terminal profile, and app shell integrations. The
homelab's `network.nix.age` contains the Wi-Fi network name and a PSK reference.
The actual Wi-Fi secret remains in `/var/lib/wifi/wireless.conf`, outside the
repository and Nix store.

The default decryption identity is `~/.ssh/matteing-2026`. To use another matching
private key, set `PRIVATE_IDENTITY` to its path outside this repository:

```console
PRIVATE_IDENTITY=/path/outside/the/repo/private-key make private-unlock HOST=homelab
```

If the SSH key has a passphrase, age prompts for it in your terminal when
decryption is needed. It cannot use an already-unlocked SSH agent. Keep a backup
of the private key and its passphrase so the encrypted modules remain recoverable.
`APPS_IDENTITY` remains supported when `PRIVATE_IDENTITY` is unset.

For Mac edits, the original app commands remain available:

```console
make apps-unlock
nano hosts/matteing-mbp/apps.local.nix
make fmt
make apps-encrypt
```

For homelab network edits:

```console
make private-unlock HOST=homelab
nano hosts/homelab/network.local.nix
make fmt
make private-encrypt HOST=homelab
```

Commit the updated `.nix.age` file after encrypting. Local edits remain usable
for builds before encryption, but will not be included in Git. Encrypt again if
formatting or other edits change the local module. Keep the actual Wi-Fi PSK in
the runtime secret file even when editing the encrypted network module.

Builds, tests, switches, initial activation, and bootstrap run
`scripts/private-config ensure <host>` for the selected host. The helper also
accepts `encrypt` and `unlock`; its default host is `matteing-mbp`.
`scripts/apps` remains a wrapper for that Mac host. If age is not installed, the
helper uses `nix run path:<checkout>#age`, an output that works before either
private module is unlocked. Bootstrap installs Nix before unlocking.

The receipt records hashes of the ciphertext and decrypted module. Unlocking
preserves local edits when the ciphertext is unchanged. After pulling changed
ciphertext, it refreshes a clean local module. If both changed, it stops instead
of overwriting either version. To resolve that conflict, move the affected
`.local.nix` file outside the repository, run `make private-unlock HOST=<host>`,
merge your saved edits into the newly decrypted file, and run
`make private-encrypt HOST=<host>`. Keep the receipt with the checkout; a missing
receipt with existing plaintext also stops the helper so it cannot guess which
version is current.

Encryption uses `PRIVATE_RECIPIENTS_FILE`, then the legacy
`APPS_RECIPIENTS_FILE`, then `keys/sergio.pub`. The overrides name public
recipients files. After changing recipients, re-encrypt the affected modules and
verify that the new identity decrypts them before retiring the old key.

To keep the private key off the homelab, securely transfer both
`network.local.nix` and `network.local.state` from a trusted unlocked checkout
with the same `network.nix.age`. Place them in `hosts/homelab/` and restrict them
to mode `0600`. Matching files let host checks and rebuilds proceed without
decrypting. After a ciphertext update, transfer a freshly unlocked matching pair
again. Never commit the transferred plaintext or receipt.

Encryption conceals these modules in the shared source; Nix still copies the
decrypted modules into its world-readable store during evaluation. Keep private
keys and runtime credentials outside the entire checkout, including `.git`:
the repository's `path:` flake commands copy that directory into the store.
Any backup of earlier Git history belongs outside the checkout and must not be
committed with the new source snapshot.

Run the helper's isolated tests with temporary keys and fixture files:

```console
nix --extra-experimental-features 'nix-command flakes' shell path:.#age -c bash tests/apps-encryption.sh
```

With age, age-keygen, and ssh-keygen already in `PATH`, use `bash tests/apps-encryption.sh`.
These tests do not use the real private key or activate a system configuration.

The bootstrap harness also runs without installing Nix or activating macOS:

```console
bash tests/bootstrap-darwin.sh
```

The helper CI runs both harnesses on macOS and Ubuntu using only disposable
fixture keys. It does not decrypt this repository's private modules.

## macOS bootstrap

Restore the private key matching `keys/sergio.pub` to `~/.ssh/matteing-2026`
before bootstrap, or set `PRIVATE_IDENTITY` to its external location. Then install
Apple's Command Line Tools, clone, and bootstrap:

```console
xcode-select --install
git clone https://github.com/matteing/nix ~/nix
cd ~/nix
make bootstrap
```

`make bootstrap` selects `matteing-mbp` even before the new Mac has that hostname.
It unlocks as your normal user and runs system activation with sudo.
For unlock-only preparation without activation, use the commands above instead.

Open a new Zsh session after bootstrap, then install the Mac development
runtimes:

```console
mise install
```

## Install the homelab on bare metal

Boot the NixOS 26.05 minimal installer. First identify the disk and firmware
mode without changing anything:

```console
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
test -d /sys/firmware/efi && echo UEFI || echo BIOS
```

Partition and format the intended disk, then mount the root filesystem at
`/mnt`. For UEFI, mount the EFI System Partition at `/mnt/boot`. Disk commands
are intentionally not hardcoded here: using the wrong `/dev/...` value would
erase the wrong disk. Follow the [official NixOS installation
manual](https://nixos.org/manual/nixos/stable/#sec-installation-manual) and
continue below once the target filesystems are mounted.

Generate the hardware facts, then clone the public source and copy in the
generated hardware configuration. These clone instructions assume a public
repository and do not require GitHub authentication:

```console
sudo -i
nixos-generate-config --root /mnt
mkdir -p /mnt/home/sergio
nix-shell -p git gnumake
git clone https://github.com/matteing/nix /mnt/home/sergio/nix
cp /mnt/etc/nixos/hardware-configuration.nix \
  /mnt/home/sergio/nix/hosts/homelab/hardware-configuration.nix
```

Before installation, unlock the homelab network module. To avoid placing the
private key on this machine, use an authenticated encrypted transfer to copy
`network.local.nix` and `network.local.state` from a trusted unlocked checkout
into `/mnt/home/sergio/nix/hosts/homelab/`. Its `network.nix.age` must match the
source checkout. Set both transferred files to mode `0600`:

```console
chmod 600 /mnt/home/sergio/nix/hosts/homelab/network.local.nix \
  /mnt/home/sergio/nix/hosts/homelab/network.local.state
```

Alternatively, run `make private-unlock HOST=homelab` in the checkout with
`PRIVATE_IDENTITY` pointing to the matching key outside the checkout.

Restore the Wi-Fi runtime secret to `/mnt/var/lib/wifi/wireless.conf`, owned by
root with mode `0600`, matching the reference in your decrypted
`network.local.nix`. The actual secret must not be added to a Nix expression.
Confirm the network interface names in `hosts/homelab/default.nix` match the
hardware: Wi-Fi and the interface-specific SMB firewall rules use those names.

The checked-in homelab configuration already selects UEFI systemd-boot. Confirm
those settings are present in the host file:

```console
nano /mnt/home/sergio/nix/hosts/homelab/default.nix
```

For this EliteDesk, these two lines must remain enabled:

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = true;
```

If no edit is needed, press `Ctrl+X` to exit. If you change anything, press
`Ctrl+O`, then `Enter` to save, followed by `Ctrl+X`.

Then install this flake, set Sergio's local password, and give him ownership of
the checkout:

```console
nixos-install --flake path:/mnt/home/sergio/nix#homelab
nixos-enter --root /mnt -c 'passwd sergio'
nixos-enter --root /mnt -c 'chown -R sergio:users /home/sergio/nix'
reboot
```

After rebooting, authenticate Tailscale and verify the normal rebuild path:

```console
cd ~/nix
sudo tailscale up
make check-host
make switch
```

The homelab advertises its hostname over mDNS, so other machines on the same
LAN can connect without looking up its DHCP address:

```console
ssh sergio@homelab.local
```

Keep both state versions at `26.05`; they are compatibility markers, not
upgrade controls. SSH accepts only Sergio's committed public key, root SSH is
disabled, and `sudo` remains password-protected.

If this server already runs NixOS, skip installation: regenerate
`hardware-configuration.nix` if its hardware or disk layout changed, then run
`HOST=homelab make switch`.

### Optional: enable Secure Boot

Install and boot the ordinary UEFI configuration first. Leave UEFI enabled; if
the installer USB is rejected, temporarily disable only Secure Boot in the HP
firmware (`F10` at startup). Once the installed system boots, confirm that it is
using UEFI and systemd-boot:

```console
bootctl status
```

Then use [Lanzaboote](https://nix-community.github.io/lanzaboote/) to sign NixOS
boot generations with keys owned by this machine. This is optional and does not
belong in the base server configuration until it is being enabled.

1. Add the current stable Lanzaboote input to `flake.nix`:

   ```nix
   lanzaboote = {
     url = "github:nix-community/lanzaboote/v1.1.0";
     inputs.nixpkgs.follows = "nixpkgs-stable";
   };
   ```

2. Add its module to the `mkNixos` module list in `lib/mk-host.nix`:

   ```nix
   inputs.lanzaboote.nixosModules.lanzaboote
   ```

3. Change `hosts/homelab/default.nix` to accept `lib`, then add `sbctl` to its
   existing system packages and replace the bootloader setting with:

   ```nix
   { lib, ... }:

   {
     boot.loader.systemd-boot.enable = lib.mkForce false;
     boot.loader.efi.canTouchEfiVariables = true;
     boot.lanzaboote = {
       enable = true;
       pkiBundle = "/var/lib/sbctl";
     };
   }
   ```

   This replaces the existing `systemd-boot.enable = true` setting; do not keep
   both as normal definitions.

4. Create the signing keys, rebuild, and verify the signed EFI files before
   changing the firmware:

   ```console
   sudo sbctl create-keys
   HOST=homelab make switch
   sudo sbctl verify
   ```

   Back up `/var/lib/sbctl` to encrypted offline storage. It contains private
   signing keys: never commit it or copy it into the Nix store.

5. Reboot into the HP firmware with `F10`, open its Secure Boot configuration,
   and put Secure Boot into **Setup Mode**. Firmware wording varies. If offered,
   remove only the Platform Key; do **not** choose **Clear All Secure Boot
   Keys**, because that can also erase the forbidden-signature database (`dbx`).
   If this EliteDesk firmware cannot enter Setup Mode without clearing all
   databases, stop and check its exact BIOS revision's instructions rather than
   guessing.

6. Boot NixOS again, enroll the owner keys while retaining Microsoft's
   certificates for firmware OptionROM compatibility, then reboot:

   ```console
   sudo sbctl enroll-keys --microsoft
   reboot
   ```

7. Enable Secure Boot in the HP firmware if it did not become enabled during
   enrollment. After NixOS boots, both commands should report Secure Boot
   enabled in user mode:

   ```console
   bootctl status
   sudo sbctl status
   ```

Keep the installer USB available. Recovery is to disable Secure Boot in the HP
firmware, boot NixOS or the installer, and repair or re-enroll the keys. Also set
an HP firmware administrator password; otherwise someone with physical access
can simply disable Secure Boot. Secure Boot verifies the boot chain but does not
encrypt the disk—full-disk encryption is a separate installation decision. See
the [official NixOS Secure Boot overview](https://wiki.nixos.org/wiki/Secure_Boot)
and Lanzaboote's [preparation](https://nix-community.github.io/lanzaboote/getting-started/prepare-your-system.html)
and [key-enrollment](https://nix-community.github.io/lanzaboote/getting-started/enable-secure-boot.html)
guides before changing firmware keys.

## Public keys and secrets

Refresh the committed SSH public key with:

```console
make sync-ssh-key
```

This file is also the default encryption recipient for both private modules.
When rotating it, re-encrypt both modules as described above.

Only public keys belong in `keys/`. Do not put passwords,
tokens, private keys, or decrypted environment files in Nix expressions; they
can enter the world-readable Nix store. Back up mutable Docker data separately.

![hexley](http://www.hexley.com/images/hexley_450_pngs/hexley_pkg_450.png)
