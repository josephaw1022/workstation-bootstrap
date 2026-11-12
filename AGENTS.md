# Agent Instructions

Single-script repo: `setup-workstation.sh` installs pinned CLI tools.

- Each tool has a pin in `PIN`, plus `ver_<tool>` and `install_<tool>`. Tools without a pin use `present_<tool>`.
- New pinned tool: add the `: "${X_VERSION:=...}" # renovate: datasource=... depName=...` line, a `PIN` entry, `ver_`/`install_` functions, and add it to `TOOLS_DEFAULT`.
- Keep the `# renovate:` comment format intact; `renovate.json` parses it.
- Use `local` for loop variables in functions (`t` is global in `run_tool`).
- Run `bash -n setup-workstation.sh` before committing. Test installs with a throwaway `HOME`.
- Keep comments one-line and docs short.
