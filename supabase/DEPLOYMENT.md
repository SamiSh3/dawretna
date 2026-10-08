# Atomic swap deployment

This change requires a database migration before the frontend is deployed.

1. Merge the independent application reliability PR first.
2. Inspect the actual Supabase schema and existing RLS policies for `profiles`, `slots`, and `swap_requests`. The SQL uses the existing table row types, identifiers, `created_at`, `date`, `is_cancelled`, `status`, `host_name`, and `requester_name`. Verify these fields and values match production.
3. In a staging database, apply `migrations/20261008_resolve_swap_atomic.sql` in Supabase SQL Editor. The function uses SECURITY INVOKER and therefore requires the current user to be allowed by RLS to update both slots and the request. Do not weaken policies just to make the function work.
4. Test a normal acceptance and rejection, expired request, changed source host, cancelled/past slot, repeated acceptance, concurrent overlapping swaps, anonymous request, unrelated user, and a deliberately denied second-slot update. On every failure verify both hosts and the request status remain unchanged.
5. Once the database tests pass, apply the migration in production and merge the atomic swap frontend PR. Without the migration the frontend reports an error and leaves the pending request intact.

Validation in this environment: frontend regression tests only. No Supabase SQL privileges or server code were available, so the migration has not been executed or tested against the live schema. Keep this PR in draft until steps 2–4 are complete.

Remaining audit work: replace name-based member relationships with user IDs; audit RLS and privileged edge functions; enforce the annual booking limit server-side; schedule reminders on the server; review existing duplicate names and their historical data. This migration is not a replacement for that work.
