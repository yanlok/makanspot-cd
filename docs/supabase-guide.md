# Supabase Database & Pipeline Guide

> A practical walkthrough for managing the MakanSpot database, deploying Edge Functions, and running the data pipeline.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Schema Migrations](#schema-migrations)
- [Edge Functions](#edge-functions)
- [Data Pipeline (Ingest → Enrich → Approve)](#data-pipeline-ingest--enrich--approve)
- [Common Tasks](#common-tasks)
- [Troubleshooting](#troubleshooting)

---
###
## Prerequisites

- **Supabase CLI** — [Install guide](https://supabase.com/docs/guides/cli/getting-started#installing-the-supabase-cli)

---

## Schema Migrations

Migrations live in `supabase/migrations/` as numbered SQL files. They're applied in order, so **never** edit a file after it's been applied.

### First-time setup

```bash
# Login to your Supabase account
supabase login

# Link this project to your local supabase/ folder
supabase link --project-ref npmdrgpypkozdjtiplmf
```

You'll be prompted for the database password — find it in the Supabase Dashboard under **Project Settings → Database → Database password**.

### Apply migrations

```bash
supabase db push
```

That's it. New migrations get applied automatically; already-applied ones are skipped.

### Create a new migration

```bash
supabase migration new your_migration_name
```

Write your SQL in the generated file, then push:

```bash
supabase db push
```

### Seed sample data (optional)

```bash
supabase db execute --file supabase/seed.sql
```

---

## Edge Functions

Edge Functions live in `supabase/functions/` and run on Deno.

### Deploy a function

```bash
supabase functions deploy <function-name> --no-verify-jwt
```

Key functions:

| Function | Purpose |
|----------|---------|
| `ingest-scraped-posts` | Loads raw scraped data into `scraped_posts` table |
| `enrich-scraped-posts` | Extracts venues from captions (LLM → geocode → Google Places → database) |

### Set environment secrets

```bash
# Required — LLM provider (OpenAI or compatible)
supabase secrets set OPENAI_API_KEY=sk-...

# Required — Google Geocoding + Places (use one key with both APIs enabled)
supabase secrets set GOOGLE_GEOCODING_KEY=AIza...

# Optional — OpenAI model override
supabase secrets set OPENAI_MODEL=gpt-4o-mini

# Optional — Use DeepSeek instead of OpenAI
supabase secrets set LLM_API_KEY=sk-<deepseek-key>
supabase secrets set LLM_BASE_URL=https://api.deepseek.com
supabase secrets set LLM_MODEL=deepseek-chat
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically by Supabase.

---

## Data Pipeline (Ingest → Enrich → Approve)

The pipeline converts raw scraped posts into structured restaurants.

```
Apify JSON → scraped_posts → restaurants (pending approval) → live
```

### Quick start — one command

Drop your Apify TikTok JSON export into the **`datasets/`** folder, then run:

```bash
node scripts/run_pipeline.mjs
```

This automatically:
1. Picks the newest `.json` from `datasets/`
2. Loads records into `scraped_posts` (deduped by URL)
3. Enriches each post (LLM extracts venue → geocodes → fetches Google Places data)
4. Creates restaurants (marked `is_approved = false`)

### Useful flags

```bash
# Use a specific dataset file
node scripts/run_pipeline.mjs "C:/data/dataset.json"

# Skip ingest, just process what's already staged
node scripts/run_pipeline.mjs --enrich-only

# Rebuild all restaurants from scratch (reuses stored LLM extraction — no extra cost)
node scripts/run_pipeline.mjs --reprocess
```

### Approve new restaurants

Promoted restaurants land with `is_approved = false`. Use the admin dashboard to review and approve them. Only approved restaurants show in the public app.

### What about duplicates?

The pipeline merges posts about the same venue into one restaurant row:

- Same name within ~13km → merged
- Prefix match (e.g. "Village Park" vs "Village Park Restaurant") within ~450m → merged
- Engagement is aggregated across all source posts
- The highest-play video becomes the primary source (photo, URL)

---

## Common Tasks

| Task | Command |
|------|---------|
| Login to Supabase | `supabase login` |
| Link project | `supabase link --project-ref npmdrgpypkozdjtiplmf` |
| Push migrations | `supabase db push` |
| Create a migration | `supabase migration new <name>` |
| Deploy a function | `supabase functions deploy <name> --no-verify-jwt` |
| Set a secret | `supabase secrets set KEY=value` |
| Run pipeline | `node scripts/run_pipeline.mjs` |
| Reprocess everything | `node scripts/run_pipeline.mjs --reprocess --enrich-only` |
| Check enrichment status | `node -e "fetch('https://npmdrgpypkozdjtiplmf.functions.supabase.co/enrich-scraped-posts',{method:'POST',headers:{'Authorization':'Bearer sb_publishable_9qvkHzyVPR6SCHtRk9zjVQ_vMODyBCH','apikey':'sb_publishable_9qvkHzyVPR6SCHtRk9zjVQ_vMODyBCH','Content-Type':'application/json'},body:JSON.stringify({action:'status'})}).then(r=>r.json()).then(console.log)"` |

---

## Connecting the Flutter app

The app talks to Supabase through `supabase_flutter`. Credentials are **not**
committed — provide them at build/run time with `--dart-define`, or edit the
constants in `lib/core/config/supabase_config.dart`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://npmdrgpypkozdjtiplmf.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

The anon key lives in the Supabase Dashboard under **Project Settings → API**.

Notes:

- Without the defines the app falls back to the in-memory fixture repository,
  so it still runs before the backend is configured.
- Registration uses Supabase Auth with email confirmation (default). The OTP
  screen verifies the emailed code; the signup trigger in migration
  `20260804000012_user_profile_on_signup.sql` creates the matching
  `public.users` profile automatically.
- Enable email confirmation: **Authentication → Providers → Email → Confirm
  email**.

---

## Troubleshooting

### "Cannot find module 'Deno'" in VS Code

These files run on **Deno**, not Node.js. Your IDE may show false-positive errors. Install the [Deno extension](https://marketplace.visualstudio.com/items?itemName=denoland.vscode-deno) to resolve them locally.

### Pipeline rows stuck on "failed"

```bash
# Check current status
node scripts/run_pipeline.mjs --enrich-only

# Push failed rows back to pending
node -e "fetch('https://npmdrgpypkozdjtiplmf.functions.supabase.co/enrich-scraped-posts',{method:'POST',headers:{'Authorization':'Bearer sb_publishable_9qvkHzyVPR6SCHtRk9zjVQ_vMODyBCH','apikey':'sb_publishable_9qvkHzyVPR6SCHtRk9zjVQ_vMODyBCH','Content-Type':'application/json'},body:JSON.stringify({action:'status',reset:true})}).then(r=>r.json()).then(console.log)"
```


