# Contributing to Reeframe

Thanks for helping out. Bug reports, fixes and features are all welcome.

## Before you start

- For anything bigger than a small fix, open an issue first so we can agree
  on the approach.
- Security problems go through [SECURITY.md](SECURITY.md), not public issues.
- Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md).

## Contributor License Agreement

Every contributor signs the [Contributor License Agreement](CLA.md) once.
The CLA Assistant bot asks for it on your first pull request, and the pull
request can't be merged until it's signed. You keep the copyright to your
work. The CLA lets the project use your contribution under the Apache
License 2.0 and under other licenses in the future.

## Making a change

1. Fork the repository and create a branch from `main`, for example
   `fix/tile-reconnect` or `feat/camera-groups`.
2. Build and run the tests as described in the [README](README.md).
3. Add or update a test for what you changed when the existing test setup
   makes that practical. Tests live in `tests/qml/`.
4. Keep commits small and focused. Commit messages are one imperative line,
   for example `Retry a failed relay request with backoff`.
5. Open a pull request against `main` and describe what changed and why. CI
   must pass before it can be merged.

## Code style

- C++ is formatted with the repository's `.clang-format`.
- Every source file starts with an SPDX header:

  ```
  // SPDX-FileCopyrightText: 2026 Mohammad Armoun
  // SPDX-License-Identifier: Apache-2.0
  ```

  New files you add may use your own name in the copyright line.
- Comments explain why the code is the way it is, not what it obviously
  does. Don't describe the history of a change in comments; that belongs in
  the commit message.
