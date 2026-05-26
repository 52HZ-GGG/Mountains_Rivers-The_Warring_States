"""从 knowledge-graph.json 提取依赖影响图谱，写入 memory/dependency-impact-map.md"""
import json
import sys
import os


def extract(graph_path, output_path):
    with open(graph_path, 'r', encoding='utf-8') as f:
        graph = json.load(f)

    nodes = {n['id']: n for n in graph.get('nodes', [])}
    edges = graph.get('edges', [])

    dependents = {}
    dependencies = {}

    for e in edges:
        src, tgt = e['source'], e['target']
        rtype = e.get('type', '')
        if rtype == 'depends_on':
            dependents.setdefault(tgt, []).append(src)
            dependencies.setdefault(src, []).append(tgt)

    def short_name(node_id):
        return nodes.get(node_id, {}).get('name', node_id.split(':')[-1])

    top = sorted(dependents.items(), key=lambda x: len(x[1]), reverse=True)[:15]

    lines = [
        '---',
        'name: dependency-impact-map',
        'description: 核心系统文件的影响范围图谱 — 修改前必查，防止连锁 bug',
        'type: project',
        '---',
        '',
        '# 依赖影响图谱（基于 knowledge-graph.json）',
        '',
        f'数据来源：`.understand-anything/knowledge-graph.json`（{len(nodes)} 节点 / {len(edges)} 边）',
        '',
        '## 高影响文件排名',
        '',
        '| 文件 | 被依赖数 | 依赖者 |',
        '|------|----------|--------|',
    ]

    for fid, deps in top:
        name = short_name(fid)
        dep_names = ', '.join(short_name(d) for d in deps)
        lines.append(f'| `{name}` | **{len(deps)}** | {dep_names} |')

    lines += ['', '## 核心依赖链', '']

    key_files = [
        'file:scripts/autoload/data_manager.gd',
        'file:scripts/autoload/signal_bus.gd',
        'file:scripts/autoload/game_manager.gd',
        'file:scripts/autoload/tactical_skirmish_manager.gd',
        'file:scripts/systems/combat_resolver.gd',
    ]

    for kf in key_files:
        if kf not in nodes:
            continue
        name = short_name(kf)
        my_deps = dependencies.get(kf, [])
        my_dependents = dependents.get(kf, [])
        lines.append(f'### {name}')
        if my_deps:
            lines.append(f'- 依赖: {", ".join(short_name(d) for d in my_deps)}')
        else:
            lines.append('- 依赖: 无（叶子节点）')
        if my_dependents:
            lines.append(f'- 被依赖: {", ".join(short_name(d) for d in my_dependents)}')
        lines.append('')

    lines += ['## 修改检查清单', '']

    checklist_map = {
        'file:scripts/autoload/data_manager.gd': [
            '验证所有下游文件的 DataManager 调用签名未变',
            '重点检查 game_manager.gd（回合循环数据流）',
            '重点检查 tactical_skirmish_manager.gd（战斗数据加载）',
            '重点检查 combat_resolver.gd（伤害公式参数）',
        ],
        'file:scripts/autoload/signal_bus.gd': [
            '确认信号名/参数未被下游依赖者硬编码',
            '重点检查 event_manager.gd（事件触发链）',
            '重点检查 city_manager.gd（城池状态变更通知）',
        ],
        'file:scripts/systems/hex_axial.gd': [
            '确认坐标转换函数签名未变',
            '重点检查 tactical_skirmish_manager.gd（移动/攻击范围计算）',
            '重点检查 unit_movement_manager.gd（路径计算）',
        ],
        'file:scripts/autoload/game_manager.gd': [
            '确认回合状态机阶段名未变',
            '检查 event_manager.gd（回合事件触发时机）',
            '检查 startup_flow.gd（游戏初始化流程）',
        ],
    }

    for fid, checks in checklist_map.items():
        if fid not in nodes:
            continue
        name = short_name(fid)
        lines.append(f'### 改 {name} 前')
        for c in checks:
            lines.append(f'- {c}')
        lines.append('')

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')

    print(f'Wrote {len(lines)} lines to {output_path}')
    print(f'Top 5: {", ".join(short_name(f) for f, _ in top[:5])}')


if __name__ == '__main__':
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    graph = os.path.join(root, '.understand-anything', 'knowledge-graph.json')

    # Resolve memory directory: ~/.claude/projects/<encoded-project-path>/memory/
    # Claude encodes project paths: D:\Mountains-Rivers-The_Warring_States -> D--Mountains-Rivers-The_Warring_States
    home = os.path.expanduser('~')
    abs_root = os.path.abspath(root)
    drive, rest = os.path.splitdrive(abs_root)
    # D:\foo\bar -> D--foo-bar (backslashes to -, drive letter + --)
    encoded = drive.rstrip(':') + '--' + rest.replace('\\', '-').lstrip('-')
    memory_dir = os.path.join(home, '.claude', 'projects', encoded, 'memory')
    if not os.path.isdir(memory_dir):
        os.makedirs(memory_dir, exist_ok=True)
    output = os.path.join(memory_dir, 'dependency-impact-map.md')
    if not os.path.exists(graph):
        print(f'Error: {graph} not found. Run /understand first.')
        sys.exit(1)
    extract(graph, output)
