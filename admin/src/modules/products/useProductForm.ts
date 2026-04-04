import { useCallback, useEffect, useRef, useState } from "react";
import {
  createProduct,
  updateProduct,
  updateVariant,
} from "./api";
import type { CreateVariantOverrides } from "./api";
import type {
  Product,
  ProductInsert,
  ProductVariant,
} from "../../lib/types/database";

/** Exact values the Flutter app recognises for product badges. */
export const ALLOWED_MARKS = ["", "NEW", "ХИТ", "SALE"] as const;
export type MarkValue = (typeof ALLOWED_MARKS)[number];

/**
 * Top-level product categories used across the catalog.
 * Compound Tilda values (`;` and `>>>`) are normalised to these primaries.
 */
export const PRODUCT_CATEGORIES = [
  "Лицо",
  "Тело",
  "Волосы",
  "Макияж",
  "Аксессуары",
  "Для дома и авто",
  "Товары для маникюра",
  "Наборы",
  "Victoria's Secret",
  "Sister's Aroma",
] as const;

export interface ProductFormData {
  title: string;
  brand: string;
  category: string;
  description: string;
  text: string;
  photo: string;
  is_active: boolean;
  mark: MarkValue;
  external_id: string;
  tilda_uid: string;
  variant_price: string;
  variant_old_price: string;
  variant_quantity: string;
  variant_editions: string;
  variant_modifications: string;
}

export interface ProductFieldErrors {
  title?: string;
  mark?: string;
  variant_price?: string;
}

const EMPTY_FORM: ProductFormData = {
  title: "",
  brand: "",
  category: "",
  description: "",
  text: "",
  photo: "",
  is_active: false,
  mark: "",
  external_id: "",
  tilda_uid: "",
  variant_price: "",
  variant_old_price: "",
  variant_quantity: "",
  variant_editions: "",
  variant_modifications: "",
};

const VARIANT_FIELDS: ReadonlySet<string> = new Set([
  "variant_price",
  "variant_old_price",
  "variant_quantity",
  "variant_editions",
  "variant_modifications",
]);

function coerceMark(raw: string | null | undefined): MarkValue {
  const v = (raw ?? "").trim();
  return (ALLOWED_MARKS as readonly string[]).includes(v)
    ? (v as MarkValue)
    : "";
}

function productToForm(
  p: Product,
  pv: ProductVariant | null,
): ProductFormData {
  return {
    title: p.title ?? "",
    brand: p.brand ?? "",
    category: p.category ?? "",
    description: p.description ?? "",
    text: p.text ?? "",
    photo: p.photo ?? "",
    is_active: p.is_active,
    mark: coerceMark(p.mark),
    external_id: p.external_id ?? "",
    tilda_uid: p.tilda_uid ?? "",
    variant_price: pv?.price != null ? String(pv.price) : "",
    variant_old_price: pv?.old_price != null ? String(pv.old_price) : "",
    variant_quantity: pv?.quantity != null ? String(pv.quantity) : "",
    variant_editions: pv?.editions ?? "",
    variant_modifications: pv?.modifications ?? "",
  };
}

function formToPayload(f: ProductFormData): ProductInsert {
  return {
    title: f.title.trim(),
    brand: f.brand.trim() || null,
    category: f.category.trim() || null,
    description: f.description.trim() || null,
    text: f.text.trim() || null,
    photo: f.photo.trim() || null,
    is_active: f.is_active,
    mark: f.mark.trim() || null,
    external_id: f.external_id.trim() || null,
    tilda_uid: f.tilda_uid.trim() || null,
  };
}

function parseNum(s: string): number | null {
  const t = s.trim();
  if (!t) return null;
  const n = Number(t);
  return isNaN(n) ? null : n;
}

function variantOverridesFromForm(f: ProductFormData): CreateVariantOverrides {
  return {
    price: parseNum(f.variant_price) ?? 0,
    old_price: parseNum(f.variant_old_price),
    quantity: parseNum(f.variant_quantity) ?? 0,
    editions: f.variant_editions.trim() || null,
    modifications: f.variant_modifications.trim() || null,
  };
}

function validateProduct(f: ProductFormData): ProductFieldErrors {
  const errors: ProductFieldErrors = {};
  if (!f.title.trim()) errors.title = "Название обязательно";
  if (
    f.mark !== "" &&
    !(ALLOWED_MARKS as readonly string[]).includes(f.mark)
  ) {
    errors.mark = `Метка должна быть одной из: ${ALLOWED_MARKS.filter(Boolean).join(", ")}`;
  }
  const priceStr = f.variant_price.trim();
  if (priceStr) {
    const n = Number(priceStr);
    if (isNaN(n)) {
      errors.variant_price = "Цена должна быть числом";
    } else if (n < 0) {
      errors.variant_price = "Цена не может быть отрицательной";
    }
  }
  return errors;
}

/**
 * Manages form state for product create/update.
 *
 * Writes are scoped to `products` + the primary (first) variant.
 * Pass `null` for both in create mode.
 */
export function useProductForm(
  product: Product | null,
  primaryVariant: ProductVariant | null,
) {
  const [form, setForm] = useState<ProductFormData>(
    product ? productToForm(product, primaryVariant) : EMPTY_FORM,
  );
  const [dirty, setDirty] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<ProductFieldErrors>({});
  const [justSaved, setJustSaved] = useState(false);
  const [variantDirty, setVariantDirty] = useState(false);

  const loadedIdRef = useRef<string | undefined>();

  useEffect(() => {
    if (product && product.id !== loadedIdRef.current) {
      loadedIdRef.current = product.id;
      setForm(productToForm(product, primaryVariant));
      setDirty(false);
      setVariantDirty(false);
      setSaveError(null);
      setFieldErrors({});
      setJustSaved(false);
    }
  }, [product, primaryVariant]);

  const updateField = useCallback(
    <K extends keyof ProductFormData>(field: K, value: ProductFormData[K]) => {
      setForm((f) => ({ ...f, [field]: value }));
      setDirty(true);
      setJustSaved(false);
      setSaveError(null);
      if (VARIANT_FIELDS.has(field as string)) {
        setVariantDirty(true);
      }
      setFieldErrors((prev) => {
        if (field in prev) {
          const next = { ...prev };
          delete next[field as keyof ProductFieldErrors];
          return next;
        }
        return prev;
      });
    },
    [],
  );

  const save = useCallback(async (): Promise<Product | null> => {
    const errors = validateProduct(form);
    if (Object.keys(errors).length > 0) {
      setFieldErrors(errors);
      return null;
    }

    setSaving(true);
    setSaveError(null);
    setFieldErrors({});

    try {
      const payload = formToPayload(form);

      let result: Product;
      if (product) {
        result = await updateProduct(product.id, payload);

        if (primaryVariant && variantDirty) {
          await updateVariant(primaryVariant.id, {
            price: parseNum(form.variant_price) ?? 0,
            old_price: parseNum(form.variant_old_price),
            quantity: parseNum(form.variant_quantity) ?? 0,
            editions: form.variant_editions.trim() || null,
            modifications: form.variant_modifications.trim() || null,
          });
        }
      } else {
        result = await createProduct(
          payload,
          variantOverridesFromForm(form),
        );
      }

      setDirty(false);
      setVariantDirty(false);
      setJustSaved(true);
      setTimeout(() => setJustSaved(false), 2500);
      return result;
    } catch (err: unknown) {
      const msg =
        err instanceof Error ? err.message : "Не удалось сохранить товар";
      setSaveError(msg);
      return null;
    } finally {
      setSaving(false);
    }
  }, [form, product, primaryVariant, variantDirty]);

  useEffect(() => {
    if (!dirty) return;
    const handler = (e: BeforeUnloadEvent) => {
      e.preventDefault();
    };
    window.addEventListener("beforeunload", handler);
    return () => window.removeEventListener("beforeunload", handler);
  }, [dirty]);

  return {
    form,
    dirty,
    saving,
    saveError,
    fieldErrors,
    justSaved,
    updateField,
    save,
  };
}
