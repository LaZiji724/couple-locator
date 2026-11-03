-- 情侣位置 App：核心表、RLS、RPC、pg_cron 过期清理
-- 在 Supabase SQL Editor 中整体执行，或 `supabase db push`。

create extension if not exists pgcrypto;
create extension if not exists pg_cron;

-- ───────────── 表 ─────────────
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null default '',
  avatar_emoji text,
  avatar_url text,
  theme_id text not null default 'coral',
  public_key text,                -- base64 X25519 公钥
  key_backup text,                -- 口令加密后的私钥备份(密文)
  created_at timestamptz not null default now()
);

create table public.couples (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null unique references auth.users(id) on delete cascade,
  user_b uuid not null unique references auth.users(id) on delete cascade,
  retention_a int not null default 30 check (retention_a in (7,30,90,180)),
  retention_b int not null default 30 check (retention_b in (7,30,90,180)),
  created_at timestamptz not null default now(),
  check (user_a <> user_b)
);

create table public.invites (
  code text primary key,
  creator uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  used boolean not null default false
);

create table public.locations (
  id bigint generated always as identity primary key,
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  client_id text not null,
  client_ts bigint not null,       -- 客户端毫秒时间戳(明文，必要元数据)
  cipher text not null,
  nonce text not null,
  created_at timestamptz not null default now(),
  unique (user_id, client_id, client_ts)   -- 补传幂等
);
create index locations_couple_ts on public.locations (couple_id, user_id, client_ts desc);

create table public.presence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  couple_id uuid references public.couples(id) on delete cascade,
  heartbeat_at timestamptz not null default now(),
  paused_until timestamptz,        -- 暂停共享到何时；'infinity' 表示直到手动恢复
  paused boolean not null default false
);

create table public.status (
  user_id uuid primary key references auth.users(id) on delete cascade,
  couple_id uuid references public.couples(id) on delete cascade,
  cipher text not null,
  nonce text not null,
  updated_at timestamptz not null default now()
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('arrived','ack','sos','sos_cancel','sos_ack','poke')),
  cipher text not null,
  nonce text not null,
  created_at timestamptz not null default now()
);
create index events_couple_ts on public.events (couple_id, created_at desc);

create table public.pins (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  cipher text not null,
  nonce text not null,
  updated_at timestamptz not null default now(),
  deleted boolean not null default false
);

create table public.diag_logs (        -- 服务端上报日志（不含坐标）
  id bigint generated always as identity primary key,
  user_id uuid not null,
  level text not null,
  message text not null,
  created_at timestamptz not null default now()
);

-- ───────────── 辅助函数 ─────────────
create or replace function public.my_couple_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.couples where user_a = auth.uid() or user_b = auth.uid() limit 1
$$;

create or replace function public.partner_id() returns uuid
language sql stable security definer set search_path = public as $$
  select case when user_a = auth.uid() then user_b else user_a end
  from public.couples where user_a = auth.uid() or user_b = auth.uid() limit 1
$$;

-- ───────────── RLS ─────────────
alter table public.profiles enable row level security;
alter table public.couples enable row level security;
alter table public.invites enable row level security;
alter table public.locations enable row level security;
alter table public.presence enable row level security;
alter table public.status enable row level security;
alter table public.events enable row level security;
alter table public.pins enable row level security;
alter table public.diag_logs enable row level security;

-- profiles: 自己可读写；伴侣可读
create policy profiles_select on public.profiles for select
  using (id = auth.uid() or id = public.partner_id());
create policy profiles_insert on public.profiles for insert with check (id = auth.uid());
create policy profiles_update on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

-- couples: 双方可读；写入只能通过 RPC（无 insert/update/delete 策略）
create policy couples_select on public.couples for select
  using (user_a = auth.uid() or user_b = auth.uid());

-- invites: 客户端不可直接访问（只走 RPC）
-- （无策略 = 全部拒绝）

-- locations: 同 couple 可读；只能写自己的
create policy loc_select on public.locations for select using (couple_id = public.my_couple_id());
create policy loc_insert on public.locations for insert
  with check (user_id = auth.uid() and couple_id = public.my_couple_id());
create policy loc_delete on public.locations for delete using (user_id = auth.uid());

-- presence
create policy presence_select on public.presence for select
  using (user_id = auth.uid() or user_id = public.partner_id());
create policy presence_insert on public.presence for insert with check (user_id = auth.uid());
create policy presence_update on public.presence for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- status
create policy status_select on public.status for select
  using (user_id = auth.uid() or user_id = public.partner_id());
create policy status_insert on public.status for insert
  with check (user_id = auth.uid() and couple_id = public.my_couple_id());
create policy status_update on public.status for update
  using (user_id = auth.uid()) with check (user_id = auth.uid() and couple_id = public.my_couple_id());

-- events
create policy events_select on public.events for select using (couple_id = public.my_couple_id());
create policy events_insert on public.events for insert
  with check (user_id = auth.uid() and couple_id = public.my_couple_id());

-- pins: 双方可读写（共同可编辑）
create policy pins_select on public.pins for select using (couple_id = public.my_couple_id());
create policy pins_insert on public.pins for insert
  with check (user_id = auth.uid() and couple_id = public.my_couple_id());
create policy pins_update on public.pins for update
  using (couple_id = public.my_couple_id()) with check (couple_id = public.my_couple_id());
create policy pins_delete on public.pins for delete using (couple_id = public.my_couple_id());

-- diag_logs
create policy diag_insert on public.diag_logs for insert with check (user_id = auth.uid());
create policy diag_select on public.diag_logs for select using (user_id = auth.uid());

-- ───────────── RPC（security definer，防止客户端伪造） ─────────────
create or replace function public.create_invite() returns text
language plpgsql security definer set search_path = public as $$
declare c text; i int := 0;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.my_couple_id() is not null then raise exception 'already paired'; end if;
  delete from invites where creator = auth.uid() or expires_at < now();
  loop
    c := lpad((floor(random()*1000000))::int::text, 6, '0');
    begin
      insert into invites(code, creator, expires_at) values (c, auth.uid(), now() + interval '10 minutes');
      return c;
    exception when unique_violation then
      i := i + 1; if i > 20 then raise; end if;
    end;
  end loop;
end $$;

create or replace function public.redeem_invite(p_code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare inv invites; cid uuid; a uuid; b uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.my_couple_id() is not null then raise exception 'already paired'; end if;
  select * into inv from invites where code = p_code for update;
  if not found or inv.used or inv.expires_at < now() then raise exception 'invalid or expired code'; end if;
  if inv.creator = auth.uid() then raise exception 'cannot redeem own code'; end if;
  if exists (select 1 from couples where user_a = inv.creator or user_b = inv.creator) then
    raise exception 'inviter already paired';
  end if;
  a := least(inv.creator, auth.uid()); b := greatest(inv.creator, auth.uid());
  insert into couples(user_a, user_b) values (a, b) returning id into cid;
  update invites set used = true where code = p_code;
  update presence set couple_id = cid where user_id in (a, b);
  return cid;
end $$;

-- 解除配对；p_delete_history=true 同时删除历史
create or replace function public.unpair(p_delete_history boolean default true) returns void
language plpgsql security definer set search_path = public as $$
declare cid uuid;
begin
  cid := public.my_couple_id();
  if cid is null then return; end if;
  if p_delete_history then
    delete from locations where couple_id = cid;
    delete from events where couple_id = cid;
    delete from pins where couple_id = cid;
    delete from status where couple_id = cid;
  end if;
  update presence set couple_id = null where couple_id = cid;
  delete from couples where id = cid;
end $$;

-- 清除我的全部数据（不解除配对）
create or replace function public.wipe_my_data() returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from locations where user_id = auth.uid();
  delete from events where user_id = auth.uid();
  delete from pins where user_id = auth.uid();
  delete from status where user_id = auth.uid();
  delete from diag_logs where user_id = auth.uid();
end $$;

create or replace function public.set_retention(p_days int) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_days not in (7,30,90,180) then raise exception 'invalid retention'; end if;
  update couples set retention_a = p_days where user_a = auth.uid();
  update couples set retention_b = p_days where user_b = auth.uid();
end $$;

-- 心跳：服务端时间为准（防客户端伪造时钟）
create or replace function public.heartbeat(p_paused boolean default false, p_paused_until timestamptz default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into presence(user_id, couple_id, heartbeat_at, paused, paused_until)
  values (auth.uid(), public.my_couple_id(), now(), p_paused, p_paused_until)
  on conflict (user_id) do update
    set heartbeat_at = now(), couple_id = excluded.couple_id,
        paused = excluded.paused, paused_until = excluded.paused_until;
end $$;

revoke all on function public.create_invite, public.redeem_invite, public.unpair, public.wipe_my_data,
  public.set_retention, public.heartbeat from public, anon;
grant execute on function public.create_invite, public.redeem_invite, public.unpair, public.wipe_my_data,
  public.set_retention, public.heartbeat to authenticated;

-- 仅启用 Realtime 需要的表
alter publication supabase_realtime add table public.locations, public.presence,
  public.status, public.events, public.pins, public.couples;

-- ───────────── E4 数据自动过期（取双方保留期较短者） ─────────────
create or replace function public.purge_expired() returns void
language sql security definer set search_path = public as $$
  delete from locations l using couples c
   where l.couple_id = c.id
     and l.created_at < now() - make_interval(days => least(c.retention_a, c.retention_b));
  delete from events e using couples c
   where e.couple_id = c.id
     and e.created_at < now() - make_interval(days => least(c.retention_a, c.retention_b));
  delete from diag_logs where created_at < now() - interval '14 days';
  delete from invites where expires_at < now() - interval '1 day';
$$;

select cron.schedule('purge-expired', '15 3 * * *', $$select public.purge_expired()$$);
