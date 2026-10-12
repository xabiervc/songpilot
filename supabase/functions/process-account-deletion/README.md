# Account deletion processor deployment notes

The app can record a user's deletion request in `account_deletion_requests`. This repository package does not yet deploy an automatic processor. Do not tell users that an account has been deleted until the server-side process completes successfully.

## Security requirements for the future Edge Function

- Require a valid Supabase JWT; derive the target user only from the verified JWT subject. Never accept an arbitrary user ID from request JSON.
- Use `SUPABASE_SERVICE_ROLE_KEY` only in Supabase Edge Function secrets; never in Flutter, browser code, logs or Git.
- Fetch the caller's pending deletion request and process it idempotently.
- Delete user-owned `song_sections` through their `songs` rows, owned `songs`, `profiles`, `collab_requests`, safety records, and any user-owned Storage objects after inventorying buckets and path conventions.
- Delete the Auth user last using the Admin API; record completion only if deletion succeeds. Avoid logging emails, tokens or song contents.
- Apply and test least-privilege RLS; rate-limit requests and document support/retry behavior.

## Deployment outline

1. Apply all migrations to a non-production Supabase project first.
2. Implement and test the Edge Function using a disposable test account and records in every owned table/bucket.
3. Set the service-role secret with the Supabase CLI secrets command in the target project; never put its value in this repository.
4. Deploy the function with JWT verification enabled.
5. Test authorization, retries, partial failure, cascade behavior and Storage cleanup before production rollout.
6. Define a realistic processing SLA and update the privacy policy before enabling the feature for real users.

This README is an implementation specification, not a deployed deletion service.