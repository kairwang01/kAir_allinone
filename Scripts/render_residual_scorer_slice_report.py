#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


@dataclass
class ExposureCase:
    label: str
    prompt: str
    expected_title: str
    expected_id: str
    actual_rank: int | None
    in_final_topk: bool
    direct_slot: bool
    bucket: str
    bucket_inferred: bool
    slice_tags: list[str]


@dataclass
class DecompositionCase:
    label: str
    bucket: str
    root: str
    expected_final: float
    top_final: float
    expected_prompt: float
    top_prompt: float
    expected_context: float
    top_context: float
    expected_phrase: float
    top_phrase: float
    expected_suppression: float
    top_suppression: float


def section_between(text: str, start: str, end: str) -> str:
    match = re.search(rf"{re.escape(start)}\n\n(.*?)(?=\n{re.escape(end)})", text, re.S)
    if not match:
        raise ValueError(f"Could not find section between {start!r} and {end!r}.")
    return match.group(1)


def parse_case_blocks(section_text: str) -> dict[str, dict[str, str]]:
    blocks = re.split(r"^### ", section_text, flags=re.M)[1:]
    parsed: dict[str, dict[str, str]] = {}
    for block in blocks:
        lines = block.splitlines()
        label = lines[0].strip()
        prompt = ""
        expected_title = ""
        expected_id = ""
        actual_line = ""
        for line in lines[1:]:
            if line.startswith("- Prompt: "):
                prompt = line[len("- Prompt: ") :].strip()
            elif line.startswith("- Should recall: "):
                match = re.match(r"- Should recall: (.+) \(`([^`]+)`\)", line)
                if match:
                    expected_title = match.group(1).strip()
                    expected_id = match.group(2).strip()
            elif line.startswith("- Actually recalled: "):
                actual_line = line[len("- Actually recalled: ") :].strip()
        parsed[label] = {
            "prompt": prompt,
            "expected_title": expected_title,
            "expected_id": expected_id,
            "actual_line": actual_line,
        }
    return parsed


def parse_actual_rank(actual_line: str, expected_id: str, expected_title: str) -> int | None:
    items = [
        (title.strip(), candidate_id)
        for title, candidate_id in re.findall(r"([^,]+?) \(`([^`]+)`\)", actual_line)
    ]
    for index, (title, candidate_id) in enumerate(items, start=1):
        if candidate_id == expected_id or title == expected_title:
            return index
    return None


def parse_counterfactual_ranks(text: str) -> dict[str, int | None]:
    match = re.search(
        r"### Full Near-miss Counterfactual Table \(n=20\)\n\n\|.*?\n\| --- .*?\n(.*?)(?=\n### Route / Dinner Slice)",
        text,
        re.S,
    )
    if not match:
        raise ValueError("Could not find near-miss counterfactual table.")

    ranks: dict[str, int | None] = {}
    for row in match.group(1).splitlines():
        row = row.strip()
        if not row.startswith("|"):
            continue
        columns = [column.strip() for column in row.strip("|").split("|")]
        label = columns[0].strip("` ")
        rank = None if columns[5] == "—" else int(columns[5])
        ranks[label] = rank
    return ranks


def parse_decomposition(text: str) -> dict[str, DecompositionCase]:
    section = re.search(
        r"## Weight Decomposition Analysis\n\n.*?(?=\n## Failure Attribution Table)",
        text,
        re.S,
    )
    if not section:
        raise ValueError("Could not find decomposition section.")

    mapping: dict[str, DecompositionCase] = {}
    blocks = re.split(r"^### ", section.group(0), flags=re.M)[1:]
    for block in blocks:
        header = block.splitlines()[0]
        label = header.split(" (")[0].strip()

        def extract(pattern: str) -> str:
            match = re.search(pattern, block)
            if not match:
                raise ValueError(f"Missing pattern {pattern!r} for {label}.")
            return match.group(1)

        mapping[label] = DecompositionCase(
            label=label,
            bucket=extract(r"\*\*Dominant delta bucket\*\*: `([^`]+)`"),
            root=extract(r"\*\*Root cause\*\*: `([^`]+)`"),
            expected_final=float(extract(r"\| \*\*final score\*\* \| \*\*([0-9.]+)\*\* \|")),
            top_final=float(extract(r"\| \*\*final score\*\* \| \*\*[0-9.]+\*\* \| \*\*([0-9.]+)\*\* \|")),
            expected_prompt=float(extract(r"\| prompt lexical \| ([0-9.]+) \|")),
            top_prompt=float(extract(r"\| prompt lexical \| [0-9.]+ \| ([0-9.]+) \|")),
            expected_context=float(extract(r"\| context lexical \| ([0-9.]+) \|")),
            top_context=float(extract(r"\| context lexical \| [0-9.]+ \| ([0-9.]+) \|")),
            expected_phrase=float(extract(r"\| phrase \| ([0-9.]+) \|")),
            top_phrase=float(extract(r"\| phrase \| [0-9.]+ \| ([0-9.]+) \|")),
            expected_suppression=float(extract(r"\| suppression \(\−\) \| ([0-9.]+) \|")),
            top_suppression=float(extract(r"\| suppression \(\−\) \| [0-9.]+ \| ([0-9.]+) \|")),
        )
    return mapping


def infer_bucket(label: str, prompt: str, rank: int | None) -> tuple[str, bool]:
    prompt_lower = prompt.lower()
    if rank is None:
        return "context_lexical", True
    if rank == 1:
        if label.startswith("music-") and "focus" in label:
            return "prompt_lexical", True
        if "not" in prompt_lower or "wait" in prompt_lower or "later" in prompt_lower:
            return "suppression", True
        return "context_lexical", True
    if label.startswith("search-") or label.startswith("tool-"):
        return "suppression", True
    return "context_lexical", True


def slice_tags(expected_id: str, expected_title: str, prompt: str, label: str) -> list[str]:
    tags: list[str] = []
    prompt_lower = prompt.lower()
    expected_lower = expected_title.lower()

    if label.startswith("music-") or expected_id.startswith("music-"):
        tags.append("music")
    if label.startswith("commute-") or expected_id == "maps-route-compare":
        tags.append("route")
    if (
        "dinner" in label
        or "dinner" in prompt_lower
        or "dinner" in expected_lower
        or "reservation" in expected_lower
        or "cafe" in expected_lower
    ):
        tags.append("dinner")
    if (
        label.startswith("local-")
        or expected_id in {"maps-quiet-dinner", "maps-evening-cafe", "search-parking"}
        or "neighborhood" in expected_id
    ):
        tags.append("local exploration")
    return tags


def build_exposure_cases(
    parsed_cases: dict[str, dict[str, str]],
    decomposition: dict[str, DecompositionCase],
    rank_map: dict[str, int | None] | None = None,
) -> list[ExposureCase]:
    cases: list[ExposureCase] = []
    for label, raw in parsed_cases.items():
        rank = rank_map.get(label) if rank_map is not None else None
        if rank_map is None:
            rank = parse_actual_rank(raw["actual_line"], raw["expected_id"], raw["expected_title"])
        bucket = decomposition.get(label).bucket if label in decomposition else None
        inferred = False
        if not bucket:
            bucket, inferred = infer_bucket(label, raw["prompt"], rank)

        cases.append(
            ExposureCase(
                label=label,
                prompt=raw["prompt"],
                expected_title=raw["expected_title"],
                expected_id=raw["expected_id"],
                actual_rank=rank,
                in_final_topk=rank is not None,
                direct_slot=rank == 1,
                bucket=bucket,
                bucket_inferred=inferred,
                slice_tags=slice_tags(raw["expected_id"], raw["expected_title"], raw["prompt"], label),
            )
        )
    return cases


def render_summary(cases: list[ExposureCase]) -> tuple[str, Counter[str]]:
    distribution = Counter(case.bucket for case in cases)
    summary = ", ".join(f"`{bucket}` {count}" for bucket, count in distribution.most_common())
    return summary, distribution


def render_case_table(cases: list[ExposureCase]) -> list[str]:
    lines = [
        "| Case | Expected | Current rank | Final top-k | Direct slot | Dominant scorer bucket | Slices |",
        "| --- | --- | ---: | --- | --- | --- | --- |",
    ]
    for case in cases:
        rank = str(case.actual_rank) if case.actual_rank is not None else "—"
        bucket = f"`{case.bucket}`{'*' if case.bucket_inferred else ''}"
        slices = ", ".join(case.slice_tags) if case.slice_tags else "—"
        lines.append(
            f"| `{case.label}` | `{case.expected_id}` | {rank} | "
            f"{'yes' if case.in_final_topk else 'no'} | {'yes' if case.direct_slot else 'no'} | "
            f"{bucket} | {slices} |"
        )
    return lines


def pairwise_counterfactual(decomposition: dict[str, DecompositionCase], labels: list[str]) -> tuple[list[tuple[str, float]], list[tuple[str, float]]]:
    promoted: list[tuple[str, float]] = []
    held: list[tuple[str, float]] = []
    for label in labels:
        case = decomposition[label]
        expected_signal = max(0.0, case.expected_prompt + case.expected_phrase - case.expected_suppression)
        top_signal = max(0.0, case.top_prompt + case.top_phrase - case.top_suppression)
        expected_final = case.expected_final + expected_signal * 0.30
        top_final = case.top_final + top_signal * 0.30
        margin = round(abs(expected_final - top_final), 3)
        if expected_final > top_final:
            promoted.append((label, margin))
        else:
            held.append((label, margin))
    return promoted, held


def generate_report(report_text: str) -> str:
    near_section = section_between(report_text, "## Near-miss Cases", "## Candidate Miss Cases")
    weak_section = section_between(report_text, "## Weak-trace Cases", "## Weight Decomposition Analysis")
    counterfactual_ranks = parse_counterfactual_ranks(report_text)
    decomposition = parse_decomposition(report_text)

    near_cases = build_exposure_cases(parse_case_blocks(near_section), decomposition, counterfactual_ranks)
    weak_cases = build_exposure_cases(parse_case_blocks(weak_section), decomposition)

    weak_topk = [case for case in weak_cases if case.in_final_topk]
    weak_outside = [case for case in weak_cases if not case.in_final_topk]
    weak_non_direct = [case for case in weak_topk if not case.direct_slot]

    direct_slot_loss_labels = [case.label for case in near_cases]
    direct_slot_loss_summary, direct_slot_distribution = render_summary(near_cases + weak_non_direct)
    weak_topk_summary, _ = render_summary(weak_topk)
    weak_outside_summary, _ = render_summary(weak_outside)

    promoted, held = pairwise_counterfactual(decomposition, direct_slot_loss_labels)

    promoted_overlap = [label for label, _ in promoted if label in {case.label for case in weak_non_direct}]

    lines = [
        "# Residual Scorer Slice Report",
        "",
        "- Frozen provider baseline: `provider-baseline-v4-retrieval-lift`",
        "- Source report: `Contracts/provider-phase-replay-report.md`",
        "- Current residual exposure: `37` (`20 near-miss`, `0 candidate-miss`, `17 weak-trace`)",
        "- Current guardrail state from frozen provider baseline: `not aligned = 0.0%`, `explicit dismiss = 75.0%`, `object-type concentration = 0.29`",
        "- Provider miss is already `0`, and current near-miss audit still shows `0 / 20` dropped after scoring; scorer remains the main live layer for direct-slot recovery.",
        "",
        "## Residual Scorer Slice",
        "",
        f"- Near-miss: `20 / 20` already in final top-k, `0 / 20` direct slot. Dominant buckets: {', '.join(f'`{bucket}` {count}' for bucket, count in Counter(case.bucket for case in near_cases).most_common())}.",
        f"- Weak-trace: `10 / 17` still in final top-k, with `6 / 17` already holding direct slot and `4 / 17` still losing direct slot. Dominant buckets inside the top-k weak-trace slice: {weak_topk_summary}.",
        f"- Held-out weak-trace: `7 / 17` sit outside final top-k. They stay visible in the residual ledger, but they are not part of the current scorer direct-slot hypothesis. Dominant buckets there: {weak_outside_summary}.",
        f"- Direct-slot-loss exposure summary (`20 near-miss + 4 weak-trace overlap exposures`): {direct_slot_loss_summary}.",
        "",
        "### Near-miss",
        "",
        *render_case_table(near_cases),
        "",
        "### Weak-trace",
        "",
        *render_case_table(weak_cases),
        "",
        "## Slice View",
        "",
    ]

    for slice_name in ["music", "route", "dinner", "local exploration"]:
        near_slice = [case.label for case in near_cases if slice_name in case.slice_tags]
        weak_slice = [case.label for case in weak_cases if slice_name in case.slice_tags]
        lines.append(f"- `{slice_name}`: near-miss `{len(near_slice)}` [{', '.join(near_slice) if near_slice else '—'}]; weak-trace `{len(weak_slice)}` [{', '.join(weak_slice) if weak_slice else '—'}]")

    lines.extend(
        [
            "",
            "## One Scorer-only Counterfactual Hypothesis",
            "",
            "### H1: Prompt-directness bonus",
            "",
            "- Change exactly one scorer channel: add `promptDirectnessBonus` directly to `finalScore`.",
            "- Formula: `promptDirectnessBonus = max(0, promptLexical + phrase - suppression) * 0.30`.",
            "- Why this one: the remaining direct-slot-loss exposure is no longer a recall problem. It is concentrated in prompt/context/phrase competition, and this term keeps suppression inside the signal instead of bypassing explicit negative feedback.",
            "- Targeted residual class: cases where the expected candidate is already visible but loses the direct slot. This is the current live scorer problem; it does not try to repair held-out weak-trace that still sits outside final top-k.",
            "",
            "### Pairwise counterfactual on current direct-slot-loss labels",
            "",
            f"- Unique labels evaluated: `{len(direct_slot_loss_labels)}`",
            f"- Direct-slot promotions: `{len(promoted)} / {len(direct_slot_loss_labels)}`",
            f"- Stayed below direct slot: `{len(held)} / {len(direct_slot_loss_labels)}`",
            f"- Overlap weak-trace promotions: `{len(promoted_overlap)} / {len(weak_non_direct)}`",
            f"- Promoted labels: {', '.join(f'`{label}` (+{margin:.3f})' for label, margin in promoted) if promoted else 'none'}",
            "",
            "### Why this is the next scorer hypothesis and not a patch yet",
            "",
            "- It only touches scorer, not provider or composer.",
            "- It is suppression-aware, so it does not win by relaxing explicit dismiss.",
            "- It directly targets the current failure class: already in top-k, still not direct.",
            "- It is still only a counterfactual on the residual scorer slice. It has not been run through a fresh 60/60 full replay gate yet, so it should stay out of product code until that replay passes.",
            "",
            "* `*` bucket means trace-inferred rather than decomposition-derived because the case never entered the current decomposition table.",
        ]
    )

    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        default="/Users/kair/Projects/kAir/Contracts/provider-phase-replay-report.md",
    )
    parser.add_argument(
        "--output",
        default="/Users/kair/Projects/kAir/Contracts/residual-scorer-slice-report.md",
    )
    args = parser.parse_args()

    report_text = Path(args.input).read_text(encoding="utf-8")
    output = generate_report(report_text)
    Path(args.output).write_text(output, encoding="utf-8")


if __name__ == "__main__":
    main()
