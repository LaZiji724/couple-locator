# 后端部署（Supabase）完整清单

1. **注册**：https://supabase.com → New project。区域选 **Southeast Asia (Singapore)** 或 **Northeast Asia (Tokyo)**；记下数据库密码。
2. **开启 pg_cron**：Dashboard → Database → Extensions → 启用 `pg_cron`（迁移里也会 `create extension`）。
3. **执行迁移**：Dashboard → SQL Editor → 粘贴 `supabase/migrations/0001_init.sql` → Run。
   或使用 CLI：`supabase link --project-ref <ref> && supabase db push`。
   会创建：profiles / couples / invites / locations / presence / status / events / pins / diag_logs，全部开启 RLS，
   配对/解除/清除/保留期/心跳走 `security definer` RPC，`pg_cron` 每天 03:15 清理过期 locations 与 events（取双方保留期较短者）。
4. **认证设置**（App 使用「用户名 + 密码」，不收集真实邮箱）：Authentication → Providers → Email：保持开启，并**必须关闭 “Confirm email”**（否则注册后无法登录，因为内部邮箱收不到邮件）。
   App 内部把用户名（3–20 位小写字母/数字/下划线，不区分大小写）映射成 `用户名@couple-locator.app` 交给 Supabase Auth；域名可用 `--dart-define=AUTH_EMAIL_DOMAIN=xxx` 或 env 文件覆盖。
   注意：没有真实邮箱 = **忘记密码无法找回**；请提醒双方牢记密码，并在「设置 → 密钥备份」备份加密密钥。若日后想允许改密，可再接入绑定邮箱流程。
5. **Realtime**：迁移已把 locations/presence/status/events/pins/couples 加入 `supabase_realtime` publication；确认 Database → Replication 中可见。
6. **取密钥**：Project Settings → API：
   - `Project URL` → `SUPABASE_URL`
   - `anon public` → `SUPABASE_ANON_KEY`
   - ⚠️ **绝不要**把 `service_role` 放进 App 或仓库。
7. **（可选）Edge Function**：`supabase functions deploy check-lost`。失联提醒默认由 App 端定时检查（前台每分钟 + WorkManager 约 15 分钟），该函数只是可选的服务端检查入口，只读明文心跳。
8. **填写 App 配置**：`cp env/example.json env/dev.json`，填 `SUPABASE_URL`、`SUPABASE_ANON_KEY`、高德三个 Key。
9. **验证 RLS**（建议）：用第三个账号的 anon 登录，对 `locations` 执行 `select *`，应返回 0 行；直接读到的 `cipher` 字段是 base64 密文。

## 表与安全速览
| 表 | 明文字段 | 密文 |
|---|---|---|
| locations | couple_id, user_id, client_id, client_ts | cipher+nonce（坐标/精度/速度） |
| status | user_id, updated_at | cipher+nonce（电量/网络/移动状态） |
| events | couple_id, user_id, kind, created_at | cipher+nonce（位置/emoji/文字） |
| pins | couple_id, user_id, updated_at | cipher+nonce（名称/坐标/备注/照片） |
| presence | user_id, heartbeat_at, paused | —（有意明文，供失联判断，不含位置） |
