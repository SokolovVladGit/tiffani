"""Local concurrency proof for submit_order_v4.

Connects only to 127.0.0.1. Refuses any hosted Supabase host.
Requires the throwaway database created for checkout_reliability.sql.
"""

import json
import sys
import threading
import time

import psycopg2

DSN = "host=127.0.0.1 port=55432 dbname=postgres user=postgres"
REQUEST_ID = "cccccccc-cccc-4ccc-8ccc-ccccccccccc1"
CUSTOMER = {
    "name": "Анна",
    "phone": "+37312345678",
    "consent_given": True,
    "fulfillment_type": "pickup",
    "pickup_store_id": "store_central",
    "fulfillment_method_code": "pickup_store",
    "fulfillment_fee": 0,
    "payment_method_code": "cash",
}
ITEMS = [{"variant_id": "TST-V-A1", "quantity": 1}]


def connect():
    if "supabase.co" in DSN or "pooler" in DSN:
        raise SystemExit("refusing non-local database")
    conn = psycopg2.connect(DSN)
    conn.autocommit = False
    return conn


def seed(conn):
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO public.products (id, title, is_active)
            VALUES ('11111111-1111-4111-8111-111111111111', 'TST', true)
            """
        )
        cur.execute(
            """
            INSERT INTO public.product_variants (id, product_id, variant_id, price)
            VALUES (
              'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
              '11111111-1111-4111-8111-111111111111',
              'TST-V-A1',
              100
            )
            """
        )
        cur.execute(
            """
            INSERT INTO public.discount_campaigns (id, kind, name, percent_off, is_active)
            VALUES (
              'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
              'automatic',
              'TST 10',
              10,
              true
            )
            """
        )
        cur.execute(
            """
            INSERT INTO public.discount_campaign_targets (campaign_id, target_type)
            VALUES ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'all')
            """
        )
    conn.commit()


def cleanup(conn):
    with conn.cursor() as cur:
        cur.execute("DELETE FROM private.checkout_submissions")
        cur.execute(
            """
            DELETE FROM public.discount_redemptions
            WHERE campaign_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'
            """
        )
        cur.execute(
            "DELETE FROM public.order_requests WHERE customer_name IN ('Анна', 'Boom', 'Historical', 'Bad', 'LockProbe')"
        )
        cur.execute(
            "DELETE FROM public.discount_campaigns WHERE id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'"
        )
        cur.execute(
            "DELETE FROM public.product_variants WHERE variant_id = 'TST-V-A1'"
        )
        cur.execute(
            "DELETE FROM public.products WHERE id = '11111111-1111-4111-8111-111111111111'"
        )
    conn.commit()


def submit(results, index):
    conn = connect()
    try:
        with conn.cursor() as cur:
            cur.execute("SET statement_timeout = '15s'")
            cur.execute(
                "SELECT public.submit_order_v4(%s::jsonb, %s::jsonb, %s::uuid)",
                (json.dumps(CUSTOMER), json.dumps(ITEMS), REQUEST_ID),
            )
            raw = cur.fetchone()[0]
            results[index] = json.loads(raw) if isinstance(raw, str) else raw
        conn.commit()
    finally:
        conn.close()


def main():
    conn = connect()
    try:
        cleanup(conn)
        seed(conn)
        lock = connect()
        threads = []
        try:
            with lock.cursor() as cur:
                cur.execute(
                    "LOCK TABLE public.order_requests IN SHARE ROW EXCLUSIVE MODE"
                )

            results = [None, None]
            threads.extend(
                [
                    threading.Thread(target=submit, args=(results, 0)),
                    threading.Thread(target=submit, args=(results, 1)),
                ]
            )
            for thread in threads:
                thread.start()

            waited = 0.0
            waiting = 0
            while waited < 8:
                observer = psycopg2.connect(DSN)
                observer.autocommit = True
                with observer.cursor() as cur:
                    cur.execute(
                        """
                        SELECT count(*)
                        FROM pg_stat_activity
                        WHERE datname = current_database()
                          AND wait_event_type = 'Lock'
                        """
                    )
                    waiting = cur.fetchone()[0]
                observer.close()
                if waiting >= 2:
                    break
                time.sleep(0.05)
                waited += 0.05
            else:
                raise RuntimeError(f"workers did not overlap; waiting={waiting}")
        finally:
            lock.rollback()
            lock.close()
            for thread in threads:
                thread.join(timeout=20)

        for thread in threads:
            thread.join(timeout=20)
            if thread.is_alive():
                raise RuntimeError("worker did not finish")

        left, right = results
        if left["order_id"] != right["order_id"]:
            raise RuntimeError(f"concurrent calls created two orders: {left} {right}")
        if left["grand_total_amount"] != right["grand_total_amount"]:
            raise RuntimeError("concurrent replay changed the total")
        if round(float(left["grand_total_amount"]), 2) != 90.0:
            raise RuntimeError(f"unexpected total {left['grand_total_amount']}")

        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                  (SELECT count(*) FROM public.order_requests WHERE id = %s::uuid),
                  (SELECT count(*) FROM public.order_request_items WHERE request_id = %s::uuid),
                  (SELECT count(*) FROM private.order_notification_jobs WHERE order_id = %s::uuid),
                  (SELECT count(*) FROM public.discount_redemptions WHERE order_request_id = %s::uuid)
                """,
                (left["order_id"],) * 4,
            )
            orders, items, jobs, redemptions = cur.fetchone()
        if (orders, items, jobs, redemptions) != (1, 1, 1, 1):
            raise RuntimeError(
                f"state orders={orders} items={items} jobs={jobs} redemptions={redemptions}"
            )
        print("checkout_reliability_concurrent_ok")
        print(f"order_id={left['order_id']}")
        print(f"overlapped_lock_waits=2")
    finally:
        cleanup(conn)
        conn.close()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
