-- Prevent a physical device from creating a new installation identity when
-- another identity already exists for the same product and fingerprint.
--
-- Existing duplicates are deliberately left untouched. Both existing IDs keep
-- working until they are reviewed manually; only a third/new ID is rejected.
-- The shared advisory lock closes the race between recipe/status validation and
-- activation-request registration.

BEGIN;

DO $migration$
DECLARE
  v_definition text;
  v_old text := $old$
  PERFORM pg_advisory_xact_lock(hashtextextended(v_installation_id, 1));

  INSERT INTO installations ($old$;
  v_new text := $new$
  PERFORM pg_advisory_xact_lock(
    hashtextextended(
      v_product || ':' || (p_request_body ->> 'device_fingerprint_hash'),
      5
    )
  );
  PERFORM pg_advisory_xact_lock(hashtextextended(v_installation_id, 1));

  IF NOT EXISTS (
    SELECT 1
    FROM installations
    WHERE installations.installation_id = v_installation_id
  ) AND EXISTS (
    SELECT 1
    FROM installations
    WHERE installations.product = v_product
      AND installations.device_fingerprint_hash =
        p_request_body ->> 'device_fingerprint_hash'
  ) THEN
    v_allowed := false;
    v_status := 'blocked';
    v_reason := 'installation_blocked';
    v_response := jsonb_build_object(
      'http', 403,
      'decision', 'deny',
      'access_status', v_status,
      'reason_code', v_reason,
      'recipe_action', 'delete',
      'installation_id', v_installation_id
    );

    INSERT INTO access_events (
      request_id,
      installation_id,
      product,
      license_id,
      request_sha256,
      request_body,
      allowed,
      access_status,
      reason_code,
      response_body,
      occurred_at
    ) VALUES (
      v_request_id,
      NULL,
      NULL,
      NULL,
      p_request_sha256,
      p_request_body,
      false,
      v_status,
      v_reason,
      v_response,
      v_now
    );

    RETURN v_response;
  END IF;

  INSERT INTO installations ($new$;
BEGIN
  SELECT pg_get_functiondef(p.oid)
  INTO v_definition
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'licensing'
    AND p.proname = 'resolve_recipe_access'
    AND pg_get_function_identity_arguments(p.oid) =
      'p_request_body jsonb, p_request_sha256 text';

  IF v_definition IS NULL THEN
    RAISE EXCEPTION 'licensing.resolve_recipe_access was not found';
  END IF;

  IF strpos(v_definition, v_new) > 0 THEN
    RAISE NOTICE 'resolve_recipe_access is already protected';
  ELSIF strpos(v_definition, v_old) = 0 THEN
    RAISE EXCEPTION 'resolve_recipe_access no longer matches the expected source';
  ELSE
    EXECUTE replace(v_definition, v_old, v_new);
  END IF;
END
$migration$;

DO $migration$
DECLARE
  v_definition text;
  v_old text := $old$
  PERFORM pg_advisory_xact_lock(hashtextextended(v_installation_id, 3));

  INSERT INTO installations ($old$;
  v_new text := $new$
  PERFORM pg_advisory_xact_lock(
    hashtextextended(
      v_product || ':' || (p_request_body ->> 'device_fingerprint_hash'),
      5
    )
  );
  PERFORM pg_advisory_xact_lock(hashtextextended(v_installation_id, 3));

  IF NOT EXISTS (
    SELECT 1
    FROM installations
    WHERE installations.installation_id = v_installation_id
  ) AND EXISTS (
    SELECT 1
    FROM installations
    WHERE installations.product = v_product
      AND installations.device_fingerprint_hash =
        p_request_body ->> 'device_fingerprint_hash'
  ) THEN
    RETURN jsonb_build_object(
      'http', 409,
      'status', 'installation_mismatch',
      'message', 'Este equipo ya está registrado con otra identidad de instalación.'
    );
  END IF;

  INSERT INTO installations ($new$;
BEGIN
  SELECT pg_get_functiondef(p.oid)
  INTO v_definition
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'licensing'
    AND p.proname = 'submit_activation_request'
    AND pg_get_function_identity_arguments(p.oid) =
      'p_request_body jsonb, p_request_sha256 text';

  IF v_definition IS NULL THEN
    RAISE EXCEPTION 'licensing.submit_activation_request was not found';
  END IF;

  IF strpos(v_definition, v_new) > 0 THEN
    RAISE NOTICE 'submit_activation_request is already protected';
  ELSIF strpos(v_definition, v_old) = 0 THEN
    RAISE EXCEPTION 'submit_activation_request no longer matches the expected source';
  ELSE
    EXECUTE replace(v_definition, v_old, v_new);
  END IF;
END
$migration$;

DO $verification$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'licensing'
      AND p.proname IN (
        'resolve_recipe_access',
        'submit_activation_request'
      )
      AND strpos(
        pg_get_functiondef(p.oid),
        'v_product || '':'' || (p_request_body ->> ''device_fingerprint_hash'')'
      ) = 0
  ) THEN
    RAISE EXCEPTION 'duplicate installation guard verification failed';
  END IF;
END
$verification$;

SELECT
  p.proname,
  strpos(
    pg_get_functiondef(p.oid),
    'v_product || '':'' || (p_request_body ->> ''device_fingerprint_hash'')'
  ) > 0 AS duplicate_guard_installed
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'licensing'
  AND p.proname IN (
    'resolve_recipe_access',
    'submit_activation_request'
  )
ORDER BY p.proname;

COMMIT;
