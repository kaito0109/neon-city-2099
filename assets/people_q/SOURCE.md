# Character assets — source and licence

The human characters in `opt/` come from the **Quaternius Ultimate
Animated Character Pack** (52 rigged characters sharing one skeleton and
a 24-clip animation set), by Quaternius — https://quaternius.com

- Licence: **CC0 1.0 / Quaternius Asset Licence** — free for personal,
  educational and commercial projects, no attribution required. The
  assets themselves may not be resold or redistributed as a standalone
  asset pack.
- Files were obtained as individual GLBs via Poly Pizza (creator page:
  poly.pizza/u/Quaternius) and from the pack's official Google Drive
  mirror listing; the sunrise-farm project manifest independently
  documents the same Poly Pizza files as CC0.
- Local processing (Blender, `blender/trim_chars.py`): animation set
  trimmed to Idle, Idle_Neutral, Walk, Run, Wave, Interact, Death,
  HitRecieve, Roll (WomanCasual: her Female_* equivalents) and keyframe
  sampling halved, to keep the web build's download size sane.
- WomanCasual uses an older HumanArmature rig (31 bones) and a native
  scale ~2.7x the others; `people.gd` compensates with scale 0.37.

An earlier candidate set (Gobkit free human packs, also CC0) was
rejected for this project: the models are chibi figurines (~2 heads
tall) that clash with the city's look. Those files live outside the
project in the local asset library only.
