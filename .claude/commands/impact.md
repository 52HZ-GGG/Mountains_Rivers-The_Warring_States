# /impact — 查询文件影响范围

根据知识图谱分析修改指定文件的影响范围。

## 输入

$ARGUMENTS — 文件名或系统名（如 `data_manager.gd`、`战斗系统`、`外交`）

## 执行步骤

1. 读取 `.understand-anything/knowledge-graph.json`
2. 在 nodes 中查找匹配的文件节点（模糊匹配文件名或标签）
3. 在 edges 中查找所有 `depends_on` 关系：
   - **上游**：该文件依赖的其他文件（修改它时不影响这些，但需要它们正常工作）
   - **下游**：依赖该文件的其他文件（修改它时这些文件可能出问题）
4. 查找 `configures`、`reads_from`、`writes_to` 等数据流边
5. 查找 `related_to` 边获取相关文件

## 输出格式

```
## 影响分析：<文件名>

### 下游依赖（修改此文件需验证）
- file_a.gd — 原因：depends_on
- file_b.gd — 原因：depends_on

### 上游依赖（此文件依赖，需确保正常）
- file_c.gd
- file_d.gd

### 数据流
- reads_from: data/xxx.json
- writes_to: data/yyy.json

### 相关文件
- file_e.gd — related_to

### 建议验证的测试
- test_xxx.gd（如果存在）
```

## 注意事项

- 如果找不到精确匹配，列出最接近的候选
- 只显示直接依赖，不展开传递依赖（避免信息过载）
- 输出简洁，每个文件一行带简要原因
