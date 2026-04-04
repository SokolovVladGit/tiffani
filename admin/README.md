# TIFFANI Admin

Product management admin panel for the TIFFANI beauty e-commerce platform.

## Stack

- React 18 + TypeScript
- Vite
- Tailwind CSS
- Supabase (auth + data)
- react-router-dom

## Setup

```bash
cd admin
cp .env.example .env   # fill in Supabase credentials
npm install
npm run dev             # http://localhost:3001
```

## Structure

```
src/
├── app/                  # App shell, routing, providers
├── lib/                  # Supabase client, shared types
│   └── types/            # Database type contracts
├── modules/              # Feature modules
│   ├── auth/             # Login / auth gate
│   ├── dashboard/        # Overview page
│   └── products/         # Product list + editor
├── shared/               # Shared UI and layout
│   ├── layout/           # AdminShell, Sidebar
│   └── ui/               # Reusable primitives
└── styles/               # Tailwind entry + component classes
```

## Key contracts

The admin writes to three Supabase tables:

| Table | Purpose |
|---|---|
| `products` | Product-level content (title, brand, category, description, photo, mark) |
| `product_variants` | SKU-level commerce data (price, quantity, editions, modifications) |
| `product_images` | Gallery images with position ordering |

The mobile Flutter app reads from the `catalog_items` VIEW, which joins these tables.

### Critical rules

- `variant_id` on `product_variants` is the mobile app's public identity field. It **must** be non-null.
- `is_active` on `products` controls mobile visibility.
- `mark` values are case-sensitive in mobile queries (e.g. `"NEW"` vs `"new"`).
- The `attributes` JSONB column does not currently exist in the live DB.

## Auth

Admin access requires a Supabase auth user whose UUID exists in the `admin_users` table.
RLS policies on product tables enforce admin-only writes via the `is_admin()` function.

## Status

Foundation scaffold only. Product CRUD implementation pending.
