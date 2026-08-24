# Live Church Translation Privacy Policy

Effective: August 24, 2026

Live Church Translation processes microphone audio, imported audio, transcripts, and live
translations locally on the user's Mac. Imported audio is transcribed in its selected source
language and is not translated. The app does not create an account, include advertising or
tracking, or send meeting content to the developer or an AI service.

## Data stored on the Mac

When a user starts a meeting, the app saves the complete audio recording, recognized
source text, timestamps, and source-correction audit in the app's sandboxed Application
Support container. Translations remain available to live readers but are not retained in
the session library. Imported audio is decoded and transcribed locally without entering the
translation pipeline. Model
weights are sealed into the signed release app, verified by size and SHA-256 before use,
and loaded locally without a first-run download. Meeting content remains until the user
deletes the meeting or removes the app's data.

When this storage policy is first applied, the app rewrites legacy app-managed transcript
files to remove previously retained translation text and review metadata. Copies outside the
app container, including user exports, backups, and filesystem snapshots, remain under their
owner's control.

## Local network sharing

Local sharing is off by default. If the Mac user enables it, explicitly paired devices on
the same trusted network receive live source text and translations. Audio files are not
sent to audience devices. The current local connection uses HTTP and WebSocket and does
not protect captions from an observer on an untrusted network.

## Diagnostics

Operational diagnostics remain on the Mac and avoid retaining raw meeting text or audio.
The app does not automatically transmit analytics or crash reports to the developer.

## User control

The user can stop recording at any time, delete an individual meeting and all associated
local artifacts, disable local sharing, and revoke paired devices. Native and browser readers may hide
passage timestamps independently, but hiding them changes presentation only and does not delete stored
timing. A host is responsible for informing participants and obtaining any consent required by local
recording laws.

## Changes and contact

Any future cloud processing will be opt-in and will identify the receiving provider before
data leaves the Mac. Material policy changes will be reflected here before release.

Privacy contact: jerryyanshuo@outlook.com
