# Passo a Passo — gerenciador de tarefas

Site interno de uma empresa pequena (dois sócios hoje, pode crescer) para organizar tarefas da empresa e pessoais. A ideia central: cada tarefa é quebrada em passos pequenos, para que na hora de fazer seja só executar.

O dono do projeto não é programador. Responda em português, explique em linguagem simples e diga o que foi e o que não foi testado.

## Arquitetura

Site estático, sem build e sem framework.

- `index.html` — o sistema inteiro: CSS, HTML e JavaScript puro em um arquivo só.
- `config.js` — URL e chave `anon` do projeto Supabase (`window.PP_CONFIG`). A chave `anon` é pública por natureza; a `service_role` nunca entra no repositório.
- `supabase.sql` — estrutura do banco (tabelas, RLS, realtime). Já foi aplicada no projeto; alterações de estrutura devem ser acrescentadas aqui e rodadas no SQL Editor do Supabase.
- `passo-a-passo.html` — versão antiga, que rodava como artefato no claude.ai com outro armazenamento. Não é usada pelo site; não editar.
- `.claude/dev-server.js` — servidor estático para teste local (`node .claude/dev-server.js`, porta 4321).

## Banco (Supabase)

- `tasks`: `id`, `title`, `descr`, `scope` (`equipe` = empresa, `pessoal`), `who` (id em `members`), `prio` (`alta`/`media`/`baixa`), `status` (`afazer`/`feito`), `due` (date, pode ser nulo), `steps` (jsonb: `[{id, text, done}]`), `created_at` (ms), `created_by`.
- `members`: `id`, `name`, `created_at`. É a lista de pessoas da equipe, separada dos usuários de login.
- RLS: qualquer usuário autenticado lê e grava tudo. Não há cadastro aberto; os logins são criados à mão em Authentication > Users.
- Realtime ligado nas duas tabelas; o site refaz a leitura a cada mudança.

## Como o código funciona

- Estado em um objeto `S`; `render()` redesenha a tela inteira com `innerHTML`. Eventos por delegação em `document`, via atributos `data-act`.
- Gravação otimista: `writeTask`/`removeTask` atualizam a tela na hora e enfileiram uma gravação por tarefa (`pending`/`inflight`/`over`). `toRow`/`fromRow` convertem entre o objeto do site e a linha do banco.
- Sem `config.js` válido ou sem a biblioteca do Supabase, o site cai em "modo local" (localStorage), com um aviso na tela.
- Depois do login, cada pessoa escolhe o próprio nome na lista da equipe; a escolha fica no navegador (`pp_me`).

## Regras de produto já decididas

- Duas abas: **Empresa** mostra só tarefas `equipe`; **Pessoal** mostra só tarefas `pessoal` da pessoa escolhida. Tarefa da empresa nunca aparece no Pessoal, mesmo atribuída à pessoa.
- Por enquanto todos veem as tarefas pessoais de todos (decisão do dono para o início).
- Só lista, sem quadro kanban. Só dois estados: a fazer e feito.
- Período: **Tudo**, **Semana** (prazo até domingo, agrupado por dia) e **Hoje** (prazo até hoje, com atrasadas). Tarefas sem prazo só aparecem em Tudo.
- Na Semana, tarefas mudam de dia arrastando. "Fazer hoje" troca o prazo para hoje em qualquer visão.
- "↑ Antes" / "Depois ↓" **não mudam o dia**: trocam a ordem com a tarefa vizinha que tem a mesma prioridade e o mesmo prazo. Só aparecem quando existe essa vizinha. A ordem dentro do grupo vem de `createdAt` (`created_at` no banco), que funciona como campo de ordem: os botões trocam os valores das duas tarefas.
- Subtarefas têm caixas para ticar (na página da tarefa e na lista, em "Subtarefas ▾"). Ticar todas conclui a tarefa sozinha; desmarcar uma reabre.
- Clicar numa tarefa "entra" nela: página inteira (não painel lateral) com as **subtarefas** em primeiro plano; situação, prioridade, responsável, prazo e observações ficam recolhidos em "Detalhes". Na tela o nome é "subtarefas"; no banco e no código continuam sendo `steps`.
- Na lista, cada tarefa mostra a próxima subtarefa pendente e uma barra de progresso.
- Na página da tarefa, os botões do rodapé ("Criar tarefa", "Excluir tarefa", "Pronto") ficam todos à esquerda, lado a lado. Nada clicável no canto inferior direito: o selo da Netlify cobre essa área. Enter no título leva ao campo de subtarefa.
- Visual: fundo mais escuro e tarefas em blocos claros com borda, para contraste nítido; temas claro e escuro pelos tokens em `:root`.

## Ainda não feito

- Hospedagem do site (Vercel ou Netlify ligados a este repositório).
- Tarefas pessoais privadas, vários quadros, e IA para gerar o passo a passo. Tarefas privadas exigem ligar cada pessoa de `members` ao usuário de login (hoje não há ligação); a IA exige uma função no servidor para guardar a chave.

## Pendências anotadas (análise de 13/10/2026)

Segurança:

- **Urgente:** o cadastro está aberto no Supabase (`disable_signup: false`) e o repositório é público. Desligar "Allow new users to sign up" em Authentication > Sign In / Providers antes de hospedar.
- Ids de tarefa, subtarefa e pessoa entram no HTML sem `esc()`.
- Sessão expirada mostra "não foi possível carregar" em vez da tela de login.

Defeitos (vistos lendo o código, não reproduzidos):

1. ~~Depois de gravar, a tela voltava por um instante à versão antiga~~ — corrigido em 14/10/2026: gravação bem-sucedida atualiza `S.remote`, e leituras que começaram antes de uma gravação terminar são descartadas e refeitas (`wrote`/`again` em `fetchAll`).
2. Falha de gravação descarta a alteração, sem nova tentativa.
3. Fechar a página de nova tarefa (Voltar ou Esc) descarta tudo sem perguntar.
4. Excluir uma pessoa deixa tarefas órfãs: as pessoais somem; as da empresa não entram no filtro "Sem responsável".
5. Duas pessoas editando a mesma tarefa: a última gravação sobrescreve a outra (linha inteira, com os `steps`).
6. A leitura traz no máximo 1.000 tarefas e as feitas nunca são arquivadas.
7. Rodar `supabase.sql` de novo dá erro nas duas linhas `alter publication`.

Limpeza:

- Restos do quadro kanban em `index.html`: estilos `.board`/`.col`/`.card`, `cardHtml`, campo `area`, `pp_view`, `fArea`.
- A tela de equipe ainda diz "Não há senha nesta versão".
- `passo-a-passo.html` pode sair do repositório.
