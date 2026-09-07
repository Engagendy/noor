#!/usr/bin/env python3
"""Forced-align a matn recitation against its bundled text -> per-line starts.

Given (a) an audio recording of a matn and (b) the bundled matn JSON produced
by `build_matn_tuhfa.py`, this emits a timings JSON mapping every line number
to its start time in seconds, so the Learn reader can highlight the line that
is currently being recited.

WHY NOT SILENCE DETECTION
-------------------------
`ffmpeg silencedetect` on the sample recording yields ~58 gaps for 60 lines,
which looks tempting, but the resulting segments run 0.5 s .. 54 s: reciters
breathe mid-hemistich and run whole couplets together, so pauses are simply
not line boundaries. The text is *known*, so the right tool is alignment, not
segmentation: we transcribe once, then align the (noisy) transcript to the
(authoritative) 60 lines and read the line starts off the anchors.

METHOD
------
1. faster-whisper (CTranslate2, no PyTorch) transcribes the audio with
   word-level timestamps, `language="ar"`.
2. Both the reference lines and the hypothesis words are folded with the same
   Arabic normalisation the app uses (`Core/ContentDB/.../TextSearch.swift`:
   strip tashkeel U+064B-U+065F, Quranic marks U+06D6-U+06ED, superscript
   alef U+0670, tatweel U+0640; alef variants -> bare alef; alef maqsura ->
   ya). Reimplemented here in Python -- Swift is not imported.
3. A global Needleman-Wunsch alignment over the two token streams (fuzzy
   token similarity, so Whisper's spelling slips still anchor) gives, for
   each reference token, the hypothesis word it corresponds to.
4. Each line's start is the timestamp of its earliest anchored token, walked
   back by the mean token duration for any of the line's tokens Whisper
   missed. Lines with no anchor at all are linearly interpolated between
   their anchored neighbours and flagged.
5. Optional refinement: starts are snapped to the nearest `silencedetect`
   boundary within a small window -- alignment gets the *line* right, silence
   gets the *instant* right.
6. Sanity checks fail loudly (see --help): count, monotonicity, in-bounds,
   plausible per-line durations. Because a matn is metrical (Tuhfat al-Atfal
   is rajaz, every line the same number of feet), a tight spread of line
   durations is real evidence the alignment did not drift; a fat tail is
   evidence it did.

REPRODUCING THIS MONTHS FROM NOW
--------------------------------
    /opt/homebrew/bin/python3.11 -m venv /tmp/noormatnvenv
    /tmp/noormatnvenv/bin/pip install faster-whisper
    /tmp/noormatnvenv/bin/python Tools/build_matn_timings.py \
        "/path/to/recitation.mp3" \
        Modules/Learn/Sources/Learn/Resources/matn-tuhfat-al-atfal.json \
        /tmp/tuhfa-timings.json

Nothing but `faster-whisper` is needed (it pulls ctranslate2, onnxruntime, av,
numpy, tokenizers -- ~120 MB of wheels, NO PyTorch). The Whisper weights are
downloaded once to ~/.cache/huggingface (large-v3 int8 ~= 1.5 GB) and cached.
`ffmpeg` on PATH is used only for the optional silence snapping.

Flags worth knowing:
    --model medium|large-v3   smaller = faster, worse Arabic (default large-v3)
    --no-snap                 skip the silencedetect refinement
    --transcript-cache PATH   save/reuse the transcription (re-tune alignment
                              without paying for ASR again)

The output JSON is a build artefact for review; wiring it into the app means
copying the licensed audio in and setting `audio`/`timings` in the matn JSON.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import unicodedata

# --- Arabic folding: mirrors ArabicSearch.fold / build_quran_db.py ----------

_DROP = set(range(0x064B, 0x0660)) | set(range(0x06D6, 0x06EE)) | {0x0670, 0x0640}
_MAP = {0x0622: 0x0627, 0x0623: 0x0627, 0x0625: 0x0627, 0x0671: 0x0627,
        0x0649: 0x064A}


def fold(text: str) -> str:
    """Folded form: diacritics/marks dropped, alef & ya variants unified."""
    out = []
    for ch in unicodedata.normalize("NFC", text):
        cp = ord(ch)
        if cp in _DROP:
            continue
        out.append(chr(_MAP.get(cp, cp)))
    return "".join(out)


_PUNCT = re.compile(r"[^ء-يٮ-ەa-zA-Z0-9]+")


def tokenize(text: str) -> list[str]:
    """Folded word tokens, punctuation stripped, empties dropped."""
    return [t for t in _PUNCT.split(fold(text)) if t]


# --- fuzzy token similarity ------------------------------------------------

def _lev(a: str, b: str) -> int:
    if a == b:
        return 0
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1,
                           prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


_sim_cache: dict[tuple[str, str], float] = {}


def similarity(a: str, b: str) -> float:
    """1.0 identical .. 0.0 unrelated. Cheap guards before edit distance."""
    if a == b:
        return 1.0
    key = (a, b)
    hit = _sim_cache.get(key)
    if hit is not None:
        return hit
    # Cheap reject: no shared first letter and very different lengths.
    if abs(len(a) - len(b)) > max(len(a), len(b)) // 2 + 1:
        val = 0.0
    else:
        d = _lev(a, b)
        val = max(0.0, 1.0 - d / max(len(a), len(b)))
    _sim_cache[key] = val
    return val


# --- global alignment ------------------------------------------------------

MATCH_FLOOR = 0.60   # below this a pairing is not evidence of anything
GAP = -0.5           # insertion/deletion penalty


def align(ref: list[str], hyp: list[str]) -> list[int | None]:
    """Needleman-Wunsch. Returns, per ref token, the hyp index or None.

    Score of pairing r,h is (2*sim - 1) so a good match is rewarded and a bad
    one is worse than a gap; the monotone alignment therefore cannot reorder
    the poem, which is exactly the property we need.
    """
    n, m = len(ref), len(hyp)
    neg = float("-inf")
    # score[i][j]: best score aligning ref[:i] with hyp[:j]
    prev = [GAP * j for j in range(m + 1)]
    ptr = [bytearray(m + 1) for _ in range(n + 1)]  # 0=diag 1=up(ref gap) 2=left
    for j in range(1, m + 1):
        ptr[0][j] = 2
    for i in range(1, n + 1):
        ri = ref[i - 1]
        cur = [GAP * i] + [neg] * m
        ptr_i = ptr[i]
        ptr_i[0] = 1
        for j in range(1, m + 1):
            diag = prev[j - 1] + (2.0 * similarity(ri, hyp[j - 1]) - 1.0)
            up = prev[j] + GAP
            left = cur[j - 1] + GAP
            if diag >= up and diag >= left:
                cur[j] = diag
                ptr_i[j] = 0
            elif up >= left:
                cur[j] = up
                ptr_i[j] = 1
            else:
                cur[j] = left
                ptr_i[j] = 2
        prev = cur
    # traceback
    out: list[int | None] = [None] * n
    i, j = n, m
    while i > 0 and j > 0:
        d = ptr[i][j]
        if d == 0:
            if similarity(ref[i - 1], hyp[j - 1]) >= MATCH_FLOOR:
                out[i - 1] = j - 1
            i -= 1
            j -= 1
        elif d == 1:
            i -= 1
        else:
            j -= 1
    return out


# --- audio helpers ---------------------------------------------------------

def audio_duration(path: str) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", path],
        capture_output=True, text=True, check=True).stdout.strip()
    return float(out)


def silence_boundaries(path: str, noise_db: int = -30,
                       min_dur: float = 0.20) -> list[float]:
    """Times (s) at which a silent stretch ENDS -- candidate line onsets."""
    proc = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", path,
         "-af", f"silencedetect=noise={noise_db}dB:d={min_dur}",
         "-f", "null", "-"],
        capture_output=True, text=True)
    return [float(m) for m in
            re.findall(r"silence_end: ([0-9.]+)", proc.stderr)]


# --- transcription ---------------------------------------------------------

def transcribe(path: str, model_name: str, cache: str | None) -> list[dict]:
    if cache and os.path.exists(cache):
        with open(cache, encoding="utf-8") as fh:
            return json.load(fh)
    from faster_whisper import WhisperModel
    model = WhisperModel(model_name, device="cpu", compute_type="int8")
    segments, _info = model.transcribe(
        path, language="ar", word_timestamps=True,
        vad_filter=False,             # we want every second covered
        condition_on_previous_text=False,  # stops rhyme-driven loops
        beam_size=5,
    )
    words: list[dict] = []
    for seg in segments:
        for w in (seg.words or []):
            words.append({"w": w.word.strip(), "start": float(w.start),
                          "end": float(w.end), "p": float(w.probability)})
        print(f"  .. {seg.end:7.1f}s", end="\r", file=sys.stderr, flush=True)
    print(file=sys.stderr)
    if cache:
        with open(cache, "w", encoding="utf-8") as fh:
            json.dump(words, fh, ensure_ascii=False)
    return words


# --- main ------------------------------------------------------------------

MIN_LINE = 2.0
MAX_LINE = 40.0


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("audio")
    ap.add_argument("matn_json")
    ap.add_argument("output")
    ap.add_argument("--model", default="large-v3")
    ap.add_argument("--transcript-cache", default=None)
    ap.add_argument("--no-snap", action="store_true")
    ap.add_argument("--review-threshold", type=float, default=0.8,
                    help="confidence below which a line is flagged for a human")
    ap.add_argument("--snap-window", type=float, default=1.2,
                    help="max seconds a start may move to reach a silence end")
    args = ap.parse_args()

    with open(args.matn_json, encoding="utf-8") as fh:
        matn = json.load(fh)
    lines = matn["lines"]
    duration = audio_duration(args.audio)
    print(f"audio: {duration:.1f}s   lines: {len(lines)}", file=sys.stderr)

    # reference token stream, remembering which line each token came from
    ref: list[str] = []
    ref_line: list[int] = []
    line_token_span: dict[int, tuple[int, int]] = {}
    for idx, ln in enumerate(lines):
        start_tok = len(ref)
        for tok in tokenize(ln["first"]) + tokenize(ln["second"]):
            ref.append(tok)
            ref_line.append(idx)
        line_token_span[idx] = (start_tok, len(ref))

    print("transcribing (first run downloads the model) ...", file=sys.stderr)
    words = transcribe(args.audio, args.model, args.transcript_cache)
    hyp: list[str] = []
    hyp_word: list[dict] = []
    for w in words:
        toks = tokenize(w["w"])
        if not toks:
            continue
        # a Whisper "word" is one token in practice; if it split, share times
        for t in toks:
            hyp.append(t)
            hyp_word.append(w)
    print(f"ref tokens: {len(ref)}   hyp tokens: {len(hyp)}", file=sys.stderr)

    mapping = align(ref, hyp)
    matched = sum(1 for m in mapping if m is not None)
    print(f"aligned {matched}/{len(ref)} reference tokens "
          f"({100 * matched / len(ref):.1f}%)", file=sys.stderr)

    # mean spoken duration of a token, for backing off to a missed line head
    spans = [hyp_word[m]["end"] - hyp_word[m]["start"]
             for m in mapping if m is not None]
    mean_tok = sum(spans) / len(spans) if spans else 0.4

    # per line: earliest anchor, coverage
    raw: list[dict] = []
    for idx in range(len(lines)):
        lo, hi = line_token_span[idx]
        anchors = [(k, mapping[k]) for k in range(lo, hi) if mapping[k] is not None]
        cov = len(anchors) / max(1, hi - lo)
        if anchors:
            k, m = anchors[0]
            start = hyp_word[m]["start"] - (k - lo) * mean_tok
            k2, m2 = anchors[-1]
            end = hyp_word[m2]["end"] + (hi - 1 - k2) * mean_tok
            raw.append({"start": max(0.0, start), "end": end, "coverage": cov,
                        "anchored": True, "n_anchor": len(anchors)})
        else:
            raw.append({"start": None, "end": None, "coverage": 0.0,
                        "anchored": False, "n_anchor": 0})

    # interpolate unanchored lines between their anchored neighbours
    known = [i for i, r in enumerate(raw) if r["start"] is not None]
    if not known:
        print("FAIL: no line could be anchored at all", file=sys.stderr)
        return 2
    for i, r in enumerate(raw):
        if r["start"] is not None:
            continue
        before = [k for k in known if k < i]
        after = [k for k in known if k > i]
        if before and after:
            a, b = before[-1], after[0]
            t = (i - a) / (b - a)
            r["start"] = raw[a]["start"] + t * (raw[b]["start"] - raw[a]["start"])
        elif before:
            a = before[-1]
            r["start"] = raw[a]["start"] + (i - a) * (duration - raw[a]["start"]) / (len(raw) - a)
        else:
            b = after[0]
            r["start"] = raw[b]["start"] * i / b

    # enforce monotonicity (alignment is monotone, but the back-off and the
    # interpolation are not guaranteed to be)
    for i in range(1, len(raw)):
        if raw[i]["start"] <= raw[i - 1]["start"]:
            raw[i]["start"] = raw[i - 1]["start"] + 0.05
            raw[i]["nudged"] = True

    # snap to silence ends
    snapped = 0
    if not args.no_snap:
        bounds = silence_boundaries(args.audio)
        print(f"silence boundaries: {len(bounds)}", file=sys.stderr)
        for i, r in enumerate(raw):
            if not r["anchored"]:
                continue
            cands = [b for b in bounds if abs(b - r["start"]) <= args.snap_window]
            if not cands:
                continue
            best = min(cands, key=lambda b: abs(b - r["start"]))
            lower = raw[i - 1]["start"] + MIN_LINE if i else 0.0
            upper = raw[i + 1]["start"] - MIN_LINE if i + 1 < len(raw) else duration
            if lower <= best <= upper:
                r["snap"] = round(best - r["start"], 3)
                r["start"] = best
                snapped += 1
        print(f"snapped {snapped} starts to a silence boundary", file=sys.stderr)

    # confidence: coverage of the line, damped when the head token was missed
    # or the value was interpolated/nudged.
    out_lines = []
    last_end = max((w["end"] for w in words), default=duration)
    for i, (ln, r) in enumerate(zip(lines, raw)):
        conf = r["coverage"]
        if not r["anchored"]:
            conf = 0.0
        if r.get("nudged"):
            conf *= 0.5
        # End of the *spoken line*, which is not always the start of the
        # next one: reciters read the section headings aloud, and those are
        # not part of any line. Emitting both lets a follow-along highlight
        # switch off during a heading instead of drifting through it.
        nxt = raw[i + 1]["start"] if i + 1 < len(raw) else min(duration, last_end)
        end = r["end"] if r["end"] is not None else nxt
        end = min(max(end, r["start"] + 0.1), nxt)
        out_lines.append({
            "line": ln["number"],
            "start": round(r["start"], 3),
            "end": round(end, 3),
            "gap_to_next": round(nxt - end, 3),
            "confidence": round(min(1.0, conf), 3),
            "anchored": r["anchored"],
            "anchor_tokens": r["n_anchor"],
            "snap": r.get("snap"),
        })

    # Spoken duration per line (start..end), which is the metre-sensitive
    # quantity; start-to-start also counts any heading read between lines.
    durs = [o["end"] - o["start"] for o in out_lines]
    slots = [out_lines[i + 1]["start"] - out_lines[i]["start"]
             for i in range(len(out_lines) - 1)]
    slots.append(min(duration, last_end) - out_lines[-1]["start"])
    mean = sum(durs) / len(durs)
    var = sum((d - mean) ** 2 for d in durs) / len(durs)
    sd = var ** 0.5

    # ---- sanity checks, loud ----
    failures: list[str] = []
    if len(out_lines) != len(lines):
        failures.append(f"expected {len(lines)} timings, got {len(out_lines)}")
    for i in range(1, len(out_lines)):
        if out_lines[i]["start"] <= out_lines[i - 1]["start"]:
            failures.append(f"line {out_lines[i]['line']} start is not increasing")
    for o in out_lines:
        if o["start"] < 0 or o["start"] > duration:
            failures.append(f"line {o['line']} start {o['start']} outside audio")
    short = [out_lines[i]["line"] for i, d in enumerate(slots) if d < MIN_LINE]
    long = [out_lines[i]["line"] for i, d in enumerate(slots) if d > MAX_LINE]
    if short:
        failures.append(f"lines shorter than {MIN_LINE}s: {short}")
    if long:
        failures.append(f"lines longer than {MAX_LINE}s: {long}")

    # outliers vs the metre: rajaz lines should all take about the same time
    outliers = [(out_lines[i]["line"], round(d, 2))
                for i, d in enumerate(durs) if abs(d - mean) > 2 * sd]
    low_conf = [o["line"] for o in out_lines
                if o["confidence"] < args.review_threshold]

    # Independent structural cross-check: reciters normally announce each
    # section title, so a real (non-drifting) alignment should leave an
    # unclaimed gap exactly at the section boundaries -- a list we never fed
    # into the alignment. Agreement here is evidence; disagreement is a smell.
    boundaries = {lines[i]["number"] for i in range(1, len(lines))
                  if lines[i]["section_id"] != lines[i - 1]["section_id"]}
    gapped = {o["line"] + 1 for o in out_lines[:-1] if o["gap_to_next"] > 1.5}
    section_check = {
        "section_boundaries": sorted(boundaries),
        "boundaries_with_a_spoken_gap": sorted(boundaries & gapped),
        "boundaries_without_a_gap": sorted(boundaries - gapped),
        "gaps_not_at_a_boundary": sorted(gapped - boundaries),
    }

    intro = out_lines[0]["start"]
    result = {
        "source_audio": os.path.basename(args.audio),
        "audio_duration": round(duration, 3),
        "matn_id": matn.get("id"),
        "model": args.model,
        "method": "faster-whisper word timestamps + Needleman-Wunsch "
                  "alignment to the bundled text (folded), silence-snapped",
        "intro_offset": round(intro, 3),
        "line_duration_mean": round(mean, 3),
        "line_duration_sd": round(sd, 3),
        "note": "start..end is the spoken line; gap_to_next is anything "
                "recited between lines (section headings) and belongs to no "
                "line -- a highlight should be off during it.",
        "duration_outliers": outliers,
        "review_lines": sorted(set(low_conf) | {l for l, _ in outliers}),
        "section_boundary_cross_check": section_check,
        "checks_passed": not failures,
        "failures": failures,
        "timings": out_lines,
    }
    with open(args.output, "w", encoding="utf-8") as fh:
        json.dump(result, fh, ensure_ascii=False, indent=2)

    print(f"\nintro before line 1: {intro:.2f}s", file=sys.stderr)
    print(f"line duration: mean {mean:.2f}s  sd {sd:.2f}s  "
          f"min {min(durs):.2f}s  max {max(durs):.2f}s", file=sys.stderr)
    print(f"duration outliers (>2sd): {outliers}", file=sys.stderr)
    print(f"low-confidence lines (<{args.review_threshold}): {low_conf}",
          file=sys.stderr)
    print(f"section boundaries with a spoken gap: "
          f"{len(section_check['boundaries_with_a_spoken_gap'])}"
          f"/{len(boundaries)}  "
          f"stray gaps: {section_check['gaps_not_at_a_boundary']}",
          file=sys.stderr)
    print(f"wrote {args.output}", file=sys.stderr)
    if failures:
        print("\nSANITY CHECKS FAILED:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        return 1
    print("sanity checks passed", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
