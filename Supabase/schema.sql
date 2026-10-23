create extension if not exists "pgcrypto";

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  symbol text not null default 'tag.fill',
  color_name text not null default 'teal',
  created_at timestamptz not null default now()
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null,
  amount_cents integer not null check (amount_cents > 0),
  kind text not null check (kind in ('expense', 'income')),
  category_id uuid not null references public.categories(id) on delete restrict,
  date date not null default current_date,
  note text not null default '',
  is_fixed boolean not null default false,
  repeats_monthly boolean not null default false,
  receipt_path text,
  receipt_file_name text,
  receipt_mime_type text,
  receipt_uploaded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.transactions add column if not exists receipt_path text;
alter table public.transactions add column if not exists receipt_file_name text;
alter table public.transactions add column if not exists receipt_mime_type text;
alter table public.transactions add column if not exists receipt_uploaded_at timestamptz;

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  title text not null,
  limit_cents integer not null check (limit_cents > 0),
  period text not null default 'month' check (period in ('day', 'week', 'month', 'all_time')),
  month date not null default date_trunc('month', now())::date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.budgets add column if not exists period text not null default 'month';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'budgets_period_check'
      and conrelid = 'public.budgets'::regclass
  ) then
    alter table public.budgets
      add constraint budgets_period_check
      check (period in ('day', 'week', 'month', 'all_time'));
  end if;
end $$;

create table if not exists public.debts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  friend_name text not null,
  amount_cents integer not null check (amount_cents > 0),
  note text not null default '',
  due_date date,
  is_paid boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.categories enable row level security;
alter table public.transactions enable row level security;
alter table public.budgets enable row level security;
alter table public.debts enable row level security;

create policy "Users can manage own categories"
on public.categories for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can manage own transactions"
on public.transactions for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can manage own budgets"
on public.budgets for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can manage own debts"
on public.debts for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

grant select, insert, update, delete on public.categories to authenticated;
grant select, insert, update, delete on public.transactions to authenticated;
grant select, insert, update, delete on public.budgets to authenticated;
grant select, insert, update, delete on public.debts to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('receipts', 'receipts', false, 5242880, array['image/jpeg', 'image/png', 'image/heic'])
on conflict (id) do update
set public = false,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/heic'];

create policy "Users can read own receipts"
on storage.objects for select
to authenticated
using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can upload own receipts"
on storage.objects for insert
to authenticated
with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can update own receipts"
on storage.objects for update
to authenticated
using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can delete own receipts"
on storage.objects for delete
to authenticated
using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
