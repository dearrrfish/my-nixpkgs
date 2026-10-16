# AGENTS.md

Instructions for coding agents working in this repository. User-level safety,
worktree, and interaction rules still apply. Keep changes focused and preserve
unrelated work in the checkout.

## Repository map

This is a custom package flake built with flake-parts, not a checkout of Nixpkgs.
Use its flake outputs and modules rather than assuming upstream Nixpkgs tooling
or paths exist here.

- `flake.nix` and `flake.lock`: inputs and their pinned revisions.

- `flake/pkgs-by-name.nix`: automatic package discovery through
  `pkgs-by-name-for-flake-parts`.

- `pkgs/by-name/<shard>/<name>/package.nix`: active package definitions; `<shard>`
  is the lowercased first two characters of `<name>`.

- `flake/pkgs-all.nix`: explicit package bindings when discovery is insufficient.

- `flake/overlay.nix`: exposes the flake packages under `pkgs.local` in the
  default overlay. Preserve this public interface.

- `flake/systems.nix`: supported flake systems; individual packages may support
  fewer systems.

- `flake/formatter.nix`: treefmt configuration, including nixfmt, deadnix,
  statix, mdformat, jsonfmt, and yamlfmt.

- `pkgs/disabled/`: packages excluded from automatic discovery. Read its README
  before restoring a package.

- `.github/workflows/ci.yml`: flake checks and package builds on `x86_64-linux`.

- `.github/workflows/update.yml`: scheduled package updates using nix-update.

- `flake/exports.nix`: explicit consumer module outputs; never recursively import
  consumer modules through the flake-parts infrastructure tree.

- `modules/home-manager/`: reusable HM modules, including `programs.askhuman`.

- `modules/nixos/`: system-module aggregation root (currently empty).

- `tests/`: real module evaluation and isolated runtime/activation fixtures.

- `docs/modules/askhuman-options.md`: generated option reference; regenerate with
  `nix run .#generate-module-docs` after public option changes.

Consumer modules must not depend on host-specific helpers or an obligatory
consumer overlay. Preserve existing slash package keys and `pkgs.local`.

## Package layout and scope

- Put new packages in `pkgs/by-name`, with a `package.nix` function accepting
  explicit dependencies as arguments, suitable for `callPackage`.
- Keep patches and auxiliary files beside the derivation. Pass dependencies as
  arguments rather than importing another package's definition directly.
- Do not add `default.nix` or manual bindings for an automatically discovered
  package. Do not edit generated files in the Nix store.
- Prefer existing dependencies from the pinned Nixpkgs. Check whether a suitable
  upstream package exists before duplicating it; use an override when that is
  simpler to maintain.
- Treat input updates, package updates, and unrelated cleanup as separate changes.
  Do not update `flake.lock` merely to make a package build.

## Derivation conventions

- Use `pname` and `version`. Prefer `mkDerivation (finalAttrs: { ... })` when
  attributes refer to each other; avoid unnecessary `rec` and broad `with` scopes.
- Use the appropriate language builder and its dependency-fetching support rather
  than hand-written package-manager installs. Use `stdenvNoCC` when no compiler
  is needed.
- Put build-time tools and setup hooks in `nativeBuildInputs`, linked libraries
  in `buildInputs`, and test tools in `nativeCheckInputs`. Propagate dependencies
  only when consumers actually need them.
- Prefer standard phases and hooks. When replacing a phase, call its pre/post
  hooks, such as `runHook preInstall` and `runHook postInstall`.
- Use patches or `substituteInPlace --replace-fail` for source changes. Explain
  non-obvious patches, compatibility workarounds, and disabled tests with their
  reason and an upstream reference when available.
- Use wrappers and setup hooks for runtime paths and environment variables.
  Declare libraries loaded via `dlopen` explicitly where the relevant hook
  requires it; a successful link does not prove runtime loading works.
- Keep Nix code in the configured nixfmt style: two-space indentation, readable
  lists, and indented strings for shell fragments. Let treefmt decide formatting.

## Sources, hashes, and metadata

- Verify the upstream release and license. Prefer source builds when practical;
  explain the choice when packaging prebuilt artifacts.
- Pin sources to a release tag or immutable commit and a fixed content hash.
  Never fetch a moving branch without pinning its revision.
- Prefer `hash = "sha256-..."` in SRI form. Use `lib.fakeHash` temporarily to obtain
  the actual hash from a fetch failure; never leave fake hashes in finished work.
  Confirm a mismatch refers to the intended source or dependency before copying it.
- Keep builds independent of network access and host state. Fetch dependencies
  through Nix fetchers and language builders; do not add build-time `npm install`,
  `pip install`, or `curl` downloads that bypass fixed-output fetching.
- Do not introduce runtime dependency installation as a packaging shortcut.
  Document any unavoidable upstream runtime downloads, such as model data.
- Include `meta.description`, `meta.homepage`, and the verified `meta.license`.
  Set `meta.mainProgram` for executable packages to the actual installed binary;
  omit it for packages without a main executable.
- Set `meta.platforms` to the supported systems, especially for binary releases.
  Keep per-system URLs, hashes, and platform metadata consistent. Do not use
  `meta.broken` or broaden platforms to hide a build failure.
- Do not invent maintainers or add an empty maintainer list as boilerplate.

## Adding or updating a package

1. Inspect the current derivation, upstream release notes, and a similar package
   in the pinned Nixpkgs. Preserve existing features and overrides unless the task
   calls for changing them.
1. Update the version, source revision, source hash, and any language dependency
   hashes or vendored lockfiles together. Review patches for applicability and
   update every supported binary artifact when using a platform map.
1. Discover the actual flake attribute with `nix flake show --json`; do not assume
   it matches the directory name or copy upstream `nix-build -A` commands here.
1. For new files, remember that Git-backed flakes exclude untracked files. Review
   and stage only intended new package files before evaluation, or use an explicit
   `path:.` flake reference for local validation without changing the index.
1. Build and smoke-test the affected package as described below. Inspect the final
   diff for accidental lockfile changes, unrelated formatting, or fake hashes.

For input maintenance, use `nix flake update <input>` for a targeted update and
`nix flake update` only when updating all inputs is in scope. Review the lockfile
and validate affected outputs. Do not change CI automation incidentally.

## Validation

Run commands from the repository root. Replace `<attribute>` with the exact
attribute discovered above; quote the whole flake reference if it contains shell
metacharacters.

```sh
# Format only files changed by the task.
nix fmt -- AGENTS.md
# For a package change, pass its changed file paths instead.

# Build the affected package and show build logs.
nix build '.#<attribute>' --no-link --print-build-logs

# Run the configured flake checks (also used by CI).
nix flake check --print-build-logs
```

- Documentation-only changes need formatting and diff review, not package builds.
- For module changes, build `checks.x86_64-linux.module-eval`,
  `checks.x86_64-linux.askhuman-reconcile`, and
  `checks.x86_64-linux.askhuman-activation`. These run isolated fixtures; never
  execute HM activation against the real user home as an unattended test.
- Build `checks.x86_64-linux.module-docs` after regenerating the option reference.
  Evaluate `checks.<system>.module-eval.drvPath` for every supported system;
  distinguish evaluation from native execution.
- While new files are untracked, use `path:.` and
  `nix run path:.#formatter.x86_64-linux -- <changed-files>` so Git flake filtering
  does not hide the new infrastructure.
- For executable changes, run a safe, upstream-supported smoke test, such as
  `nix run '.#<attribute>' -- --version`. Do not assume every program supports
  `--help`, or launch a service or GUI as an unattended smoke test.
- Preserve upstream tests. If tests must be disabled, explain the specific failure;
  do not disable them simply to obtain a successful build.
- Add focused install checks or `passthru.tests` where they catch meaningful
  regressions. Build relevant passthru tests explicitly; do not assume
  `nix flake check` runs every package's tests or builds every package output.
- For shared module or input changes, build affected packages on the current
  supported system. Cross-platform evaluation does not verify a build on another
  platform; report which systems were actually tested. CI covers `x86_64-linux`.
- Report the commands run and their results. If validation is blocked, state why
  and add a nearby `# VERIFY: <specific remaining check>` comment to the affected
  code (an HTML comment in Markdown). Never claim an unrun check passed.

## Commits and handoff

Use Conventional Commits for every commit, retaining this repository's convention
rather than copying upstream Nixpkgs commit subjects:

- `feat(pkgs): add <package-name>`
- `fix(pkgs): update <package-name> to <version>`
- `chore(flake): update inputs`
- `docs: improve agent instructions`

Do not commit broken builds, credentials, or unrelated user changes. In the
handoff, describe the changed behavior, validation results, and any remaining
platform or runtime checks.

## References

Use the pinned Nixpkgs source for APIs available to this flake. Upstream guidance
may describe newer APIs or tooling specific to the Nixpkgs repository:

- [Nixpkgs package contribution guide](https://github.com/NixOS/nixpkgs/blob/master/pkgs/README.md)
- [Nixpkgs by-name conventions](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/README.md)
- [Nixpkgs manual](https://nixos.org/manual/nixpkgs/unstable/)
