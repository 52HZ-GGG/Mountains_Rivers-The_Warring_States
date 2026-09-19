"""Rebuild the 100x70 overworld terrain without river or ford cells.

Run from the repository root: python tools/generate_big_map_terrain.py
City coordinates and fixed pass coordinates are read, never rewritten.
"""

from __future__ import annotations

import json
import heapq
import math
from collections import Counter, deque
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WIDTH, HEIGHT = 100, 70
OUT = ROOT / "data" / "big_map_terrain.json"


def hash01(x: int, y: int, seed: int) -> float:
    n = (x * 374761393 + y * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFFFFFF) / 0xFFFFFFFF


def noise(x: float, y: float, scale: float, seed: int) -> float:
    fx, fy = x / scale, y / scale
    ix, iy = math.floor(fx), math.floor(fy)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = hash01(ix, iy, seed) * (1 - tx) + hash01(ix + 1, iy, seed) * tx
    b = hash01(ix, iy + 1, seed) * (1 - tx) + hash01(ix + 1, iy + 1, seed) * tx
    return (a * (1 - ty) + b * ty) * 2 - 1


def region(x: int, y: int, cx: float, cy: float, rx: float, ry: float) -> float:
    return max(0.0, 1.0 - ((x - cx) / rx) ** 2 - ((y - cy) / ry) ** 2)


def ridge(x: float, y: float, points: tuple[tuple[int, int], ...], width: float) -> float:
    """A softly edged mountain chain following a bent geographical axis."""
    distance_sq = math.inf
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        dx, dy = bx - ax, by - ay
        t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
        distance_sq = min(distance_sq, (x - ax - t * dx) ** 2 + (y - ay - t * dy) ** 2)
    return math.exp(-distance_sq / (2.0 * width * width))


def neighbors(col: int, row: int):
    # Flat-top hexes with odd-column vertical offset; matches BigMapPanel's layout.
    diagonal_above = row - 1 if col % 2 == 0 else row
    diagonal_below = row if col % 2 == 0 else row + 1
    for point in (
        (col, row - 1), (col, row + 1),
        (col - 1, diagonal_above), (col + 1, diagonal_above),
        (col - 1, diagonal_below), (col + 1, diagonal_below),
    ):
        if 0 <= point[0] < WIDTH and 0 <= point[1] < HEIGHT:
            yield point


def coastline(x: int, y: int) -> float:
    # Bohai indentation, Shandong-like peninsula, then the Jiangnan coast.
    anchors = ((0, 95), (15, 89), (27, 87), (36, 95), (43, 91),
               (53, 87), (63, 85), (69, 87))
    for (ay, ax), (by, bx) in zip(anchors, anchors[1:]):
        if y <= by:
            t = (y - ay) / (by - ay)
            t = t * t * (3 - 2 * t)
            return ax + (bx - ax) * t + 1.4 * noise(0, y, 8.0, 4)
    return 87.0


def terrain_at(x: int, y: int) -> str:
    coast = coastline(x, y)
    if x >= coast:
        return "shallow_ocean" if x < coast + 3.5 else "deep_ocean"

    # Warp the axes slightly so the ridges do not look like drawn ellipses.
    wx = x + 2.3 * noise(x, y, 15.0, 12)
    wy = y + 2.0 * noise(x, y, 13.0, 22)
    elevation = max(
        0.94 * ridge(wx, wy, ((2, 23), (7, 34), (10, 49), (7, 68)), 4.3),
        0.91 * ridge(wx, wy, ((11, 50), (17, 47), (25, 48), (34, 49), (40, 53)), 2.6),
        0.91 * ridge(wx, wy, ((34, 13), (38, 20), (39, 28), (38, 35)), 3.0),
        0.80 * ridge(wx, wy, ((53, 5), (62, 4), (71, 5), (82, 11)), 2.7),
        0.84 * ridge(wx, wy, ((28, 54), (30, 61), (32, 69)), 2.9),
        0.77 * ridge(wx, wy, ((13, 65), (22, 68), (31, 68)), 3.0),
        0.67 * ridge(wx, wy, ((56, 58), (67, 62), (77, 66), (86, 68)), 2.7),
        0.63 * ridge(wx, wy, ((74, 32), (81, 35), (83, 41)), 2.3),
        0.58 * ridge(wx, wy, ((43, 54), (48, 58), (54, 62)), 2.0),
    ) + 0.12 * noise(x, y, 5.5, 29) + 0.04 * noise(x, y, 2.7, 28)
    if elevation > 0.58:
        return "mountain"

    # Tundra is confined to the remote north; the populated north is steppe/plains.
    cold = region(x, y, 26, -2, 25, 10) * 0.82 + noise(x, y, 8.0, 30) * 0.13
    if cold > 0.48:
        return "tundra"

    arid = max(region(x, y, 4, 13, 28, 21),
               region(x, y, 16, 23, 18, 13) * 0.66) + noise(x, y, 8.0, 37) * 0.17
    if arid > 0.50:
        return "desert"

    # Wetlands stay in low southern/coastal basins, not as one huge blob.
    wet = max(region(x, y, 62, 51, 12, 8) * 0.72,
              region(x, y, 77, 56, 10, 9) * 0.70,
              region(x, y, 72, 43, 8, 7) * 0.61) + noise(x, y, 5.0, 45) * 0.14
    if wet > 0.57:
        return "marsh"

    woods = max(region(x, y, 20, 58, 19, 13) * 0.72,
                region(x, y, 46, 62, 24, 13) * 0.84,
                region(x, y, 70, 61, 23, 14) * 0.78,
                region(x, y, 48, 17, 16, 13) * 0.59,
                region(x, y, 65, 20, 13, 10) * 0.53,
                elevation * 0.82) + noise(x, y, 7.0, 53) * 0.20
    if woods > 0.51:
        return "forest"
    return "plains"


def reachable_land(rows: list[list[str]], start: tuple[int, int]) -> set[tuple[int, int]]:
    land = {"plains", "forest", "marsh", "desert", "tundra", "pass"}
    seen = {start}
    queue = deque([start])
    while queue:
        x, y = queue.popleft()
        for nx, ny in neighbors(x, y):
            if (nx, ny) not in seen and rows[ny][nx] in land:
                seen.add((nx, ny))
                queue.append((nx, ny))
    return seen


def link_landmarks(rows: list[list[str]], cities: list[dict], passes: list[dict]) -> None:
    """Join cities and fixed passes with narrow land corridors through ridges."""
    points = [(city["hex_q"], city["hex_r"]) for city in cities]
    points += [(passage["offset_col"], passage["offset_row"]) for passage in passes]
    connected = {0}
    while len(connected) < len(points):
        _, src, dst = min(
            ((points[a][0] - points[b][0]) ** 2 + (points[a][1] - points[b][1]) ** 2, a, b)
            for a in connected for b in range(len(points)) if b not in connected
        )
        start, goal = points[src], points[dst]
        distances = {start: 0}
        previous = {}
        queue = [(0, start)]
        while queue:
            cost, current = heapq.heappop(queue)
            if cost != distances[current]:
                continue
            if current == goal:
                break
            for neighbor in neighbors(*current):
                tile = rows[neighbor[1]][neighbor[0]]
                if tile in {"shallow_ocean", "deep_ocean"}:
                    continue
                step = 10 if tile == "mountain" else 2 if tile == "marsh" else 1
                alternative = cost + step
                if alternative < distances.get(neighbor, math.inf):
                    distances[neighbor] = alternative
                    previous[neighbor] = current
                    heapq.heappush(queue, (alternative, neighbor))
        if goal not in distances:
            raise ValueError(f"No land route to landmark {points[dst]}")
        point = goal
        while point != start:
            x, y = point
            if rows[y][x] == "mountain":
                rows[y][x] = "plains"
            point = previous[point]
        connected.add(dst)


def build() -> tuple[list[list[str]], list[dict], list[dict]]:
    cities = json.loads((ROOT / "data" / "cities.json").read_text(encoding="utf-8"))["cities"]
    passes = json.loads((ROOT / "data" / "passes.json").read_text(encoding="utf-8"))["passes"]
    rows = [[terrain_at(x, y) for x in range(WIDTH)] for y in range(HEIGHT)]

    # Remove isolated single-cell flecks; keep natural clustered regions.
    for _ in range(2):
        next_rows = [row.copy() for row in rows]
        for y in range(HEIGHT):
            for x in range(WIDTH):
                current = rows[y][x]
                if current in {"shallow_ocean", "deep_ocean"}:
                    continue
                adjacent = Counter(rows[ny][nx] for nx, ny in neighbors(x, y))
                if adjacent[current] <= 1:
                    common, count = adjacent.most_common(1)[0]
                    if count >= 4 and common not in {"shallow_ocean", "deep_ocean"}:
                        next_rows[y][x] = common
        rows = next_rows

    for city in cities:
        x, y = city["hex_q"], city["hex_r"]
        if not (0 <= x < WIDTH and 0 <= y < HEIGHT):
            raise ValueError(f"City outside map: {city['id']}")
        rows[y][x] = "plains"

    for passage in passes:
        x, y = passage["offset_col"], passage["offset_row"]
        if any((city["hex_q"], city["hex_r"]) == (x, y) for city in cities):
            raise ValueError(f"Pass overlaps city: {passage['name']}")
        rows[y][x] = "pass"

    link_landmarks(rows, cities, passes)

    return rows, cities, passes


def main() -> None:
    rows, cities, passes = build()
    counts = Counter(cell for row in rows for cell in row)
    expected = {"plains", "forest", "mountain", "marsh", "pass", "desert",
                "tundra", "shallow_ocean", "deep_ocean"}
    if len(rows) != HEIGHT or any(len(row) != WIDTH for row in rows):
        raise ValueError("Wrong map dimensions")
    if set(counts) != expected:
        raise ValueError(f"Terrain set mismatch: {counts}")
    if any(rows[y][x] == "deep_ocean" and
           any(rows[ny][nx] not in {"deep_ocean", "shallow_ocean"}
               for nx, ny in neighbors(x, y))
           for y in range(HEIGHT) for x in range(WIDTH)):
        raise ValueError("Deep ocean touches land without a shallow-water transition")
    if any(rows[city["hex_r"]][city["hex_q"]] != "plains" for city in cities):
        raise ValueError("City tile is not land")
    if any(rows[p["offset_row"]][p["offset_col"]] != "pass" for p in passes):
        raise ValueError("Fixed pass lost")
    seen = reachable_land(rows, (cities[0]["hex_q"], cities[0]["hex_r"]))
    reachable = sum((city["hex_q"], city["hex_r"]) in seen for city in cities)
    if reachable != len(cities):
        raise ValueError(f"Only {reachable}/{len(cities)} cities connected by land")
    reachable_passes = sum((p["offset_col"], p["offset_row"]) in seen for p in passes)
    if reachable_passes != len(passes):
        raise ValueError(f"Only {reachable_passes}/{len(passes)} passes connected by land")

    lines = [
        "{",
        '  "schema_version": "2.0",',
        '  "description": "大地图 100x70 奇数列下移六角地形；无河流/渡口，保留城市与固定关隘坐标",',
        f'  "map_width": {WIDTH},',
        f'  "map_height": {HEIGHT},',
        '  "rows": [',
    ]
    lines.extend("    " + json.dumps(row, ensure_ascii=False) + ("," if y < HEIGHT - 1 else "")
                 for y, row in enumerate(rows))
    lines += ["  ]", "}"]
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {OUT}: {dict(counts)}, {reachable} cities connected, {len(passes)} passes")


if __name__ == "__main__":
    main()
