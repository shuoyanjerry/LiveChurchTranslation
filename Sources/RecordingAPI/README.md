# RecordingAPI

Contracts and metadata for crash-safe, full-session audio recording. Finalization
errors are recoverable through `repairInterruptedRecording`; callers discard only
an empty recording or an explicit user cancellation.
