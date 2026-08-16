# Provider ownership

Atomize has one production provider path:

- GitHub repository `orangesago/atomize`, branch `main`, is the source of truth.
- Vercel project `Hsi's Lab / atomize` owns the public web deployment. Git
  integration deploys `main`, and the tracked `vercel.json` owns build and
  routing configuration.
- Supabase project `Hsi's Lab / Atomize` owns authentication, PostgreSQL data,
  Realtime, and Storage. Vercel supplies `VITE_SUPABASE_URL` and
  `VITE_SUPABASE_ANON_KEY` to Development, Preview, and Production. Atomize
  does not use a Vercel Marketplace database resource.

Provider project IDs, project references, keys, and tokens stay in provider
storage or ignored local state. The checkout is intentionally unlinked from
hosted Supabase by default. `bun run backend:reset` includes `--local`; use the
separate `backend:types:remote` command only after an explicit maintainer link.

Within the `Hsi's Lab` Supabase organization, Atomize is the one active project
allocated to this repository. Keep the second free-project slot unused. Projects
owned by another Supabase organization are outside Atomize's lifecycle and must
not be changed as part of this repository's maintenance.
