# /update-deps — 从知识图谱更新依赖影响图谱

## 执行

运行以下命令：

```bash
python tools/extract_impact_map.py .
```

然后确认输出文件已更新。

## 前提

需要先运行 `/understand` 生成最新的 `knowledge-graph.json`。
如果图谱不存在或过时，先执行 `/understand`。
