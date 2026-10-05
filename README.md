# Reeframe VMS Desktop Client

Reeframe is a desktop client for the Reeframe video management system. It is
written in C++17 and Qt 6 (QML). It is developed and tested on Linux, and the
build also targets Windows and macOS.

With it you can:

- connect to one or more Reeframe sites, either directly or through a
  Coordinator
- add and manage cameras, and watch them live in a resizable tile matrix
- browse and play back recordings on a multi-day timeline with event markers
- build automation pipelines in a graph editor (triggers, transcode,
  watermark, snapshots, notifications, and uploads to SMB, S3, Slack,
  Telegram or email) and follow their runs

The client talks to a Reeframe backend over HTTP. The backend is not public
yet, so you can build and test the client on its own, but you need a running
backend to use it.

## Building

Requirements:

- Qt 6.8 or newer, with the Qt Multimedia module
- CMake 3.22 or newer
- A C++17 compiler (GCC, Clang or MSVC)
- On Linux: OpenGL and xkbcommon development packages (for example
  `libgl1-mesa-dev libxkbcommon-dev` on Debian and Ubuntu)

```sh
cmake -S . -B build -DCMAKE_PREFIX_PATH=/path/to/Qt/6.8.x/gcc_64
cmake --build build -j
./build/reeframe-fe
```

## Running the tests

The tests use Qt Quick Test and run without a display:

```sh
cmake --build build --target reeframe-fe-qmltests -j
QT_QPA_PLATFORM=offscreen ./build/reeframe-fe-qmltests
```

## Diagnostics

Live view reconnect decisions are logged under the `reeframe.liveview`
category. Enable them with:

```sh
QT_LOGGING_RULES="reeframe.liveview.debug=true" ./build/reeframe-fe
```

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md)
first. You will be asked to sign the [Contributor License Agreement](CLA.md)
on your first pull request. This project follows the
[Code of Conduct](CODE_OF_CONDUCT.md).

To report a security issue, see [SECURITY.md](SECURITY.md). Please don't open
a public issue for it.

## License

Copyright 2026 Mohammad Armoun.

The source code is licensed under the [Apache License 2.0](LICENSE).
Third-party components are listed in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The Reeframe name and logo
are not covered by the code license; see [TRADEMARKS.md](TRADEMARKS.md).
