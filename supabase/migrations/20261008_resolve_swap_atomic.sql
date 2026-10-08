-- Apply in Supabase SQL Editor BEFORE deploying the corresponding frontend.
-- SECURITY INVOKER preserves the existing RLS policies; this does not replace an RLS audit.
BEGIN;
CREATE OR REPLACE FUNCTION public.resolve_swap_atomic(p_swap_id text, p_accept boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  req public.swap_requests%ROWTYPE;
  source_slot public.slots%ROWTYPE;
  target_slot public.slots%ROWTYPE;
  actor_name text;
  riyadh_today date := (now() AT TIME ZONE 'Asia/Riyadh')::date;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  SELECT name INTO actor_name FROM public.profiles WHERE id = auth.uid();
  IF actor_name IS NULL THEN RAISE EXCEPTION 'Profile required'; END IF;
  -- Legacy tables use names. Fail closed when the actor/requester name is ambiguous.
  IF (SELECT count(*) FROM public.profiles WHERE name = actor_name) <> 1 THEN
    RAISE EXCEPTION 'Duplicate member name; contact administrator';
  END IF;
  SELECT * INTO req FROM public.swap_requests WHERE id::text = p_swap_id FOR UPDATE;
  IF NOT FOUND OR req.status IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'Request is no longer pending';
  END IF;
  IF req.from_slot_id = req.to_slot_id THEN RAISE EXCEPTION 'Invalid swap'; END IF;
  IF req.created_at IS NULL OR req.created_at <= now() - interval '24 hours' THEN
    RAISE EXCEPTION 'Request expired';
  END IF;
  -- Stable lock order prevents two overlapping swaps from deadlocking.
  PERFORM id FROM public.slots
    WHERE id IN (req.from_slot_id, req.to_slot_id) ORDER BY id FOR UPDATE;
  SELECT * INTO source_slot FROM public.slots WHERE id = req.from_slot_id;
  SELECT * INTO target_slot FROM public.slots WHERE id = req.to_slot_id;
  IF source_slot.id IS NULL OR target_slot.id IS NULL THEN RAISE EXCEPTION 'Slot missing'; END IF;
  IF target_slot.host_name IS DISTINCT FROM actor_name THEN RAISE EXCEPTION 'Not the target host'; END IF;
  IF source_slot.host_name IS DISTINCT FROM req.requester_name THEN RAISE EXCEPTION 'Source booking changed'; END IF;
  IF (SELECT count(*) FROM public.profiles WHERE name = req.requester_name) <> 1 THEN
    RAISE EXCEPTION 'Duplicate requester name; contact administrator';
  END IF;
  IF source_slot.host_name = target_slot.host_name THEN RAISE EXCEPTION 'Invalid hosts'; END IF;
  IF p_accept IS NULL THEN RAISE EXCEPTION 'Decision required'; END IF;
  IF p_accept THEN
    IF source_slot.date::date < riyadh_today OR target_slot.date::date < riyadh_today
      OR source_slot.is_cancelled IS TRUE OR target_slot.is_cancelled IS TRUE THEN
      RAISE EXCEPTION 'Slot is past or cancelled';
    END IF;
    UPDATE public.slots SET host_name = target_slot.host_name WHERE id = source_slot.id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Source update denied'; END IF;
    UPDATE public.slots SET host_name = source_slot.host_name WHERE id = target_slot.id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Target update denied'; END IF;
    UPDATE public.swap_requests SET status = 'accepted' WHERE id = req.id AND status = 'pending';
  ELSE
    UPDATE public.swap_requests SET status = 'rejected' WHERE id = req.id AND status = 'pending';
  END IF;
  IF NOT FOUND THEN RAISE EXCEPTION 'Request update denied'; END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;
REVOKE ALL ON FUNCTION public.resolve_swap_atomic(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_swap_atomic(text, boolean) TO authenticated;
COMMIT;
