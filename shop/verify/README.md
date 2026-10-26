# verify — 验收证据

- `smoke-result.txt`：在本机运行 `setup\smoke-test.ps1` 后生成的最新结果（包含每次请求的摘要；如含临时 Token，请勿外发）。
- `evidence-20261019.txt`：2026-10-19 的脱敏验收摘要，仅保留 PASS/FAIL 与汇总，供交接检查。

重新生成：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ..\setup\smoke-test.ps1
```

验收目标：`PASS=30 FAIL=0 SKIP=0`。
