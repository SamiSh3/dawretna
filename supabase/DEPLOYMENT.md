# Atomic swap deployment status

Applied to the chalet-rotation Supabase project on 2026-10-08 as migration `resolve_swap_atomic`.

The actual schema and relevant RLS policies were inspected before application. The RPC uses SECURITY INVOKER, is executable by authenticated users, and is not executable by anon. Existing RLS policies were preserved.

Database integration checks passed under role authenticated and simulated JWT subjects: acceptance updates both hosts and request status; repeated acceptance is rejected; a wrong actor and unauthenticated actor are rejected; expired requests, changed source bookings and cancelled slots are rejected; rejection keeps hosts unchanged. Fixture inserts and updates were inside a transaction that was rolled back. No fixture data was committed. These checks ran on the existing database, not a separate staging branch.

Ten local frontend regression tests passed. Concurrent-session stress testing and an injected failure on the second slot update have not been performed. The implementation locks requests and both slots in a stable order and relies on PostgreSQL transaction rollback for atomicity.

PR #3 was merged into the `fix/audit-app-reliability` branch, not directly into main. PR #2 now includes its changes. The database dependency is installed; merge PR #2 to main to deploy the frontend, after checking the current branch state.

Remaining security work: current slots and swap_requests RLS policies permit broad writes by authenticated users, and profiles allow own-row updates. This migration does not tighten those policies. Review role/field restrictions and direct API access separately. Replace name-based relationships with user IDs, enforce annual booking limits server-side, and schedule reminders on the server.
