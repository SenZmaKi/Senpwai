# Windows performance profiling

Use a profile build, because debug compilation and console output can dominate
the results:

```powershell
flutter run -d windows --profile
```

Open DevTools from the URL printed by Flutter, select **Performance**, enable
CPU profiling, then record these scenarios separately:

1. Open an anime preview and wait until all sources finish loading.
2. Open Downloads while an HTTP or torrent download is actively progressing.

Stop recording immediately after each stall. Export the timeline JSON so runs
can be compared after each optimization.

## Anime preview labels

- `anime_preview.initialize`: total page background initialization.
- `anime_preview.scan_owned_episodes`: directory enumeration and filename
  parsing used to detect already-downloaded episodes.
- `anime_sources.resolve_all`: total source-discovery latency.
- `anime_sources.animepahe`, `anime_sources.tokyoinsider`, and
  `anime_sources.nyaa`: individual source latency.
- `nyaa.parse_html`: HTML DOM construction for one response.
- `nyaa.parse_results`: row parsing, including the current per-row logging.

`anime_preview.scan_owned_episodes` should now appear only after a debounced
filesystem event, a folder change, initial page setup, or app resume. It should
not repeat every three seconds while the folder is idle. If it is still long,
move bulk filename parsing outside the UI isolate. If `nyaa.parse_results` is
also long, remove its per-row `aTags` and size logs. Network waits appear as gaps
and do not make Windows mark the app as not responding by themselves.

## Downloads labels

- `downloads.worker_state_rate`: state publications per second in the download
  isolate. `unitsPerSecond` is queue items serialized per second.
- `downloads.encode_state`: complete queue serialization in the worker.
- `downloads.main_isolate_state_rate`: messages handled per second by the UI
  isolate. `unitsPerSecond` is queue items decoded per second.
- `downloads.decode_state`: complete queue decoding on the UI isolate.

HTTP progress currently publishes state once for every received chunk. A high
`eventsPerSecond` confirms that progress should be sampled or coalesced (for
example, 4–10 UI updates per second), while status transitions remain immediate.
The Downloads page also watches the complete manager state, so every message
rebuilds the header, metrics, queue preview, and every visible row. After
coalescing, use Riverpod selectors or per-item providers to limit progress
rebuilds to the affected row and aggregate metrics.

Inspect every frame over 16.7 ms in the frame chart. The CPU flame chart and the
labels above distinguish Dart work from raster work. Also capture a 15–30 second
idle recording on Downloads: it should have no sustained state-update activity
while downloads are paused.
