# Atomize

## Project map

- `src/` is the React/Vite web and PWA client; `godot/` is the native iOS/Android client.
- Shared gameplay fixtures and native test runners live in `scripts/godot/`.
- Supabase schema changes belong in `supabase/migrations/`. Follow [provider ownership](PROVIDERS.md) for hosted services; `backend:reset` targets the local database.
- Setup and web checks are in [README.md](README.md). Native setup, exports, and test commands are in [godot/README.md](godot/README.md).

## Changes and verification

- Use Bun and the scripts in `package.json`. Run checks from the terminal; an editor is not required.
- For gameplay rules or realtime protocol changes, check both clients and run the relevant Godot parity and flow checks.
- Reuse web components, `src/theme.css` tokens, and `src/app-state.ts` copy. For native screens, reuse the existing Godot theme and layout helpers.
- Inspect affected UI states in the browser or Godot. Match state and viewport for before/after PR evidence; documentation-only changes do not need UI captures.
- Keep generated builds, local credentials, and temporary review media out of commits. Preserve unrelated work in shared checkouts.
