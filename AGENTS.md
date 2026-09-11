# Working on this public configuration

For app or encrypted-module changes, use the `nix-private-config` skill when
available (personal installation: `~/.codex/skills/nix-private-config/SKILL.md`).
The repository's `README.md` documents the workflow if the skill is unavailable.

Keep the simple age workflow: decrypt once per checkout/ciphertext version and
retain ignored plaintext plus its receipt across builds and reboots. Fresh-machine
commands must select HOST explicitly. Do not introduce Keychain, GPG, native
helpers, or a key cache unless the user requests a different design.

- Mac apps, app-specific preferences, Dock entries, terminal settings, and shell
  integrations belong in ignored `hosts/matteing-mbp/apps.local.nix`, not public
  loaders or other public modules. Run `make apps-unlock` before editing.
- Homelab private networking belongs in ignored
  `hosts/homelab/network.local.nix`. Run `make private-unlock HOST=homelab`
  before editing. Actual credentials stay in the runtime secret file outside Nix.
- Format and evaluate the affected host with `make check-host HOST=<host>`.
  Then run `make apps-encrypt` or `make private-encrypt HOST=homelab` after the
  final plaintext edit. Confirm the receipt hashes match the final files.
  `make fmt` can change both private modules: do not leave either unsaved.
- Commit only reviewed public changes and the updated `.nix.age` ciphertext.
  Keep `.local.nix` and `.local.state` ignored and untracked. Do not disclose
  private app/network details in public docs, tests, commits, or PR descriptions.
- Preserve conflict receipts and local edits. Follow the helper's recovery
  instructions using backups outside the checkout; never bypass its checks.
- Use the repository's `path:` flake commands so ignored modules are included.
  The decrypted source enters the world-readable Nix store. Never put private
  keys, passphrases, runtime secrets, or old-history backups inside the checkout,
  including `.git` and ignored paths.
- An app edit does not authorize system activation, publication, key changes, or
  history rewriting. NixOS `make test` activates a configuration too.
