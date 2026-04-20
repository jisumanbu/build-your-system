import importlib.util
import json
import tempfile
import unittest
from datetime import date, datetime, timezone
from pathlib import Path


def load_module():
    module_path = Path(__file__).resolve().parents[1] / "scripts" / "analyze_codex_activity.py"
    spec = importlib.util.spec_from_file_location("analyze_codex_activity", module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def write_jsonl(path: Path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows),
        encoding="utf-8",
    )


class AnalyzeCodexActivityTests(unittest.TestCase):
    def test_build_report_filters_target_date_and_enriches_session_metadata(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as tmpdir:
            codex_home = Path(tmpdir)
            target_day = date(2026, 4, 8)
            same_day_ts = int(datetime(2026, 4, 8, 1, 5, tzinfo=timezone.utc).timestamp())
            other_day_ts = int(datetime(2026, 4, 7, 15, 55, tzinfo=timezone.utc).timestamp())

            write_jsonl(
                codex_home / "history.jsonl",
                [
                    {
                        "session_id": "sess-1",
                        "ts": same_day_ts,
                        "text": "整理今天选题 #media",
                    },
                    {
                        "session_id": "sess-1",
                        "ts": same_day_ts + 1800,
                        "text": "继续梳理发布时间线",
                    },
                    {
                        "session_id": "sess-2",
                        "ts": other_day_ts,
                        "text": "昨天的消息不该被统计",
                    },
                ],
            )
            write_jsonl(
                codex_home / "session_index.jsonl",
                [
                    {
                        "id": "sess-1",
                        "thread_name": "热点追踪工作流",
                        "updated_at": "2026-04-08T01:40:00Z",
                    }
                ],
            )
            write_jsonl(
                codex_home / "sessions" / "2026" / "04" / "08" / "rollout-sess-1.jsonl",
                [
                    {
                        "timestamp": "2026-04-08T01:00:00Z",
                        "type": "session_meta",
                        "payload": {
                            "id": "sess-1",
                            "timestamp": "2026-04-08T01:00:00Z",
                            "cwd": "/Users/jliu/Projects/vault",
                        },
                    }
                ],
            )

            report = module.build_report(codex_home, target_day)

            self.assertEqual(report["date"], "2026-04-08")
            self.assertEqual(report["summary"]["message_count"], 2)
            self.assertEqual(report["summary"]["session_count"], 1)
            self.assertEqual(report["summary"]["start_time"], "09:05")
            self.assertEqual(report["summary"]["end_time"], "09:35")
            self.assertEqual(report["summary"]["domains"]["#media"], 2)

            event = report["timeline"][0]
            self.assertEqual(event["session_name"], "热点追踪工作流")
            self.assertEqual(event["cwd"], "/Users/jliu/Projects/vault")
            self.assertEqual(event["domain"], "#media")

    def test_render_text_report_outputs_summary_and_timeline(self):
        module = load_module()
        report = {
            "date": "2026-04-08",
            "summary": {
                "message_count": 2,
                "session_count": 1,
                "start_time": "09:05",
                "end_time": "09:35",
                "domains": {"#media": 2},
            },
            "timeline": [
                {
                    "time": "09:05",
                    "session_id": "sess-1",
                    "session_name": "热点追踪工作流",
                    "content": "整理今天选题 #media",
                    "domain": "#media",
                    "cwd": "/Users/jliu/Projects/vault",
                },
                {
                    "time": "09:35",
                    "session_id": "sess-1",
                    "session_name": "热点追踪工作流",
                    "content": "继续梳理发布时间线",
                    "domain": "#media",
                    "cwd": "/Users/jliu/Projects/vault",
                },
            ],
        }

        rendered = module.render_text_report(report)

        self.assertIn("Codex 活动分析 2026-04-08", rendered)
        self.assertIn("活动时段：09:05 - 09:35", rendered)
        self.assertIn("消息总数：2", rendered)
        self.assertIn("09:05 | 热点追踪工作流 | #media | 整理今天选题 #media", rendered)


if __name__ == "__main__":
    unittest.main()
