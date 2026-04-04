import { useEffect, useState } from "react";
import { PageHeader } from "../../shared/ui/PageHeader";
import {
  fetchCatalogHealth,
  type CatalogHealth,
} from "../products/api";

export function DashboardPage() {
  const [health, setHealth] = useState<CatalogHealth | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    fetchCatalogHealth()
      .then((h) => {
        if (!cancelled) setHealth(h);
      })
      .catch((err: unknown) => {
        if (!cancelled)
          setError(
            err instanceof Error ? err.message : "Не удалось загрузить данные",
          );
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div>
      <PageHeader title="Обзор" />

      {loading && (
        <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <div
              key={i}
              className="h-24 animate-pulse rounded-lg border border-gray-200 bg-gray-50"
            />
          ))}
        </div>
      )}

      {error && (
        <div className="mt-6 rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {health && !loading && (
        <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <StatCard label="Товары" value={health.productsCount} />
          <StatCard label="Варианты" value={health.variantsCount} />
          <StatCard
            label="В каталоге"
            value={health.catalogItemsCount}
          />
          <StatCard
            label="Без вариантов"
            value={health.orphanProductsCount}
            alert={health.orphanProductsCount > 0}
          />
        </div>
      )}

      {health && !loading && health.orphanProductsCount > 0 && (
        <div className="mt-4 rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {health.orphanProductsCount} товар(ов) без вариантов — они не
          отображаются в мобильном приложении. Откройте каждый товар и добавьте
          хотя бы один вариант.
        </div>
      )}
    </div>
  );
}

function StatCard({
  label,
  value,
  alert,
}: {
  label: string;
  value: number;
  alert?: boolean;
}) {
  return (
    <div
      className={`rounded-lg border px-4 py-4 ${
        alert
          ? "border-red-200 bg-red-50"
          : "border-gray-200 bg-white"
      }`}
    >
      <p className="text-xs font-medium uppercase tracking-wider text-gray-400">
        {label}
      </p>
      <p
        className={`mt-1 text-2xl font-semibold ${
          alert ? "text-red-600" : "text-gray-900"
        }`}
      >
        {value.toLocaleString()}
      </p>
    </div>
  );
}
