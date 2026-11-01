# verify — 验收证据

- [`fresh-machine-20261027/`](fresh-machine-20261027/README.md)：2026-10-27 本地模拟换机验收，包含源码/运行包各 30 项脱敏冒烟结果、22 项 HTTP 检查、10 项数据库校验、回执与浏览器截图；不等同真实异机或跨设备网络验收。
- `smoke-result.txt`：在本机运行 `setup\smoke-test.ps1` 后生成的最新结果（包含每次请求的摘要；如含临时 Token，请勿外发）。
- `evidence-20261019.txt`：2026-10-19 的脱敏验收摘要，仅保留 PASS/FAIL 与汇总，供交接检查。
- `backend-20261019.txt`：`ruoyi-mall` 后端规模、接口分布、关键一致性实现定位与运行验收摘要（为 AI-010/AI-011 补录取证；采集对象与 2026-10-19 验收版本逐字节一致）。
- `mall-frontend-20261026.txt`：2026-10-26 管理端商城前端交付证据（33 个新增文件清单、静态自检结果、`npm.cmd run build:prod` 构建结果、接口契约与后端 Controller/DTO 对照、未做项与已知偏差）。
- `integration-20261026.txt`：2026-10-26 协作者 `main` 分支整合证据（双方基线、834 个纯重命名 + 44 个新增差异、合并提交 `d439bb5`、后端逐字节一致校验、前端自检与生产构建实测、环境适配与未做项）。

重新生成：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ..\setup\smoke-test.ps1
```

验收目标：`PASS=30 FAIL=0 SKIP=0`。
