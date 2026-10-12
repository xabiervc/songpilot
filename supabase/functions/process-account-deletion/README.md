# Process account deletion

This Edge Function is authenticated and derives the target identity from the verified Supabase JWT. It accepts no user ID in the request body. The service-role key is read only from Edge Function secrets and must never be supplied to Flutter or committed to Git.

## Deploy and configure

1. Apply migrations to a staging Supabase project first, including the account-deletion and community-safety migrations.
2. Set server secrets using the Supabase CLI or Dashboard secret manager. Required variables are `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`. Never paste values into this repository or client build arguments.
3. Deploy `process-account-deletion` with JWT verification enabled.
4. The signed-in client can invoke the function with POST and no user ID body after its request has status `pending`.
5. Test with a disposable account and verify cascades for profiles, songs, sections, collaboration requests and deletion request. Verify retries and unauthorized calls.

## Important limitations before production

- Inventory all Storage buckets and object naming conventions. The current schema has no bucket definitions in migrations; do not enable production deletion until object cleanup is implemented and tested for every actual bucket.
- This function deletes the Auth user only after cleaning explicit safety rows; FK cascades remove schema-linked rows. Confirm cascade behavior in staging.
- If deletion partially fails, the function returns 500 and attempts to reset the request to pending. Inspect the staging database and retry safely.
- Define a processing SLA, user notification flow and lawful retention exceptions before release.
- Use an Edge Function concurrency/locking design if multiple requests could be processed simultaneously; test duplicate invocations before production.

This is a staging implementation; deploy and test it before representing deletion as fully operational to users or reviewers.
