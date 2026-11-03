# 安全设计

- **设备密钥**：首次登录生成 X25519 密钥对；私钥只存 `flutter_secure_storage`（Android Keystore / iOS Keychain），公钥上传 `profiles.public_key`。
- **共享密钥**：`X25519(私钥, 对方公钥)` → `HKDF-SHA256`（info 含排序后的双方公钥）→ 32 字节对称密钥。
- **加密**：XChaCha20-Poly1305，每条数据独立随机 24 字节 nonce；AAD 绑定 `user_id|时间戳/场景`，密文不能被搬运到别的行。
- **安全码**：双方公钥排序后 SHA-256，取前 10 字节生成 5×4 位数字，配对后当面核对以防中间人（TOFU 前提下的带外校验）。
- **密钥备份**：口令 → Argon2id（m=19 MiB, t=2）→ 加密私钥；备份到 `profiles.key_backup` 或导出二维码。服务器只见密文。
- **RLS**：所有表开启；只有同一 couple 的双方可读写相应行；配对/解除/清除/保留期/心跳走 RPC。anon key 在客户端，**service_role 永不出现在客户端**。
- **有意保留的明文**：`presence.heartbeat_at` 与 `paused`（失联判断需要）、各表的 `user_id/couple_id/时间戳`。这是取舍：服务器能看到“你们何时在线”，但看不到位置。
- **客户端细节**：切后台时模糊遮罩（防最近任务预览泄露）；日志中的坐标一律替换为 `***`；本机 SQLite 缓存的是解密后的坐标（位于应用私有目录，未做数据库级加密 —— 已知限制）。
