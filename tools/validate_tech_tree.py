# -*- coding: utf-8 -*-
"""科技树及相关数据静态校验（无需 Godot）。

用法：
  python tools/validate_tech_tree.py
退出码：0=无 ERROR，1=有 ERROR
"""
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"


def load(name: str):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def main() -> int:
    tech_tree = load("tech_tree.json")
    techs = tech_tree["techs"]
    by_id = {t["id"]: t for t in techs}
    units = load("units.json")
    unit_ids = {u["id"] for u in units.get("unit_types", [])}
    buildings = load("buildings.json")
    building_ids = {b["id"] for b in buildings.get("buildings", [])}
    cities = load("cities.json")
    city_ids = {c["id"] for c in cities.get("cities", [])}
    wonders = load("wonders.json")
    wonder_ids = {w["id"] for w in wonders.get("wonders", [])}
    synergies = load("tech_synergies.json").get("synergies", [])
    events = {e["id"]: e for e in load("tech_events.json").get("tech_events", [])}

    errors: list[str] = []
    warnings: list[str] = []

    for t in techs:
        for p in t.get("prerequisites", []):
            if p not in by_id:
                errors.append(f"前置不存在: {t['id']} -> {p}")

    groups = {g["id"]: g for g in tech_tree.get("mutual_exclusion_groups", [])}
    for t in techs:
        g = t.get("mutual_exclusion_group")
        if g and g not in groups:
            errors.append(f"互斥组未定义: {t['id']} -> {g}")
    for gid, g in groups.items():
        for m in g.get("members", []):
            if m not in by_id:
                errors.append(f"互斥成员不存在: {gid} -> {m}")
            elif by_id[m].get("mutual_exclusion_group") != gid:
                warnings.append(f"互斥成员字段不一致: {m}")

    for t in techs:
        effects = t.get("effects") or []
        if isinstance(effects, dict):
            effects = [effects]
        for e in effects:
            if e.get("type") == "unlock_unit":
                uid = e.get("unit_id")
                if uid and uid not in unit_ids:
                    errors.append(f"解锁兵种不在 units.json: {t['id']} -> {uid}")
        for c in t.get("special_conditions") or []:
            typ = c.get("type")
            if typ == "city_control" and c.get("city_id") not in city_ids:
                errors.append(f"条件城市不存在: {t['id']} -> {c.get('city_id')}")
            if typ == "building" and c.get("building_id") not in building_ids:
                warnings.append(f"条件建筑不在 buildings.json: {t['id']} -> {c.get('building_id')}")
        req_w = t.get("requires_wonder")
        if req_w and req_w not in wonder_ids:
            errors.append(f"requires_wonder 不存在: {t['id']} -> {req_w}")
        for eid in t.get("research_events") or []:
            if eid not in events:
                errors.append(f"research_events 未定义: {t['id']} -> {eid}")
        m = t.get("mastery")
        if m:
            max_lv = int(m.get("max_level", 0))
            if len(m.get("increment_per_level", [])) < max_lv:
                warnings.append(f"精通 increment 少于 max_level: {t['id']}")
            if len(m.get("upgrade_cost", [])) < max_lv:
                warnings.append(f"精通 cost 少于 max_level: {t['id']}")
            if not m.get("effect_type"):
                errors.append(f"精通缺 effect_type: {t['id']}")

    for s in synergies:
        for req in s.get("required_techs", []):
            if req not in by_id:
                errors.append(f"协同前置不存在: {s.get('id')} -> {req}")

    # 循环前置
    color = defaultdict(int)
    stack = []
    circles = []

    def dfs(u: str) -> None:
        color[u] = 1
        stack.append(u)
        for v in by_id.get(u, {}).get("prerequisites", []):
            if v not in by_id:
                continue
            if color[v] == 1:
                circles.append(stack[stack.index(v):] + [v])
            elif color[v] == 0:
                dfs(v)
        stack.pop()
        color[u] = 2

    for tid in by_id:
        if color[tid] == 0:
            dfs(tid)

    print("=== 科技数据静态校验 ===")
    print(f"科技: {len(techs)} {dict(Counter(t['category'] for t in techs))}")
    print(f"ERRORS ({len(errors)}):")
    for e in errors:
        print("  [E]", e)
    print(f"WARNINGS ({len(warnings)}):")
    for w in warnings:
        print("  [W]", w)
    print("循环前置:", circles if circles else "无")
    return 1 if errors or circles else 0


if __name__ == "__main__":
    sys.exit(main())
