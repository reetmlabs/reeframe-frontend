# Changelog

## v0.2.0

First public release. Version numbers match the Reeframe backend this client
is built against.

### Sites and sign-in

- Connect to sites directly (local mode, one site) or through one or more
  Coordinator connections (Coordinator mode, all sites the Coordinator lists).
- Sign-in, token refresh, and a Coordinator sign-in dialog.
- Backend health is polled every 5 seconds and shown in the top bar. A poll
  that gets no answer within 3 seconds counts as the backend being down.

### Cameras

- Add, edit, duplicate and delete cameras, with undo for deletes.
- Search, location field, thumbnails, and recording start and stop.
- The camera list and the selected tile stay in sync.

### Live view

- Tile matrix with drag and drop, resizable tiles that push their
  neighbours, and saved matrix profiles.
- Full-screen camera view that upgrades from the sub stream to the main
  stream.
- A tile that stops receiving frames for 5 seconds, or whose stream fails,
  shows "Connecting..." and requests a fresh relay from the backend. Failed
  relay requests are retried after 2, 4 and 8 seconds, then every 10
  seconds. Tiles also request fresh relays as soon as the backend recovers.
- Reconnect decisions are logged under the `reeframe.liveview` logging
  category.

### Recordings and playback

- Recordings panel with per-day summaries that refresh automatically.
- Multi-day timeline with zoom, pan, seeking and event markers.
- Playback of recorded footage in tiles and in full-screen view.

### Pipelines

- Pipeline list with validation counts and an enable toggle that stays off
  while a pipeline has errors.
- Graph editor with node palette, Fork nodes with several outputs, wheel
  and keyboard zoom and pan, and a problems panel with badges on the
  affected nodes.
- Configuration panels for triggers and events, transcode, watermark,
  encrypt, compress, snapshot, merge clips, notifications, and transports
  (SMB, S3 including custom endpoints, Slack, Telegram, email).
- Run history and run details that update live, with copyable errors and
  output.

### Sources and destinations

- Create, edit and delete sources and destinations, with undo for deletes.

### General

- Global search, undo for destructive actions, toast messages, and a system
  tray icon.
- Settings for camera overlays and an About page listing third-party
  licenses.
- English and partial German translations.
