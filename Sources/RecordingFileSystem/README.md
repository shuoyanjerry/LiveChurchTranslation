# RecordingFileSystem

Private PCM16 CAF persistence with atomic publication and interrupted-file repair.
An fsynced private activity marker spans begin through publication. Finish, explicit
discard, and successful recovery clear it; recovery also handles crashes before the
first frame and after the final file was renamed but before directory synchronization.
