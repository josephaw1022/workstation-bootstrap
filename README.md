# workstation-bootstrap

Pinned, upgrade-aware CLI setup for a personal Linux/macOS workstation.

```bash
./setup-workstation.sh            # all tools
./setup-workstation.sh kubectl k9s  # specific tools
K9S_VERSION=0.52.0 ./setup-workstation.sh k9s  # override a pin
```

- Compares installed vs pinned version; installs or upgrades on mismatch.
- Installs to `~/.local/bin` (override with `BIN_DIR`).
- Pins are updated by Renovate via `# renovate:` comments in the script.
