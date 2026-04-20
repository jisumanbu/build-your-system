#!/usr/bin/env python3
"""Analyze Codex activity from local history and rollout files."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from datetime import date, datetime, timedelta, timezone
from pathlib import Path


GMT8 = timezone(timedelta(hours=8))
KNOWN_TAGS = ("#outsourcing", "#indie", "#media", "#life", "#learning")


def iter_jsonl(path: Path):
    if not path.is_file():
        return
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def parse_date_arg(value: str | None) -> date:
    if not value:
        return datetime.now(tz=GMT8).date()
    return datetime.strptime(value, "%Y-%m-%d").date()


def ts_to_local(ts: int | float) -> datetime:
    return datetime.fromtimestamp(ts, tz=timezone.utc).astimezone(GMT8)


def read_session_names(codex_home: Path) -> dict[str, str]:
    names: dict[str, str] = {}
    for row in iter_jsonl(codex_home / "session_index.jsonl") or []:
        session_id = row.get("id")
        thread_name = row.get("thread_name")
        if session_id and thread_name:
            names[session_id] = thread_name
    return names


def load_rollout_metadata(codex_home: Path, session_ids: set[str]) -> dict[str, dict[str, str]]:
    metadata: dict[str, dict[str, str]] = {}
    rollout_paths = list((codex_home / "sessions").glob("**/rollout-*.jsonl"))
    rollout_paths.extend((codex_home / "archived_sessions").glob("rollout-*.jsonl"))

    for path in rollout_paths:
        if session_ids and not any(session_id in path.name for session_id in session_ids):
            continue
        for row in iter_jsonl(path) or []:
            if row.get("type") != "session_meta":
                continue
            payload = row.get("payload", {})
            session_id = payload.get("id")
            if not session_id or session_id not in session_ids:
                continue
            metadata[session_id] = {
                "cwd": payload.get("cwd", ""),
                "started_at": payload.get("timestamp", ""),
            }
            break
    return metadata


def detect_domain(text: str, cwd: str) -> str:
    for tag in KNOWN_TAGS:
        if tag in text:
            return tag

    lowered = cwd.lower()
    if "media" in lowered:
        return "#media"
    if "outsourcing" in lowered:
        return "#outsourcing"
    if "indie" in lowered or "build-in-public" in lowered:
        return "#indie"
    if "learning" in lowered:
        return "#learning"
    if "life" in lowered:
        return "#life"
    return "#other"


def clean_excerpt(text: str, limit: int = 80) -> str:
    line = " ".join(text.strip().split())
    if len(line) <= limit:
        return line
    return f"{line[: limit - 1]}…"


def build_report(codex_home: Path, target_date: date) -> dict:
    session_names = read_session_names(codex_home)
    raw_events: list[dict] = []

    for row in iter_jsonl(codex_home / "history.jsonl") or []:
        session_id = row.get("session_id")
        ts = row.get("ts")
        text = row.get("text", "")
        if not session_id or ts is None or not text:
            continue

        local_dt = ts_to_local(ts)
        if local_dt.date() != target_date:
            continue

        raw_events.append(
            {
                "local_dt": local_dt,
                "session_id": session_id,
                "content": clean_excerpt(text),
            }
        )

    session_ids = {event["session_id"] for event in raw_events}
    rollout_metadata = load_rollout_metadata(codex_home, session_ids)

    timeline: list[dict[str, str]] = []
    domain_counts: Counter[str] = Counter()
    session_domains: dict[str, str] = {}

    for event in sorted(raw_events, key=lambda item: item["local_dt"]):
        session_id = event["session_id"]
        metadata = rollout_metadata.get(session_id, {})
        cwd = metadata.get("cwd", "")
        domain = detect_domain(event["content"], cwd)
        if domain == "#other" and session_id in session_domains:
            domain = session_domains[session_id]
        elif domain != "#other":
            session_domains[session_id] = domain
        timeline_event = {
            "time": event["local_dt"].strftime("%H:%M"),
            "session_id": session_id,
            "session_name": session_names.get(session_id, session_id[:12]),
            "content": event["content"],
            "domain": domain,
            "cwd": cwd,
        }
        timeline.append(timeline_event)
        domain_counts[domain] += 1

    start_time = timeline[0]["time"] if timeline else None
    end_time = timeline[-1]["time"] if timeline else None

    return {
        "date": target_date.isoformat(),
        "summary": {
            "message_count": len(timeline),
            "session_count": len({event["session_id"] for event in timeline}),
            "start_time": start_time,
            "end_time": end_time,
            "domains": dict(sorted(domain_counts.items())),
        },
        "timeline": timeline,
    }


def render_text_report(report: dict) -> str:
    lines = [f"=== Codex 活动分析 {report['date']} ==="]

    summary = report["summary"]
    if summary["message_count"] == 0:
        lines.append("当天没有检测到 Codex 活动。")
        return "\n".join(lines)

    lines.append(f"活动时段：{summary['start_time']} - {summary['end_time']}")
    lines.append(f"消息总数：{summary['message_count']}")
    lines.append(f"活跃会话：{summary['session_count']}")
    lines.append("")
    lines.append("时间线：")

    for event in report["timeline"]:
        lines.append(
            f"{event['time']} | {event['session_name']} | {event['domain']} | {event['content']}"
        )

    if summary["domains"]:
        lines.append("")
        lines.append("领域分布：")
        for domain, count in summary["domains"].items():
            lines.append(f"- {domain}: {count}")

    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Analyze Codex activity for a given day.")
    parser.add_argument("target_date", nargs="?", help="Date in YYYY-MM-DD format")
    parser.add_argument("--json-only", action="store_true", help="Print JSON only")
    parser.add_argument(
        "--codex-home",
        default=str(Path.home() / ".codex"),
        help="Override Codex home path for testing",
    )
    args = parser.parse_args(argv)

    report = build_report(Path(args.codex_home), parse_date_arg(args.target_date))
    if args.json_only:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(render_text_report(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
