-- IMAGE LINK GENERATOR PRO
-- Migration: server-side history insert + database-level duplicate protection

-- 1) Make sure the hash column exists.
ALTER TABLE public.image_upload_history
ADD COLUMN IF NOT EXISTS file_hash TEXT;

-- 2) Inspect duplicate hashes BEFORE creating the unique index.
-- Run this SELECT first. If it returns rows, keep the newest row and remove/merge
-- older duplicate records manually before continuing to step 3.
SELECT file_hash, COUNT(*) AS duplicate_count
FROM public.image_upload_history
WHERE file_hash IS NOT NULL
GROUP BY file_hash
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- 3) After resolving any duplicate hashes, enforce uniqueness at DB level.
-- Partial unique index allows legacy rows with NULL file_hash.
CREATE UNIQUE INDEX IF NOT EXISTS ux_image_upload_history_file_hash
ON public.image_upload_history(file_hash)
WHERE file_hash IS NOT NULL;

-- 4) The browser no longer inserts history directly.
-- Keep SELECT for cloud history. INSERT can be removed from public roles.
REVOKE INSERT ON TABLE public.image_upload_history FROM anon, authenticated;

-- 5) Admin delete policy remains protected by the admin checker.
ALTER TABLE public.image_upload_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow delete image history" ON public.image_upload_history;
DROP POLICY IF EXISTS "Only admins can delete image history" ON public.image_upload_history;

CREATE POLICY "Only admins can delete image history"
ON public.image_upload_history
FOR DELETE
TO authenticated
USING (public.is_image_history_admin());

GRANT SELECT ON TABLE public.image_upload_history TO anon, authenticated;
GRANT DELETE ON TABLE public.image_upload_history TO authenticated;

-- 6) Realtime for live history refresh.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'image_upload_history'
  ) then
    alter publication supabase_realtime add table public.image_upload_history;
  end if;
end $$;
