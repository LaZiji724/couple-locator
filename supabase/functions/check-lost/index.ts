// 可选 Edge Function：失联检测。App 端也会本地定时检查，本函数只读明文心跳，不接触位置数据。
// 部署：supabase functions deploy check-lost
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const auth = req.headers.get("Authorization") ?? "";
  // 使用用户 JWT + anon key，受 RLS 约束；绝不使用 service_role
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: auth } } },
  );
  const { data: me } = await supabase.auth.getUser();
  if (!me.user) return new Response("unauthorized", { status: 401 });
  const url = new URL(req.url);
  const thresholdMin = Math.min(Math.max(Number(url.searchParams.get("minutes") ?? 30), 5), 1440);

  const { data: partner } = await supabase.rpc("partner_id");
  if (!partner) return Response.json({ lost: false, reason: "no_partner" });
  const { data: p } = await supabase.from("presence").select("*").eq("user_id", partner).maybeSingle();
  if (!p) return Response.json({ lost: false, reason: "no_presence" });

  const now = Date.now();
  const pausedUntil = p.paused_until ? new Date(p.paused_until).getTime() : null;
  const paused = p.paused && (pausedUntil === null || pausedUntil > now);
  const silentMin = Math.floor((now - new Date(p.heartbeat_at).getTime()) / 60000);
  return Response.json({ lost: !paused && silentMin >= thresholdMin, paused, silentMin });
});
