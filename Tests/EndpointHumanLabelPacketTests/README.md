# Endpoint human-label packet

This private QA workflow never uploads audio, runs a model, or creates an automatic label.
It binds the frozen 84-event plan to exact source-WAV identities and absolute sample ranges,
then writes randomized reviewer audio and a separate sealed identity map.

This packet covers only the frozen six-clip public Scripture Manifest V2. It is challenger
calibration, not the required release set of at least 12 sermons, 8 hours, and 6 speakers.

Materialize the packet:

```sh
python3 Scripts/build_endpoint_human_labels.py
```

Start one independent reviewer:

```sh
python3 Scripts/review_endpoint_human_labels.py --annotator REVIEWER_A
```

Run the deterministic, cardinality, range, separation, hash, and permission checks:

```sh
python3 -m unittest discover -s Tests/EndpointHumanLabelPacketTests -p 'test_*.py' -v
```

The generated packet stays below `.artifacts/`, which is gitignored. Packet directories are
`0700`; audio, manifests, the sealed map, and reviewer label JSON are `0600`. Reviewer-facing
files contain no source ID, stratum, boundary reason, proxy class, model score, transcript, or
reference text. Human accuracy must not be reported until two independent labels and their
adjudication exist.
