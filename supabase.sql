-- Passo a Passo: estrutura do banco.
-- Cole tudo no Supabase em SQL Editor > New query e clique em Run.

create table if not exists public.tasks (
  id          text primary key,
  title       text not null default '',
  descr       text not null default '',
  scope       text not null default 'equipe',   -- 'equipe' (empresa) ou 'pessoal'
  who         text not null default '',         -- id da pessoa em members
  prio        text not null default 'media',    -- 'alta' | 'media' | 'baixa'
  status      text not null default 'afazer',   -- 'afazer' | 'feito'
  due         date,
  steps       jsonb not null default '[]',      -- [{id, text, done}]
  created_at  bigint not null default 0,
  created_by  text not null default ''
);

create table if not exists public.members (
  id          text primary key,
  name        text not null,
  created_at  timestamptz not null default now()
);

-- Só quem está logado lê e grava.
alter table public.tasks   enable row level security;
alter table public.members enable row level security;

drop policy if exists "logados leem e gravam tarefas" on public.tasks;
create policy "logados leem e gravam tarefas" on public.tasks
  for all to authenticated using (true) with check (true);

drop policy if exists "logados leem e gravam pessoas" on public.members;
create policy "logados leem e gravam pessoas" on public.members
  for all to authenticated using (true) with check (true);

-- Atualização em tempo real entre os aparelhos.
alter publication supabase_realtime add table public.tasks;
alter publication supabase_realtime add table public.members;
