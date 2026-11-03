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

-- ---------------------------------------------------------------------------
-- Finanças (acrescentado em 22/10/2026). Pode rodar este trecho sozinho.
-- Lançamentos de despesas e receitas da empresa. Valores em centavos (R$ 150,00 = 15000).
create table if not exists public.finance (
  id            text primary key,
  kind          text not null default 'despesa',  -- 'despesa' | 'receita'
  amount_cents  bigint not null default 0,
  date          date not null default current_date,
  descr         text not null default '',
  category      text not null default '',
  who           text not null default '',         -- quem pagou/recebeu (id em members); vazio = conta da empresa
  notes         text not null default '',
  created_at    bigint not null default 0,
  created_by    text not null default ''
);

alter table public.finance enable row level security;

drop policy if exists "logados leem e gravam financas" on public.finance;
create policy "logados leem e gravam financas" on public.finance
  for all to authenticated using (true) with check (true);

do $$ begin
  alter publication supabase_realtime add table public.finance;
exception when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- Modelos (acrescentado em 22/10/2026). Pode rodar este trecho sozinho.
-- Moldes reaproveitáveis. kind 'tarefa': data = {desc, prio, who, steps:[texto]}.
create table if not exists public.templates (
  id          text primary key,
  kind        text not null default 'tarefa',
  name        text not null default '',
  data        jsonb not null default '{}',
  created_at  bigint not null default 0,
  created_by  text not null default ''
);

alter table public.templates enable row level security;

drop policy if exists "logados leem e gravam modelos" on public.templates;
create policy "logados leem e gravam modelos" on public.templates
  for all to authenticated using (true) with check (true);

do $$ begin
  alter publication supabase_realtime add table public.templates;
exception when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- Ofertas (acrescentado em 31/10/2026). Pode rodar este trecho sozinho.
-- finance.offer_id vazio = lançamento geral da empresa.
create table if not exists public.offers (
  id          text primary key,
  name        text not null default '',
  status      text not null default 'ativa',   -- 'ativa' | 'pausada' | 'encerrada'
  created_at  bigint not null default 0,
  created_by  text not null default ''
);

alter table public.finance add column if not exists offer_id text not null default '';

alter table public.offers enable row level security;

drop policy if exists "logados leem e gravam ofertas" on public.offers;
create policy "logados leem e gravam ofertas" on public.offers
  for all to authenticated using (true) with check (true);

do $$ begin
  alter publication supabase_realtime add table public.offers;
exception when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- Finanças pessoais (acrescentado em 03/11/2026). Pode rodar este trecho sozinho.
-- Entradas e saídas de cada pessoa, separadas das contas da empresa. Valores em centavos.
-- PRIVADO: cada linha pertence a um login (user_id) e o banco só deixa esse login ler e mexer nela.
-- Diferente das outras tabelas, aqui nem os outros usuários logados enxergam nada.
create table if not exists public.personal_finance (
  id            text primary key,
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind          text not null default 'saida',     -- 'saida' | 'receita'
  amount_cents  bigint not null default 0,
  date          date not null default current_date,
  descr         text not null default '',
  type          text not null default '',          -- saída: 'rapida' | 'lazer' | 'contas' | 'transporte' | 'saude' | 'investimento' | 'outros'
  items         jsonb not null default '[]',       -- [{text, cents}]
  created_at    bigint not null default 0,
  created_by    text not null default ''
);

create index if not exists personal_finance_user_id_idx on public.personal_finance (user_id);

alter table public.personal_finance enable row level security;
revoke all on public.personal_finance from anon;

drop policy if exists "dono le financas pessoais" on public.personal_finance;
create policy "dono le financas pessoais" on public.personal_finance
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "dono cria financas pessoais" on public.personal_finance;
create policy "dono cria financas pessoais" on public.personal_finance
  for insert to authenticated with check (user_id = (select auth.uid()));

drop policy if exists "dono altera financas pessoais" on public.personal_finance;
create policy "dono altera financas pessoais" on public.personal_finance
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists "dono exclui financas pessoais" on public.personal_finance;
create policy "dono exclui financas pessoais" on public.personal_finance
  for delete to authenticated using (user_id = (select auth.uid()));

do $$ begin
  alter publication supabase_realtime add table public.personal_finance;
exception when duplicate_object then null;
end $$;
