# SQLite for History, with image data as files on disk

History lives in SQLite, so deleting and evicting Clips (CB-4, CB-5) are simple queries. Large image data is stored as files beside the database, with metadata and previews in SQLite, to keep the database small. Deleting a Clip must remove both, so startup sweeps for orphaned files left by a crash between the two steps.

## Considered Options

- A plain file (JSON or similar): rejected, since eviction and multi-delete would need hand-rolled logic.
- Image bytes as SQLite BLOBs: rejected to keep the database small and fast to open.
