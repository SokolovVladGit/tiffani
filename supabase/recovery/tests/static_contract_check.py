#!/usr/bin/env python3
"""Static checks for supabase/recovery. No database and no network."""

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SQL_FILES = sorted(p for p in ROOT.glob("*.sql"))
TEXT = "\n".join(p.read_text() for p in SQL_FILES)

REQUIRED_SNIPPETS = [
    "CREATE TABLE public.products",
    "CREATE TABLE public.product_variants",
    "CREATE TABLE public.product_images",
    "CREATE TABLE public.order_requests",
    "CREATE TABLE public.order_request_items",
    "product_id                 uuid",
    "variant_id        text             NOT NULL",
    "numeric(12,2)",
    "WHERE p.is_active",
    "user_id_not_allowed",
    "user_id_mismatch",
    "product_is_publicly_visible",
    "CREATE VIEW public.catalog_items",
    "(p.is_active AND p.app_is_visible)   AS is_active",
    "AS legacy_variant_uuid",
    "CREATE OR REPLACE FUNCTION public.is_admin()",
    "CREATE OR REPLACE FUNCTION public.quote_order_v1",
    "CREATE OR REPLACE FUNCTION public.submit_order_v2",
    "CREATE OR REPLACE FUNCTION public.submit_order_v3",
    "CREATE OR REPLACE FUNCTION public.submit_consultation_v1",
    "CREATE OR REPLACE FUNCTION public.admin_set_product_visibility",
    "CREATE OR REPLACE FUNCTION public.admin_upsert_native_product",
    "CREATE OR REPLACE FUNCTION public.generate_admin_variant_id",
    "c.product_id::uuid",
    "CREATE TABLE public.stores",
    "CREATE TABLE public.delivery_rules",
    "CREATE TABLE public.articles",
    "CREATE TABLE public.article_blocks",
    "CREATE TABLE public.discount_campaigns",
    "CREATE TABLE public.catalog_sync_runs",
    "GRANT EXECUTE ON FUNCTION public.submit_order_v3(jsonb, jsonb) TO anon, authenticated, service_role",
    "REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon, authenticated",
    "REVOKE ALL ON TABLE public.catalog_items FROM PUBLIC, anon, authenticated",
    "USING (public.is_admin())",
    "fulfillment_fee_mismatch",
]

FORBIDDEN = [
    "cron.schedule",
    "catalog-sync-every-10min",
    "deactivateMissingProducts",
    "/functions/v1/catalog-sync",
    "pg_cron",
    "pg_net",
    "(p_customer->>'user_id')::UUID",
    "100.0",
]

REQUIRED_FILES = [
    "0001_catalog_base.sql",
    "0002_identity_and_orders.sql",
    "0003_content_and_sync.sql",
    "0004_discounts.sql",
    "0005_catalog_contract.sql",
    "0006_checkout_rpcs.sql",
    "0007_admin_rpcs.sql",
    "0008_security.sql",
    "0009_seed_info_blocks.sql",
]


def main() -> int:
    failures = []
    names = [p.name for p in SQL_FILES]
    if names != REQUIRED_FILES:
        failures.append(f"migration order mismatch: {names}")
    for snippet in REQUIRED_SNIPPETS:
        if snippet not in TEXT:
            failures.append(f"missing snippet: {snippet}")
    lowered = TEXT.lower()
    for token in FORBIDDEN:
        # The validation cast is btrim(p_customer->>'user_id')::uuid.
        # Reject only a client cast that is not wrapped in that check.
        if token == "(p_customer->>'user_id')::UUID":
            if re.search(r"(?<!btrim)\(p_customer->>'user_id'\)::uuid", lowered):
                failures.append(f"forbidden token present: {token}")
            continue
        if token.lower() in lowered:
            failures.append(f"forbidden token present: {token}")
    # Guest checkout must not regain a blanket insert policy.
    if TEXT.count("WHEN 'moldova_post'     THEN 30") != 3:
        failures.append("fulfillment fee CASE is not shared by quote, submit_v3, and submit_v2")
    if "FOR INSERT" in TEXT and "order_requests" in TEXT:
        for line in TEXT.splitlines():
            if "POLICY" in line and "order_requests" in line and "INSERT" in line:
                failures.append(f"unexpected order insert policy: {line.strip()}")
    if failures:
        print("FAIL")
        for item in failures:
            print(f"- {item}")
        return 1
    print(f"PASS static contract ({len(SQL_FILES)} sql files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
