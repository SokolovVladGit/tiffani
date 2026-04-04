/**
 * Product create/edit page.
 *
 * Product-level writes target `products`.
 * Variant CRUD targets `product_variants` (variant_id is DB-generated).
 * Image management targets `product_images` (URL-based, no storage upload).
 */

import { type ReactNode, useState } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { useProductDetail } from "./useProductDetail";
import { useProductForm, ALLOWED_MARKS, PRODUCT_CATEGORIES } from "./useProductForm";
import type { MarkValue } from "./useProductForm";
import { VariantManager } from "./VariantManager";
import { ImageManager } from "./ImageManager";
import type { Product, ProductVariant } from "../../lib/types/database";


export function ProductEditorPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isNew = !id;

  const detail = useProductDetail(isNew ? undefined : id);
  const primaryVariant = (!isNew && detail.variants.length > 0)
    ? detail.variants[0]!
    : null;
  const {
    form,
    dirty,
    saving,
    saveError,
    fieldErrors,
    justSaved,
    updateField,
    save,
  } = useProductForm(
    isNew ? null : detail.product,
    primaryVariant,
  );

  if (!isNew && detail.loading) {
    return (
      <div className="max-w-4xl">
        <div className="h-4 w-24 animate-pulse rounded bg-gray-100" />
        <div className="mt-4 h-6 w-64 animate-pulse rounded bg-gray-100" />
        <div className="mt-8 space-y-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="h-24 animate-pulse rounded-md bg-gray-100" />
          ))}
        </div>
      </div>
    );
  }

  if (!isNew && detail.notFound) {
    return (
      <div className="py-16 text-center">
        <Link to="/products" className="text-sm text-gray-500 hover:text-gray-700">
          ← Назад к товарам
        </Link>
        <p className="mt-8 text-sm text-gray-400">Товар не найден</p>
      </div>
    );
  }

  if (!isNew && detail.error) {
    return (
      <div className="max-w-4xl py-8">
        <Link to="/products" className="text-sm text-gray-500 hover:text-gray-700">
          ← Назад к товарам
        </Link>
        <div className="mt-6 rounded-md border border-red-200 bg-red-50 px-4 py-3">
          <p className="text-sm text-red-700">{detail.error}</p>
          <button
            onClick={detail.retry}
            className="mt-2 text-sm font-medium text-red-600 hover:text-red-500"
          >
            Попробовать снова
          </button>
        </div>
      </div>
    );
  }

  const warnings = !isNew && detail.product
    ? computeWarnings(detail.product, detail.variants)
    : [];

  async function handleSave() {
    const result = await save();
    if (result && isNew) {
      navigate(`/products/${result.id}`, { replace: true });
    }
  }

  const markLabels: Record<string, string> = {
    "": "— Нет —",
    NEW: "NEW",
    ХИТ: "ХИТ",
    SALE: "SALE",
  };

  return (
    <div className="max-w-4xl space-y-6 pb-12">
      {/* Header */}
      <div>
        <Link to="/products" className="text-sm text-gray-500 hover:text-gray-700">
          ← Товары
        </Link>

        <div className="mt-3 flex items-center justify-between">
          <h1 className="text-lg font-semibold text-gray-900">
            {isNew ? "Новый товар" : form.title || "Без названия"}
          </h1>

          <div className="flex items-center gap-3">
            {saveError && (
              <span className="text-sm text-red-600">{saveError}</span>
            )}
            <button
              onClick={handleSave}
              disabled={saving || (!isNew && !dirty)}
              className={`btn-primary ${
                justSaved ? "!bg-emerald-600 hover:!bg-emerald-600" : ""
              }`}
            >
              {saving
                ? "Сохранение…"
                : justSaved
                  ? "Сохранено"
                  : isNew
                    ? "Создать товар"
                    : "Сохранить"}
            </button>
          </div>
        </div>
      </div>

      {/* Contract warnings */}
      {warnings.length > 0 && (
        <div className="space-y-2">
          {warnings.map((w, i) => (
            <div
              key={i}
              className={`rounded-md px-4 py-2.5 text-sm ${
                w.severity === "error"
                  ? "border border-red-200 bg-red-50 text-red-700"
                  : "border border-amber-200 bg-amber-50 text-amber-700"
              }`}
            >
              {w.message}
            </div>
          ))}
        </div>
      )}

      {/* Основная информация */}
      <FormSection title="Основная информация">
        <FormField label="Название" required error={fieldErrors.title}>
          <input
            className={`input ${fieldErrors.title ? "!border-red-300 !ring-red-100" : ""}`}
            value={form.title}
            onChange={(e) => updateField("title", e.target.value)}
            placeholder="Название товара"
          />
        </FormField>

        <div className="grid gap-4 sm:grid-cols-2">
          <FormField label="Бренд">
            <input
              className="input"
              value={form.brand}
              onChange={(e) => updateField("brand", e.target.value)}
              placeholder="Например: COSRX"
            />
          </FormField>
          <FormField label="Категория">
            <select
              className="input"
              value={form.category}
              onChange={(e) => updateField("category", e.target.value)}
            >
              <option value="">— Не выбрана —</option>
              {PRODUCT_CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
              {form.category &&
                !(PRODUCT_CATEGORIES as readonly string[]).includes(
                  form.category,
                ) && (
                  <option value={form.category}>
                    {form.category} (из каталога)
                  </option>
                )}
            </select>
          </FormField>
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <FormField label="Метка" hint="Значок на карточке товара в приложении" error={fieldErrors.mark}>
            <select
              className={`input ${fieldErrors.mark ? "!border-red-300 !ring-red-100" : ""}`}
              value={form.mark}
              onChange={(e) =>
                updateField("mark", e.target.value as MarkValue)
              }
            >
              {ALLOWED_MARKS.map((m) => (
                <option key={m} value={m}>
                  {markLabels[m] ?? m}
                </option>
              ))}
            </select>
          </FormField>
          <div className="flex flex-col justify-end gap-1 pb-1">
            <label className="flex items-center gap-2.5 text-sm text-gray-700">
              <input
                type="checkbox"
                checked={form.is_active}
                onChange={(e) => updateField("is_active", e.target.checked)}
                className="h-4 w-4 rounded border-gray-300"
              />
              Показывать в приложении
            </label>
            <p className="text-xs text-gray-400">
              {form.is_active
                ? "Товар виден покупателям в приложении."
                : "Товар скрыт из приложения. Данные сохранены."}
            </p>
          </div>
        </div>
      </FormSection>

      {/* Цена и наличие */}
      <FormSection title="Цена и наличие">
        <div className="grid gap-4 sm:grid-cols-3">
          <FormField
            label="Цена"
            hint="Текущая цена в приложении"
            error={fieldErrors.variant_price}
          >
            <input
              className={`input ${fieldErrors.variant_price ? "!border-red-300 !ring-red-100" : ""}`}
              inputMode="decimal"
              value={form.variant_price}
              onChange={(e) => updateField("variant_price", e.target.value)}
              placeholder="0"
            />
          </FormField>
          <FormField label="Старая цена" hint="Зачёркнутая цена (необязательно)">
            <input
              className="input"
              inputMode="decimal"
              value={form.variant_old_price}
              onChange={(e) => updateField("variant_old_price", e.target.value)}
              placeholder="—"
            />
          </FormField>
          <FormField label="Количество" hint="Остаток на складе">
            <input
              className="input"
              inputMode="numeric"
              value={form.variant_quantity}
              onChange={(e) => updateField("variant_quantity", e.target.value)}
              placeholder="0"
            />
          </FormField>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <FormField
            label="Объём / вариант"
            hint="Показывается как отдельный чип на странице товара"
          >
            <input
              className="input"
              value={form.variant_editions}
              onChange={(e) => updateField("variant_editions", e.target.value)}
              placeholder="Например: 30 мл, 50 мл, 1 шт"
            />
          </FormField>
          <FormField
            label="Цвет / оттенок"
            hint="Показывается как отдельный чип на странице товара"
          >
            <input
              className="input"
              value={form.variant_modifications}
              onChange={(e) => updateField("variant_modifications", e.target.value)}
              placeholder="Например: Оттенок 13, Розовый, Light Beige"
            />
          </FormField>
        </div>
      </FormSection>

      {/* Описание товара */}
      <FormSection title="Описание товара">
        <FormField
          label="Короткий текст"
          hint="Показывается под названием товара в карточке приложения"
        >
          <textarea
            className="input resize-y"
            rows={3}
            value={form.description}
            onChange={(e) => updateField("description", e.target.value)}
            placeholder="Например: Увлажняющий крем для чувствительной кожи"
          />
        </FormField>
        <FormField
          label="Подробное описание"
          hint="Полный текст на странице товара в приложении. Можно использовать HTML-разметку для форматирования"
        >
          <textarea
            className="input resize-y"
            rows={8}
            value={form.text}
            onChange={(e) => updateField("text", e.target.value)}
            placeholder="Состав, способ применения, особенности…"
          />
        </FormField>
      </FormSection>

      {/* Главное фото */}
      <FormSection title="Главное фото">
        <p className="text-xs text-gray-400">
          Обложка карточки товара в приложении. Если дополнительных фото нет —
          это единственное изображение товара.
        </p>
        <div className="flex items-start gap-4">
          <div className="min-w-0 flex-1">
            <FormField label="Ссылка на фото">
              <div className="flex gap-2">
                <input
                  className="input flex-1"
                  type="url"
                  value={form.photo}
                  onChange={(e) => updateField("photo", e.target.value)}
                  placeholder="https://…"
                />
                {form.photo.trim() && (
                  <button
                    type="button"
                    onClick={() => updateField("photo", "")}
                    className="btn-secondary shrink-0 py-1.5 text-xs"
                    title="Убрать главное фото"
                  >
                    Убрать
                  </button>
                )}
              </div>
            </FormField>
          </div>
          {form.photo.trim() && (
            <img
              src={form.photo.trim()}
              alt="Превью"
              className="h-32 w-32 shrink-0 rounded-md border border-gray-200 object-cover"
              onError={(e) => {
                (e.target as HTMLImageElement).style.display = "none";
              }}
            />
          )}
        </div>
      </FormSection>

      {/* Дополнительные фото */}
      {isNew ? (
        <div>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-gray-400">
            Дополнительные фото
          </h2>
          <div className="rounded-md border border-gray-200 bg-gray-50 px-4 py-6 text-center">
            <p className="text-sm text-gray-500">
              Сначала сохраните товар — после этого здесь можно будет добавить
              дополнительные фото для галереи.
            </p>
          </div>
        </div>
      ) : id ? (
        <ImageManager
          key={`img-${id}`}
          productId={id}
          initialImages={detail.images}
        />
      ) : null}

      {/* Все варианты */}
      {!isNew && id && (
        <CollapsibleSection
          title={`Все варианты (${detail.variants.length})`}
          defaultOpen={detail.variants.length > 1}
          bare
        >
          <p className="mb-3 text-xs text-gray-400">
            Цена и количество основного варианта редактируются в секции
            «Цена и наличие» выше. Здесь можно добавить дополнительные варианты
            или отредактировать расширенные поля.
          </p>
          <VariantManager
            key={id}
            productId={id}
            initialVariants={detail.variants}
          />
        </CollapsibleSection>
      )}

      {/* Служебные поля */}
      <CollapsibleSection
        title="Служебные поля"
        defaultOpen={
          !isNew &&
          !!(form.external_id.trim() || form.tilda_uid.trim())
        }
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <FormField label="Внешний ID" hint="Идентификатор из внешней системы">
            <input
              className="input font-mono text-xs"
              value={form.external_id}
              onChange={(e) => updateField("external_id", e.target.value)}
            />
          </FormField>
          <FormField label="Tilda UID" hint="Идентификатор из Tilda">
            <input
              className="input font-mono text-xs"
              value={form.tilda_uid}
              onChange={(e) => updateField("tilda_uid", e.target.value)}
            />
          </FormField>
        </div>
        {!isNew && detail.product && (
          <div className="grid gap-4 border-t border-gray-100 pt-4 sm:grid-cols-2">
            <ReadOnlyField label="ID товара" value={detail.product.id} mono />
            <ReadOnlyField
              label="Создан"
              value={
                detail.product.created_at
                  ? formatDate(detail.product.created_at)
                  : "—"
              }
            />
          </div>
        )}
      </CollapsibleSection>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Contract warnings
// ---------------------------------------------------------------------------

interface ContractWarning {
  severity: "error" | "warning";
  message: string;
}

function computeWarnings(
  product: Product,
  variants: ProductVariant[],
): ContractWarning[] {
  const out: ContractWarning[] = [];

  const nullVids = variants.filter((v) => !v.variant_id);
  if (nullVids.length > 0) {
    out.push({
      severity: "error",
      message: `У ${nullVids.length} варианта(ов) отсутствует variant_id — приложение не сможет их отобразить`,
    });
  }

  if (!product.photo) {
    out.push({
      severity: "warning",
      message: "Нет главного фото — в приложении будет показана заглушка",
    });
  }

  if (variants.length === 0) {
    out.push({
      severity: "error",
      message:
        "Нет вариантов — товар не отображается в приложении. Добавьте хотя бы один вариант.",
    });
  }

  return out;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString("ru-RU", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

// ---------------------------------------------------------------------------
// Form components
// ---------------------------------------------------------------------------

function FormSection({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <div>
      <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-gray-400">
        {title}
      </h2>
      <div className="space-y-4 rounded-md border border-gray-200 bg-white p-4">
        {children}
      </div>
    </div>
  );
}

function FormField({
  label,
  required,
  hint,
  error,
  children,
}: {
  label: string;
  required?: boolean;
  hint?: string;
  error?: string;
  children: ReactNode;
}) {
  return (
    <div>
      <label className="mb-1 block text-sm font-medium text-gray-700">
        {label}
        {required && <span className="ml-0.5 text-red-400">*</span>}
      </label>
      {children}
      {error && <p className="mt-1 text-xs text-red-500">{error}</p>}
      {hint && !error && (
        <p className="mt-1 text-xs text-gray-400">{hint}</p>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Collapsible section for secondary fields
// ---------------------------------------------------------------------------

function CollapsibleSection({
  title,
  defaultOpen = false,
  bare = false,
  children,
}: {
  title: string;
  defaultOpen?: boolean;
  /** When true, renders children without the card wrapper. */
  bare?: boolean;
  children: ReactNode;
}) {
  const [open, setOpen] = useState(defaultOpen);

  return (
    <div>
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="mb-2 flex items-center gap-1.5 text-xs font-medium uppercase tracking-wider text-gray-400 hover:text-gray-600"
      >
        <span
          className={`inline-block transition-transform ${open ? "rotate-90" : ""}`}
        >
          ▸
        </span>
        {title}
      </button>
      {open &&
        (bare ? (
          children
        ) : (
          <div className="space-y-4 rounded-md border border-gray-200 bg-white p-4">
            {children}
          </div>
        ))}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Read-only components (metadata)
// ---------------------------------------------------------------------------

function ReadOnlyField({
  label,
  value,
  mono,
}: {
  label: string;
  value: string | number | null | undefined;
  mono?: boolean;
}) {
  const empty = value == null || value === "";
  return (
    <div>
      <p className="text-xs text-gray-400">{label}</p>
      <p
        className={`mt-0.5 text-sm ${empty ? "text-gray-300" : "text-gray-700"} ${
          mono ? "font-mono text-xs" : ""
        }`}
      >
        {empty ? "—" : value}
      </p>
    </div>
  );
}
