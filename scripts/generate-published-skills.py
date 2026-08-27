#!/usr/bin/env python3
"""
Generate the published (de-identified) skills from the internal source.

WHY THIS EXISTS. c-ship was hand-de-identified once, which FORKED it. The two
copies then drifted: on 2026-08-27 the published 0.1.5 was 14,246 bytes while
this repo's source was 18,553 — and both claimed to be 0.1.5, so `/plugin update`
correctly reported "already at latest" and never re-fetched. Same version number,
different content. A hand-sync is a fork with extra steps.

Run this instead of editing the published copy by hand:
    python3 scripts/generate-published-skills.py --source <path-to-internal-repo>

The internal copy is the source of truth: it is where every amendment lands.
This applies the name substitutions and writes the result. If a client name
survives the map, it EXITS NON-ZERO rather than publishing — a licensed,
distributed artifact must never carry one.
"""
import argparse, re, sys
from pathlib import Path

SUBS = [
    (r"\(Santorio, HelpMeRad, any HIPAA-gated repo\)", "(any HIPAA-gated client repo)"),
    (r"Options2Exit #6 retro:", "a client engagement retro:"),
    (r"Options2Exit #6:", "that retro:"),
    (r"The #6 bug", "That bug"),
    (r"#5/#6:", "That retro:"),
    (r"same shape as #6", "same shape as that one"),
    (r"SoloVet day-1 4-PR set, session [0-9a-f]+, 2026-06-05",
     "a day-one 4-PR set on a client engagement"),
    (r"SoloVet day-1 4-PR set", "a day-one 4-PR set on a client engagement"),
]

# Any of these surviving means the map is incomplete. Fail loudly.
FORBIDDEN = ["santorio", "helpmerad", "options2exit", "solovet", "magill", "kocal",
             "thomas", "randi", "granola", "formstack", "resimpli", "claimpoint",
             "o2e", "truetime", "buxton"]


def generate(src: Path, dst: Path) -> int:
    text = src.read_text()
    for pat, rep in SUBS:
        text = re.sub(pat, rep, text)

    leaks = [n for n in FORBIDDEN if re.search(rf"\b{n}\b", text, re.I)]
    if leaks:
        print(f"REFUSING to write {dst}: client name(s) survived the map: {', '.join(leaks)}",
              file=sys.stderr)
        print("Add a substitution rather than deleting the sentence — the lesson is the value.",
              file=sys.stderr)
        return 1

    dst.write_text(text)
    print(f"wrote {dst} ({len(text)} bytes)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True,
                    help="path to the internal repo root (the one with .claude/skills)")
    ap.add_argument("--skill", default="c-ship")
    args = ap.parse_args()

    src = Path(args.source) / ".claude" / "skills" / args.skill / "SKILL.md"
    if not src.exists():
        print(f"source not found: {src}", file=sys.stderr)
        return 1
    dst = Path("skills") / args.skill / "SKILL.md"
    return generate(src, dst)


if __name__ == "__main__":
    raise SystemExit(main())
