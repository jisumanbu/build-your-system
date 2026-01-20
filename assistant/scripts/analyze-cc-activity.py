#!/usr/bin/env python3
"""
Claude Code 活动分析脚本 V2
分析指定日期的 Claude Code 对话记录，生成活动时间线和统计

功能：
- 自动识别活动目标（基于 summary、命令、关键词、文件路径）
- 与 MIT 关联对比
- 按目标分组统计时间
- 输出结构化数据供 /a-review 使用

用法：
  python3 analyze-cc-activity.py              # 分析今天
  python3 analyze-cc-activity.py 2025-12-31   # 分析指定日期
"""
import json
import os
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Dict, Optional, Set, Tuple

# 配置
# 使用当前工作目录作为 Vault（用户应在 Vault 目录内运行 Claude Code）
VAULT = Path.cwd()
CLAUDE_HOME = Path.home() / '.claude'
PROJECTS_DIR = CLAUDE_HOME / 'projects'
ACTIVE_FILE = VAULT / '02-Tasks/active.md'

# 目标识别配置
COMMAND_GOALS = {
    '/a-tasks': '任务管理',
    '/a-review': '每日回顾',
    '/a-capture': '快速捕获',
    '/a-dump': '脑暴倾倒',
    '/a-weekly': '周报整理',
    '/a-status': '系统检查',
    '/m-director': '视频创作',
    '/m-topic': '选题评估',
    '/m-hook': 'Hook设计',
    '/m-structure': '内容结构',
    '/m-script': '逐字稿创作',
    '/m-title': '标题封面',
    '/m-publish': '发布检查',
    '/m-mine': '选题挖掘',
    '/cc-activity': 'CC活动分析',
}

# 应该忽略的命令（系统操作）
IGNORED_COMMANDS = {'/rename', '/clear', '/help', '/quit', '/exit'}

# 应该跳过的消息模式
SKIP_PATTERNS = [
    r'^Warmup$',
    r'^Caveat:',
    r'^<local-command-stdout>',
    r'^This session is being continued',
    r'^\[-\]\s*$',  # 单独的 [-]
    r'^-\s*$',  # 单独的 -
    r'^<command-message>',  # 命令消息（重复内容）
    r'^进行每日回顾，包含',  # 命令描述
    r'^分析 Claude Code 对话记录',  # 命令描述
    r'^\[助手\]',  # 助手命令描述
]

# 不应作为目标的通用词
GENERIC_WORDS = {'执行计划', '继续', '好的', '确认', '是', '否', 'yes', 'no', 'ok'}

# 无效目标的模式
INVALID_GOAL_PATTERNS = [
    r'^\d{1,2}:\d{2}$',  # 时间格式 HH:MM
    r'^\d+$',  # 纯数字
    r'^[A-Z]$',  # 单个大写字母
]

# 领域识别配置
DOMAIN_PATTERNS = [
    (r'03-Areas/media/', '#media'),
    (r'03-Areas/indie/', '#indie'),
    (r'04-Projects/', '#indie'),
    (r'02-Tasks/', '#tasks'),
    (r'06-Memory/', '#reflection'),
    (r'outsourcing', '#outsourcing'),
    (r'\.claude/commands/m-', '#media'),
    (r'\.claude/commands/a-', '#assistant'),
]

# 目标关键词模式
GOAL_PATTERNS = [
    (r'开始\s*[「""]?([^「""」\s]+)[」""]?\s*(MIT|任务)?', 1),
    (r'聚焦\s*[「""]?([^「""」\s]+)[」""]?', 1),
    (r'/m-director\s+(.+)', 1),
    (r'/m-script\s+(.+)', 1),
    (r'/m-topic\s+(.+)', 1),
]


@dataclass
class Activity:
    """单个活动记录"""
    time: str  # HH:MM
    goal: str  # 活动目标
    domain: str  # 领域标签
    content: str  # 消息摘要
    session_id: str  # 来源会话 ID
    session_name: str  # 会话名称（用户命名或 slug）
    project: str  # 项目名


@dataclass
class Session:
    """对话会话"""
    file_path: Path
    session_id: str
    project: str  # 项目名
    session_name: Optional[str] = None  # 用户命名的会话名
    slug: Optional[str] = None  # 自动生成的 slug
    summary: Optional[str] = None
    activities: List[Activity] = field(default_factory=list)
    files_touched: Set[str] = field(default_factory=set)
    tools_used: Set[str] = field(default_factory=set)

    @property
    def display_name(self) -> str:
        """获取显示名称：优先用户命名，其次 slug，最后 session_id"""
        if self.session_name:
            return self.session_name
        if self.slug:
            return self.slug
        return self.session_id[:12]


def parse_date(date_str: Optional[str]) -> datetime.date:
    """解析日期字符串"""
    if not date_str:
        return datetime.now().date()
    try:
        return datetime.strptime(date_str, '%Y-%m-%d').date()
    except ValueError:
        print(f"日期格式错误: {date_str}，应为 YYYY-MM-DD")
        sys.exit(1)


def utc_to_gmt8(ts_str: str) -> Tuple[Optional[str], Optional[datetime.date], Optional[datetime]]:
    """UTC 时间戳转 GMT+8，返回 (时间字符串, 日期, 完整datetime)"""
    try:
        dt = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
        gmt8 = dt + timedelta(hours=8)
        return gmt8.strftime('%H:%M'), gmt8.date(), gmt8
    except:
        return None, None, None


def parse_project_name(dir_name: str) -> str:
    """从目录名解析项目名"""
    name = dir_name.lstrip('-')
    parts = name.split('-')
    prefixes_to_remove = ['Users', 'jliu', 'git', 'claude', 'code', 'Library',
                          'Mobile', 'Documents', 'iCloud', 'md', 'obsidian', 'Projects']
    result_parts = []
    prefix_done = False
    for part in parts:
        if not prefix_done and part.lower() in [p.lower() for p in prefixes_to_remove]:
            continue
        else:
            prefix_done = True
            result_parts.append(part)
    if result_parts:
        return '-'.join(result_parts)
    else:
        return '-'.join(parts[-2:]) if len(parts) >= 2 else parts[-1]


def get_files_for_date(target_date: datetime.date) -> List[Tuple[Path, str]]:
    """获取指定日期修改的 jsonl 文件"""
    files = []
    if PROJECTS_DIR.exists():
        for project_dir in PROJECTS_DIR.iterdir():
            if not project_dir.is_dir():
                continue
            project_name = parse_project_name(project_dir.name)
            for f in project_dir.glob('*.jsonl'):
                try:
                    mtime = datetime.fromtimestamp(f.stat().st_mtime).date()
                    if mtime == target_date:
                        files.append((f, project_name))
                except Exception:
                    pass
    return sorted(files, key=lambda x: x[0].stat().st_mtime)


def extract_command(content: str) -> Optional[Tuple[str, str]]:
    """从消息内容提取命令和参数"""
    cmd_match = re.search(r'<command-name>(/[^<]+)</command-name>', content)
    if cmd_match:
        cmd = cmd_match.group(1)
        args_match = re.search(r'<command-args>([^<]*)</command-args>', content)
        args = args_match.group(1) if args_match else ''
        return cmd, args.strip()
    cmd_match = re.match(r'^(/[a-z]+-?[a-z]*)\s*(.*)', content.strip())
    if cmd_match:
        return cmd_match.group(1), cmd_match.group(2).strip()
    return None


def detect_goal_from_content(content: str) -> Optional[str]:
    """从消息内容检测目标"""
    cmd_result = extract_command(content)
    if cmd_result:
        cmd, args = cmd_result
        base_cmd = cmd.split()[0] if ' ' in cmd else cmd
        if base_cmd in COMMAND_GOALS:
            goal = COMMAND_GOALS[base_cmd]
            if args and base_cmd in ['/m-director', '/m-script', '/m-topic']:
                return f"{goal}:{args[:30]}"
            return goal
    for pattern, group in GOAL_PATTERNS:
        match = re.search(pattern, content)
        if match:
            return match.group(group).strip()[:40]
    return None


def infer_domain_from_paths(paths: Set[str]) -> str:
    """从文件路径推断领域"""
    for path in paths:
        for pattern, domain in DOMAIN_PATTERNS:
            if re.search(pattern, path):
                return domain
    return '#other'


def parse_session(filepath: Path, target_date: datetime.date, project: str = '') -> Session:
    """解析单个对话文件"""
    session = Session(
        file_path=filepath,
        session_id=filepath.stem,
        project=project
    )
    current_goal = None

    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            try:
                d = json.loads(line)
                record_type = d.get('type', '')

                if record_type == 'user' and not session.slug:
                    slug = d.get('slug', '')
                    if slug:
                        session.slug = slug

                if record_type == 'user':
                    content = ''
                    msg = d.get('message', {})
                    if isinstance(msg, dict):
                        raw = msg.get('content', '')
                        if isinstance(raw, str):
                            content = raw
                    rename_match = re.search(r'Session renamed to:\s*(.+?)(?:<|$)', content)
                    if rename_match:
                        name = rename_match.group(1).strip()
                        name = re.sub(r'<[^>]+>', '', name).strip()
                        if name:
                            session.session_name = name

                if record_type == 'summary':
                    session.summary = d.get('summary', '')
                    continue

                if record_type == 'file-history-snapshot':
                    snapshot = d.get('snapshot', {})
                    for path in snapshot.get('trackedFileBackups', {}).keys():
                        session.files_touched.add(path)
                    continue

                if record_type == 'assistant':
                    msg = d.get('message', {})
                    contents = msg.get('content', [])
                    if isinstance(contents, list):
                        for c in contents:
                            if isinstance(c, dict) and c.get('type') == 'tool_use':
                                session.tools_used.add(c.get('name', ''))
                    continue

                if record_type == 'user':
                    ts = d.get('timestamp', '')
                    if not ts:
                        continue

                    time_str, msg_date, _ = utc_to_gmt8(ts)
                    if msg_date != target_date:
                        continue

                    msg = d.get('message', {})
                    content = ''
                    if isinstance(msg, dict):
                        raw = msg.get('content', '')
                        if isinstance(raw, str):
                            content = raw
                        elif isinstance(raw, list):
                            for c in raw:
                                if isinstance(c, dict) and c.get('type') == 'text':
                                    content = c.get('text', '')
                                    break

                    if not content or content.startswith('<system') or content.startswith('<?xml'):
                        continue
                    if '[Request interrupted' in content:
                        continue

                    should_skip = False
                    for pattern in SKIP_PATTERNS:
                        if re.match(pattern, content.strip()):
                            should_skip = True
                            break
                    if should_skip:
                        continue

                    cmd_result = extract_command(content)
                    if cmd_result:
                        cmd, _ = cmd_result
                        if cmd in IGNORED_COMMANDS:
                            continue

                    clean_content = content.strip()
                    clean_content = re.sub(r'^\[-\]\s*', '', clean_content)
                    clean_content = re.sub(r'^-\s+', '', clean_content)
                    clean_content = clean_content.strip()
                    if not clean_content:
                        continue

                    detected_goal = detect_goal_from_content(clean_content)
                    if detected_goal and detected_goal not in GENERIC_WORDS:
                        current_goal = detected_goal

                    valid_summary = session.summary if session.summary and len(session.summary) > 2 else None
                    goal = current_goal or valid_summary or '其他'

                    is_invalid = goal in GENERIC_WORDS or goal == '-' or len(goal) <= 1
                    for pattern in INVALID_GOAL_PATTERNS:
                        if re.match(pattern, goal):
                            is_invalid = True
                            break
                    if is_invalid:
                        goal = '其他'

                    domain = infer_domain_from_paths(session.files_touched)

                    activity = Activity(
                        time=time_str,
                        goal=goal,
                        domain=domain,
                        content=clean_content[:100].replace('\n', ' '),
                        session_id=session.session_id,
                        session_name=session.display_name,
                        project=session.project
                    )
                    session.activities.append(activity)

            except json.JSONDecodeError:
                pass
            except Exception:
                pass

    return session


def parse_mit(target_date: datetime.date) -> List[str]:
    """从 active.md 解析 MIT 列表"""
    if not ACTIVE_FILE.exists():
        return []

    mit_list = []
    date_str = target_date.strftime('%m-%d')

    try:
        with open(ACTIVE_FILE, 'r', encoding='utf-8') as f:
            content = f.read()

        pattern = rf'## 今日重点 \(MIT\) - {date_str}\s*\n(.*?)(?=\n---|\n##|$)'
        match = re.search(pattern, content, re.DOTALL)

        if match:
            block = match.group(1)
            for line in block.split('\n'):
                line = line.strip()
                if line.startswith('- [ ]') or line.startswith('- [x]'):
                    task = re.sub(r'^- \[.\]\s*', '', line)
                    task = re.sub(r'\s*#\w+\s*', ' ', task).strip()
                    if task:
                        mit_list.append(task)
    except:
        pass

    return mit_list


def match_mit(goal: str, mit_list: List[str]) -> Optional[str]:
    """将活动目标与 MIT 匹配"""
    if not mit_list or not goal:
        return None

    goal_lower = goal.lower()

    for mit in mit_list:
        mit_lower = mit.lower()
        if goal_lower in mit_lower or mit_lower in goal_lower:
            return mit

    goal_words = set(re.findall(r'[\u4e00-\u9fa5]+|[a-zA-Z]+', goal_lower))
    for mit in mit_list:
        mit_words = set(re.findall(r'[\u4e00-\u9fa5]+|[a-zA-Z]+', mit.lower()))
        if goal_words & mit_words:
            return mit

    return None


def calculate_stats(activities: List[Activity]) -> Dict:
    """计算统计数据"""
    if not activities:
        return {}

    by_goal = defaultdict(list)
    for act in activities:
        by_goal[act.goal].append(act)

    by_domain = defaultdict(int)
    for act in activities:
        by_domain[act.domain] += 1

    goal_stats = {}
    for goal, acts in by_goal.items():
        minutes = len(acts) * 5
        domain = acts[0].domain if acts else '#other'
        goal_stats[goal] = {
            'messages': len(acts),
            'minutes': minutes,
            'domain': domain
        }

    return {
        'total_messages': len(activities),
        'start_time': activities[0].time,
        'end_time': activities[-1].time,
        'by_goal': goal_stats,
        'by_domain': dict(by_domain)
    }


def format_timeline(activities: List[Activity], sessions: List[Session]) -> str:
    """格式化时间线输出"""
    lines = ["📝 活动时间线 (GMT+8):", "-" * 80]

    session_map = {s.session_id: s for s in sessions}
    by_session = defaultdict(list)
    for act in activities:
        by_session[act.session_id].append(act)

    session_order = []
    for sid, acts in by_session.items():
        if acts:
            first_time = acts[0].time
            session_order.append((first_time, sid))
    session_order.sort()

    for _, sid in session_order:
        acts = by_session[sid]
        if not acts:
            continue

        session = session_map.get(sid)
        session_name = session.display_name if session else sid[:12]
        project = session.project if session else ''
        time_range = f"{acts[0].time}-{acts[-1].time}"

        project_tag = f"@{project}" if project else ''
        lines.append(f"\n🔹 [{session_name}] {project_tag} ({time_range}, {len(acts)}条)")
        lines.append("-" * 40)

        for act in acts:
            goal_tag = f"[{act.goal}]" if act.goal != '其他' else ''
            content = act.content
            lines.append(f"  {act.time} | {goal_tag} {content}")

    lines.append("\n" + "-" * 80)
    return '\n'.join(lines)


def format_stats(stats: Dict, mit_list: List[str], activities: List[Activity]) -> str:
    """格式化统计摘要"""
    if not stats:
        return ""

    lines = ["\n📊 统计摘要:", "-" * 60]

    lines.append(f"活动时段: {stats['start_time']} - {stats['end_time']}")
    lines.append(f"消息总数: {stats['total_messages']} 条\n")

    lines.append("按目标分组:")
    for goal, data in sorted(stats['by_goal'].items(), key=lambda x: -x[1]['messages']):
        dots = '.' * max(1, 30 - len(goal))
        lines.append(f"  {goal} {dots} {data['messages']}条 ({data['domain']})")

    if mit_list:
        lines.append("\nMIT 完成情况:")
        matched_mits = set()
        goal_to_mit = {}

        for goal in stats['by_goal'].keys():
            matched = match_mit(goal, mit_list)
            if matched:
                matched_mits.add(matched)
                goal_to_mit[goal] = matched

        for mit in mit_list:
            if mit in matched_mits:
                for goal, matched in goal_to_mit.items():
                    if matched == mit:
                        lines.append(f"  ✅ {mit[:40]} → 匹配「{goal}」")
                        break
            else:
                lines.append(f"  ⏸️ {mit[:40]} → 未启动")

        unplanned = [g for g in stats['by_goal'].keys()
                     if g not in goal_to_mit and g not in ['其他', '任务管理', '每日回顾', '快速捕获']]
        if unplanned:
            lines.append("\n计划外产出:")
            for goal in unplanned:
                lines.append(f"  - {goal}")

    lines.append("-" * 60)
    return '\n'.join(lines)


def format_json_data(target_date: datetime.date, stats: Dict, mit_list: List[str],
                      activities: List[Activity], sessions: List[Session]) -> str:
    """生成 JSON 数据块供 /a-review 使用"""
    sessions_data = []
    for session in sessions:
        if not session.activities:
            continue

        acts = session.activities
        sessions_data.append({
            'name': session.display_name,
            'project': session.project,
            'summary': session.summary or '',
            'time_range': f"{acts[0].time}-{acts[-1].time}",
            'messages': len(acts),
            'files': list(session.files_touched)[:10],
            'activities': [
                {
                    'time': act.time,
                    'content': act.content[:80]
                }
                for act in acts[:10]
            ]
        })

    data = {
        'date': str(target_date),
        'active_period': {
            'start': stats.get('start_time', ''),
            'end': stats.get('end_time', '')
        },
        'total_messages': stats.get('total_messages', 0),
        'sessions': sessions_data,
        'mit_list': mit_list
    }

    return f"\n=== CC_ACTIVITY_DATA ===\n{json.dumps(data, ensure_ascii=False, indent=2)}\n=== END ==="


def main():
    date_arg = sys.argv[1] if len(sys.argv) > 1 else None
    target_date = parse_date(date_arg)

    print(f"=== Claude Code 活动分析 ({target_date}) ===\n")

    files = get_files_for_date(target_date)
    if not files:
        print(f"未找到 {target_date} 的对话记录")
        return

    print(f"找到 {len(files)} 个对话文件\n")

    all_activities = []
    all_sessions = []
    for f, project in files:
        session = parse_session(f, target_date, project)
        if session.activities:
            all_sessions.append(session)
            all_activities.extend(session.activities)

    if not all_activities:
        print("该日期无用户消息")
        return

    all_activities.sort(key=lambda x: x.time)

    mit_list = parse_mit(target_date)
    if mit_list:
        print(f"📋 今日 MIT ({len(mit_list)} 项):")
        for mit in mit_list:
            print(f"  - {mit}")
        print()

    print(format_timeline(all_activities, all_sessions))

    stats = calculate_stats(all_activities)
    print(format_stats(stats, mit_list, all_activities))

    print(format_json_data(target_date, stats, mit_list, all_activities, all_sessions))


if __name__ == '__main__':
    main()
