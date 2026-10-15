# DeepSeek Harness (`de/deepseek-harness`)

`pkgs/by-name/de/deepseek-harness/package.nix` builds the `dsh` CLI from the
official [deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)
source. It was migrated from the `dotnix` repository (`pkgs/deepseek-harness`),
which now consumes it from this flake.

```sh
nix build .#de/deepseek-harness
nix run .#de/deepseek-harness -- --version
```

Only **x86_64-linux** is packaged and tested.

## Source tracking

The package follows upstream `master` with a pinned commit (`src.rev`), so its
version can be an unreleased source version taken from
`apps/cli/package.json`. `share/deepseek-harness/source.json` inside the output
and the `sourceRevision` passthru attribute identify the pinned revision, which
is also passed to the build as `DSH_CLIENT_COMMIT_HASH` (GitHub archives omit
`.git`).

The output keeps the complete built workspace and dependencies to preserve
upstream's built-in profile resolution through `apps/cli`. It is approximately
2.3 GB; it is not a trimmed production dependency closure.

## Toolchain and patches

- Node.js 24 (`nodejs_24`) and pnpm 11 (`pnpm_11`, overridden to the same Node)
  from this flake's `nixpkgs` input. `pnpm_config_pm_on_fail=ignore` keeps
  pnpm from downloading upstream's `packageManager` version during the build;
  it is not exported at runtime.
- `node-pty` is rebuilt with `node-gyp` against Nix's Node headers; the native
  launcher is built with the musl toolchain (`pkgsMusl.stdenv.cc`) in place of
  `musl-gcc`.
- The default Bash shell is replaced with Nix's Bash. Node, pnpm, Bash and Git
  are on the wrapper's runtime `PATH`, and `dsh` runs with
  `--expose-internals`.
- `exposed-internals.patch` adapts upstream's loader to Nix-built Node: the
  native builtin getter decoder fails with the pinned Node build, so resolution
  prefers Node's actual `--expose-internals` singleton modules while keeping
  native fallbacks and interface checks. HMR obtains the same internal binding
  through `internal/test/binding`; Node's warning "These APIs are for internal
  testing only" can therefore appear during cache invalidation. Node internal
  APIs can change, so source or toolchain updates must repeat loader, HMR and
  plugin smoke checks (see `tests/dsh-package-smoke-test.sh` in `dotnix`).

## Updating

The scheduled update workflow runs `nix-update` for this package with
`--version=branch`, which moves `src` to the latest `master` commit and refreshes
both the source and the pnpm dependency hashes. To update manually:

```sh
nix run nixpkgs#nix-update -- --flake de/deepseek-harness --version=branch
```

Then set `version` to the value in upstream's `apps/cli/package.json` at the
new `rev` if you prefer the upstream version string, and verify:

```sh
nix build .#de/deepseek-harness.pnpmDeps --no-link
nix build .#de/deepseek-harness --no-link
nix flake check
```

If the pnpm dependency hash needs to be rediscovered, temporarily set the
`hash` in `fetchPnpmDeps` to `""`, build `.#de/deepseek-harness.pnpmDeps`, and
copy the reported **got** hash. Never leave an empty or placeholder hash
committed. A source update may require recipe changes when upstream's build,
native ABI or Node/pnpm requirements change; bumping this flake's `nixpkgs`
input also changes the toolchain and can change the pnpm dependency hash.
