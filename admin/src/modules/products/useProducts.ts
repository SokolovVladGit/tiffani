import { useCallback, useEffect, useState } from "react";
import {
  fetchProducts,
  fetchDistinctBrands,
  fetchDistinctCategories,
  EMPTY_FILTERS,
  PAGE_SIZE,
  type ProductListFilters,
  type ProductListResult,
} from "./api";

export function useProducts() {
  const [filters, setFiltersState] = useState<ProductListFilters>(EMPTY_FILTERS);
  const [page, setPageState] = useState(0);
  const [result, setResult] = useState<ProductListResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [brands, setBrands] = useState<string[]>([]);
  const [categories, setCategories] = useState<string[]>([]);
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    Promise.all([fetchDistinctBrands(), fetchDistinctCategories()])
      .then(([b, c]) => {
        setBrands(b);
        setCategories(c);
      })
      .catch(() => undefined);
  }, []);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    fetchProducts(filters, page)
      .then((res) => {
        if (!cancelled) {
          setResult(res);
          setLoading(false);
        }
      })
      .catch((err: unknown) => {
        if (!cancelled) {
          const msg =
            err instanceof Error ? err.message : "Failed to load products";
          setError(msg);
          setLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [filters, page, refreshKey]);

  const setFilters = useCallback(
    (update: Partial<ProductListFilters>) => {
      setFiltersState((f) => ({ ...f, ...update }));
      setPageState(0);
    },
    [],
  );

  const setPage = useCallback((p: number) => {
    setPageState(p);
  }, []);

  const retry = useCallback(() => {
    setRefreshKey((k) => k + 1);
  }, []);

  const refresh = useCallback(() => {
    setRefreshKey((k) => k + 1);
  }, []);

  const resetFilters = useCallback(() => {
    setFiltersState(EMPTY_FILTERS);
    setPageState(0);
  }, []);

  const totalPages = result
    ? Math.ceil(result.totalCount / PAGE_SIZE)
    : 0;

  const hasActiveFilters =
    filters.search !== "" ||
    filters.status !== "all" ||
    filters.brand !== "" ||
    filters.category !== "" ||
    filters.mark !== "" ||
    filters.sort !== "newest";

  return {
    rows: result?.rows ?? [],
    totalCount: result?.totalCount ?? 0,
    loading,
    error,
    filters,
    page,
    totalPages,
    brands,
    categories,
    hasActiveFilters,
    setFilters,
    setPage,
    resetFilters,
    refresh,
    retry,
  } as const;
}
