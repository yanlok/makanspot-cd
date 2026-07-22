# Supabase Database Migration Guide

## Prerequisites

- [Supabase CLI](https://supabase.com/docs/guides/cli/getting-started#installing-the-supabase-cli) installed on your machine

## Quick Steps

### 1. Login to Supabase

```bash
supabase login
```

### 2. Link the project

Run this command in the project root (`makanspot/`):

```bash
supabase link --project-ref npmdrgpypkozdjtiplmf
```

When prompted for a database password, enter the project's DB password (get it from **Project Settings → Database → Database password**).

### 3. Push all migrations to the database

```bash
supabase db push
```

This applies all SQL files inside `supabase/migrations/` in order.

### 4. *(Optional)* Seed sample data

If you want test data (restaurants, categories, achievements):

```bash
supabase db execute --file supabase/seed.sql
```

Or paste the contents of `supabase/seed.sql` into the Supabase Dashboard **SQL Editor**.

## How It Works

| Step | What it does |
|------|-------------|
| `supabase link` | Links your local `supabase/` folder to the remote Supabase project |
| `supabase db push` | Compares local migrations vs remote, applies any new ones |
| `supabase db execute --file seed.sql` | Runs a one-off SQL script (not tracked as a migration) |

## For Adding Future Migrations

```bash
supabase migration new your_migration_name
```

Write your SQL in the generated file, then push:

```bash
supabase db push
```

That's it. The CLI handles ordering and keeps track of what's been applied.
