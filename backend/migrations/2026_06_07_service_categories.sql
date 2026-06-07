-- Adds multi-category service coverage for workshops and incidents.

ALTER TABLE IF EXISTS workshops
    ADD COLUMN IF NOT EXISTS categories TEXT[] NOT NULL DEFAULT '{}'::text[];

ALTER TABLE IF EXISTS incidents
    ADD COLUMN IF NOT EXISTS categories TEXT[] NOT NULL DEFAULT '{}'::text[];