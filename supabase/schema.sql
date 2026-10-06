-- CIMO 공유 저장소 스키마 (현재 운영 중인 앱이 사용하는 구조를 문서화한 파일)
-- 새 Supabase 프로젝트에 같은 구조를 만들 때: SQL Editor 에 통째로 붙여넣고 Run. 여러 번 실행해도 안전해요.
-- 앱(index.html)은 아래 컬럼만 사용해요.
--   rooms        : code, data, updated_at
--   participants : room_code, person_id, data, updated_at

-- 1) 방: 앱의 room 객체(이름, 날짜, 시간대, 필참자, 확정 일정 등)를 data(JSONB)에 그대로 저장
create table if not exists public.rooms (
  code        text primary key,               -- 6자리 방 코드
  data        jsonb not null,
  updated_at  timestamptz not null default now()
);

-- 2) 참여자: 앱의 person 객체({id, name, title, cells})를 data(JSONB)에 그대로 저장
create table if not exists public.participants (
  room_code   text not null references public.rooms(code) on delete cascade,
  person_id   text not null,                  -- 앱의 personKey(이름|직급)
  data        jsonb not null,
  updated_at  timestamptz not null default now(),
  -- 한 방에 같은 사람은 1행만(upsert on_conflict 대상). PK라서 Realtime 대상이어도 UPDATE가 가능해요.
  constraint participants_pkey primary key (room_code, person_id)
);

-- 3) RLS: 로그인 없이 링크/코드로 쓰는 앱이라 anon 에게 조회·생성·수정을 허용하고, 삭제는 허용하지 않아요.
alter table public.rooms        enable row level security;
alter table public.participants enable row level security;

drop policy if exists "rooms_select"        on public.rooms;
drop policy if exists "rooms_insert"        on public.rooms;
drop policy if exists "rooms_update"        on public.rooms;
drop policy if exists "participants_select" on public.participants;
drop policy if exists "participants_insert" on public.participants;
drop policy if exists "participants_update" on public.participants;

create policy "rooms_select" on public.rooms for select to anon, authenticated using (true);
create policy "rooms_insert" on public.rooms for insert to anon, authenticated with check (true);
create policy "rooms_update" on public.rooms for update to anon, authenticated using (true) with check (true);

create policy "participants_select" on public.participants for select to anon, authenticated using (true);
create policy "participants_insert" on public.participants for insert to anon, authenticated with check (true);
create policy "participants_update" on public.participants for update to anon, authenticated using (true) with check (true);

grant select, insert, update on public.rooms, public.participants to anon, authenticated;

-- 4) Realtime: 두 테이블의 변경을 구독할 수 있게 publication 에 추가
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='rooms') then
    alter publication supabase_realtime add table public.rooms;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='participants') then
    alter publication supabase_realtime add table public.participants;
  end if;
end $$;
