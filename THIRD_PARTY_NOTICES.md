# Third-party notices

Reeframe uses the following third-party software and assets. Each is
distributed under its own license, not under the Apache License that covers
the rest of this repository.

## Qt 6

- Website: https://www.qt.io
- License: GNU Lesser General Public License v3 (LGPLv3)
- Modules used: Core, Gui, Widgets, Quick, QuickControls2, Qml, Network,
  Multimedia, Sql, Svg, Test, QuickTest. Linguist tools are used at build
  time only.

Reeframe links to Qt dynamically and does not modify it. Anyone distributing
a build of Reeframe must comply with the LGPLv3: ship the Qt license texts,
keep the dynamic linking, and allow users to replace the Qt libraries with a
compatible version. See https://www.qt.io/licensing.

Qt Multimedia plays streams through its FFmpeg backend. The FFmpeg libraries
shipped with Qt are licensed under the LGPL v2.1 or later. See
https://ffmpeg.org/legal.html.

Qt is not included in this repository.

## Tabler Icons

- Website: https://tabler.io/icons
- License: MIT
- Copyright (c) 2020-2026 Paweł Kuna
- Files: `assets/icons/tabler/*.svg`

The full license text is in `assets/icons/tabler/LICENSE`.
