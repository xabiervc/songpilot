import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = request.headers.get("Authorization");
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !authorization) {
    return json({ error: "Server configuration or authorization missing" }, 500);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) return json({ error: "Unauthorized" }, 401);

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const { data: requestRow, error: requestError } = await admin
      .from("account_deletion_requests")
      .select("id,status")
      .eq("user_id", user.id)
      .maybeSingle();
    if (requestError) throw requestError;
    if (!requestRow) return json({ error: "No deletion request found" }, 404);
    if (requestRow.status === "completed") return json({ status: "completed" }, 200);
    if (requestRow.status !== "pending" && requestRow.status !== "processing") {
      return json({ error: "Deletion request is not processable" }, 409);
    }

    const { error: markError } = await admin
      .from("account_deletion_requests")
      .update({ status: "processing" })
      .eq("id", requestRow.id);
    if (markError) throw markError;

    // Existing schema has cascading FKs from auth.users for owned rows. Delete
    // explicit safety records before deleting auth user; storage buckets still
    // need an inventory-specific cleanup policy before production enablement.
    const { error: blocksError } = await admin.from("user_blocks")
      .delete().or(`blocker_id.eq.${user.id},blocked_id.eq.${user.id}`);
    if (blocksError) throw blocksError;
    const { error: reportsError } = await admin.from("content_reports")
      .delete().eq("reporter_id", user.id);
    if (reportsError) throw reportsError;

    const { error: deleteUserError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteUserError) throw deleteUserError;
    // Account request row cascades with auth.users. Do not attempt to update it
    // after auth deletion; successful identity deletion is the completion point.
    return json({ status: "completed" }, 200);
  } catch (error) {
    console.error("account deletion processing failed", error instanceof Error ? error.message : "unknown error");
    await admin.from("account_deletion_requests")
      .update({ status: "pending" })
      .eq("user_id", user.id)
      .eq("status", "processing");
    return json({ error: "Deletion could not be completed; retry later" }, 500);
  }
});

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
