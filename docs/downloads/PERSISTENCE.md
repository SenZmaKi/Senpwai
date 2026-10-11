# Download recovery

The download worker owns the durable queue and transfer state. The UI owns
source resolution, including browser-backed requests. Neither saved UI byte
counts nor payload length authorize byte reuse.

## Storage and lifecycle

- `state/downloads.json`: versioned jobs, stable item/batch IDs, queue order,
  user pause intent, retry budgets, refresh intent, and seeding accounting.
- `state/download_recovery/`: per-job native resume data and HTTP checkpoints.
  Filenames use SHA-256 of the job ID rather than untrusted source names.
- HTTP payloads use `<destination>.senpwai-part` until completion. Checkpoints
  describe ranges and SHA-256 blocks, never progress inferred from allocation.
- JSON saves are serialized, flushed to a temporary file, and renamed over the
  destination. A prior snapshot is retained as `.bak`. Malformed JSON is
  quarantined. Rejected queue records preserve a separate original snapshot.
- An exclusive queue file lock prevents another process owning its state.
- Checkpoints run every five seconds and on pause/shutdown. HTTP commits flush
  payload writes before recording their byte ranges. Lost uncommitted writes
  are downloaded again. Completed HTTP checkpoints precede final publication,
  allowing recovery across the rename/queue-save crash window.
- Normal desktop exits await worker shutdown. Android's foreground worker can
  outlive the UI and restores saved network settings before native startup.
  Updating the app checkpoints downloads instead of cancelling them.

## Recovery policy

User-paused, completed, cancelled, failed, and needs-attention jobs preserve
that intent. Other unfinished jobs return to the scheduler with their stable
IDs and destination paths. Only the active batch consumes download slots;
user-paused and needs-attention jobs do not prevent later batches progressing.

Torrent jobs restore native resume data with metadata, file selection and
renames. Rejected resume data falls back to native checking of retained files.
Native duplicate-torrent rejection prevents independent jobs fighting over
one handle's priorities. Torrent seeding time and upload accounting persist.

HTTP jobs first try cached access. They reuse committed bytes only if the probe
returns the same final resource URI, size, and strong ETag with range support,
and all local block checksums verify. ETags from different resource URIs do not
establish identity. Otherwise the transfer starts at zero with an explanation.
Without a strong validator a transfer uses one connection; it cannot safely
reuse bytes after reconnecting. `206`, range bounds, representation identity,
encoding and body length are checked before treating a response as valid.

Expired access requests trigger a bounded refresh of the exact saved source
selection. AnimePahe refresh uses a stable anime ID plus selected filename,
audio and resolution. TokyoInsider refresh matches the selected variant on
its original anime/episode page. AnimeHeaven has one episode file and validates
its original source filename when supplied. Refresh never reruns current user
preferences or silently picks a different release. Refreshed access may resume
the job while restarting its bytes if representation identity is insufficient.

Automatic HTTP retries use 4/8/16-second backoff and a persisted three-retry
budget. Source requests have bounded cancellation; network transfers have
connect/receive timeouts. Exhaustion, missing selections or required source
interaction produce “Needs attention”, preserve partial data, and expose Retry.
Pause/cancel invalidate stale refresh attempts. Failed callbacks cannot restart
cancelled jobs. Cancellation is saved before deleting owned partial data.

## Validation boundary

Static analysis is required. Runtime restart and source behavior remain separate
claims and require explicit testing authorization under AGENTS.md.

When authorized, validate:

1. Torrent close/reopen and force termination with the original seed offline:
   prove retained verified reads, selected files, renames and paused intent.
2. HTTP multi-range interruption: prove byte-for-byte final content and unchanged
   range geometry even if connection-count settings changed between launches.
3. Expired signed URL: refresh the exact selection; changed URL/ETag/size causes
   a clean byte restart, with no mixed representations.
4. Weak/missing ETags, ignored ranges (`200`), `416`, truncated bodies, HTML gates,
   changed encodings, damaged local blocks and missing/truncated partial files.
5. Termination before/after checkpoint rename and final publication; corrupt queue
   recovery, one damaged record among healthy jobs, disk-full and permissions.
6. Pause/cancel during probe, local verification, refresh, backoff and publication;
   reorder during recovery; no exceeded slots or stale writes.
7. Android service restart/reattachment, persisted VPN/proxy policy before any
   traffic, and UI-unavailable source refresh; update/restart retains jobs.

Limitations: restart persistence cannot recover downloads created before this
feature was installed. Some refreshed HTTP links require restarting bytes even
when they serve the same episode. Source interaction still requires an available
UI session; a background-only worker retains the job if it cannot obtain access.
