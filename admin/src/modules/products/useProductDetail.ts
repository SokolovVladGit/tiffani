import { useCallback, useEffect, useState } from "react";
import {
  fetchProduct,
  fetchProductVariants,
  fetchProductImages,
} from "./api";
import type {
  Product,
  ProductVariant,
  ProductImage,
} from "../../lib/types/database";

export function useProductDetail(id: string | undefined) {
  const [product, setProduct] = useState<Product | null>(null);
  const [variants, setVariants] = useState<ProductVariant[]>([]);
  const [images, setImages] = useState<ProductImage[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notFound, setNotFound] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    if (!id) {
      setLoading(false);
      setNotFound(true);
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError(null);
    setNotFound(false);

    (async () => {
      try {
        const p = await fetchProduct(id);
        if (cancelled) return;
        setProduct(p);

        const [v, img] = await Promise.all([
          fetchProductVariants(p.id),
          fetchProductImages(p.id),
        ]);

        if (!cancelled) {
          setVariants(v);
          setImages(img);
          setLoading(false);
        }
      } catch (err: unknown) {
        if (cancelled) return;
        const code = (err as { code?: string })?.code;
        if (code === "PGRST116") {
          setNotFound(true);
          setLoading(false);
        } else {
          const msg =
            err instanceof Error ? err.message : "Failed to load product";
          setError(msg);
          setLoading(false);
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [id, refreshKey]);

  const retry = useCallback(() => {
    setRefreshKey((k) => k + 1);
  }, []);

  return { product, variants, images, loading, error, notFound, retry };
}
