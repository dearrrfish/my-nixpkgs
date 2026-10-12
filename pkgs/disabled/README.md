# Disabled packages

Packages in this directory are excluded from the flake's available packages
and the default overlay because only `pkgs/by-name` is discovered automatically.

`nanobot` is temporarily disabled: its 0.3.5 source no longer includes the Node
bridge expected by the current package definition. The repair in
[PR #9](https://github.com/dearrrfish/my-nixpkgs/pull/9) is deferred while its
filelock dependency fails an asynchronous lock test in CI.

Restore nanobot to `pkgs/by-name/na/nanobot` after its packaging and CI pass.
