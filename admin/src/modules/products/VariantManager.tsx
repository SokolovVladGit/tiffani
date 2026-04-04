import { type ReactNode, useState } from "react";
import {
  createVariant as apiCreate,
  updateVariant as apiUpdate,
  deleteVariant as apiDelete,
  fetchProductVariants,
} from "./api";
import type {
  ProductVariant,
  VariantInsert,
  VariantUpdate,
} from "../../lib/types/database";

// ---------------------------------------------------------------------------
// Public component
// ---------------------------------------------------------------------------

interface Props {
  productId: string;
  initialVariants: ProductVariant[];
}

export function VariantManager({ productId, initialVariants }: Props) {
  const [variants, setVariants] = useState<ProductVariant[]>(initialVariants);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [isCreating, setIsCreating] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [sectionError, setSectionError] = useState<string | null>(null);

  async function reload() {
    try {
      setVariants(await fetchProductVariants(productId));
    } catch {
      /* best-effort */
    }
  }

  async function handleSave(
    form: VariantFormData,
    existingId: string | null,
  ): Promise<string | null> {
    setSectionError(null);
    try {
      if (existingId) {
        await apiUpdate(existingId, formToUpdatePayload(form));
      } else {
        await apiCreate(formToInsertPayload(form, productId));
      }
      await reload();
      setEditingId(null);
      setIsCreating(false);
      return null;
    } catch (err: unknown) {
      const msg =
        err instanceof Error ? err.message : "Не удалось сохранить вариант";
      return msg;
    }
  }

  const isLastVariant = variants.length <= 1;

  async function handleDelete(id: string) {
    if (isLastVariant) {
      setSectionError(
        "Нельзя удалить последний вариант. Товар без вариантов не отображается в приложении.",
      );
      return;
    }
    if (!window.confirm("Удалить этот вариант? Это действие нельзя отменить."))
      return;
    setSectionError(null);
    setDeletingId(id);
    try {
      await apiDelete(id, productId);
      await reload();
    } catch (err: unknown) {
      setSectionError(
        err instanceof Error ? err.message : "Не удалось удалить вариант",
      );
    } finally {
      setDeletingId(null);
    }
  }

  function startCreate() {
    setEditingId(null);
    setIsCreating(true);
    setSectionError(null);
  }

  function startEdit(id: string) {
    setIsCreating(false);
    setEditingId(id);
    setSectionError(null);
  }

  function cancelEdit() {
    setEditingId(null);
    setIsCreating(false);
    setSectionError(null);
  }

  return (
    <div>
      <div className="mb-2 flex items-center justify-between">
        <h2 className="text-xs font-medium uppercase tracking-wider text-gray-400">
          Варианты
          <span className="ml-1.5 text-gray-300">({variants.length})</span>
        </h2>
        <button
          className="btn-secondary py-1 text-xs"
          onClick={startCreate}
          disabled={isCreating}
        >
          + Добавить вариант
        </button>
      </div>

      {sectionError && (
        <div className="mb-2 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {sectionError}
        </div>
      )}

      <div className="rounded-md border border-gray-200 bg-white">
        {isCreating && (
          <div className="border-b border-gray-100">
            <VariantForm
              onSave={(f) => handleSave(f, null)}
              onCancel={cancelEdit}
            />
          </div>
        )}

        {variants.length === 0 && !isCreating && (
          <p className="px-4 py-10 text-center text-sm text-gray-400">
            Вариантов пока нет
          </p>
        )}

        {variants.map((v) =>
          editingId === v.id ? (
            <div key={v.id} className="border-b border-gray-100 last:border-b-0">
              <VariantForm
                variant={v}
                onSave={(f) => handleSave(f, v.id)}
                onCancel={cancelEdit}
              />
            </div>
          ) : (
            <VariantRow
              key={v.id}
              variant={v}
              deleting={deletingId === v.id}
              deleteBlocked={isLastVariant}
              onEdit={() => startEdit(v.id)}
              onDelete={() => handleDelete(v.id)}
            />
          ),
        )}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Form data types & helpers
// ---------------------------------------------------------------------------

interface VariantFormData {
  title: string;
  price: string;
  old_price: string;
  quantity: string;
  editions: string;
  modifications: string;
  photo: string;
  weight: string;
  external_id: string;
  parent_uid: string;
  tilda_uid: string;
}

const EMPTY_FORM: VariantFormData = {
  title: "",
  price: "",
  old_price: "",
  quantity: "",
  editions: "",
  modifications: "",
  photo: "",
  weight: "",
  external_id: "",
  parent_uid: "",
  tilda_uid: "",
};

function variantToForm(v: ProductVariant): VariantFormData {
  return {
    title: v.title ?? "",
    price: v.price != null ? String(v.price) : "",
    old_price: v.old_price != null ? String(v.old_price) : "",
    quantity: v.quantity != null ? String(v.quantity) : "",
    editions: v.editions ?? "",
    modifications: v.modifications ?? "",
    photo: v.photo ?? "",
    weight: v.weight ?? "",
    external_id: v.external_id ?? "",
    parent_uid: v.parent_uid ?? "",
    tilda_uid: v.tilda_uid ?? "",
  };
}

function parseNum(s: string): number | null {
  const t = s.trim();
  if (!t) return null;
  const n = Number(t);
  return isNaN(n) ? null : n;
}

function corePayload(f: VariantFormData): VariantUpdate {
  return {
    title: f.title.trim() || null,
    price: parseNum(f.price),
    old_price: parseNum(f.old_price),
    quantity: parseNum(f.quantity),
    editions: f.editions.trim() || null,
    modifications: f.modifications.trim() || null,
    photo: f.photo.trim() || null,
    weight: f.weight.trim() || null,
    external_id: f.external_id.trim() || null,
    parent_uid: f.parent_uid.trim() || null,
    tilda_uid: f.tilda_uid.trim() || null,
  };
}

function formToInsertPayload(
  f: VariantFormData,
  productId: string,
): VariantInsert {
  return { product_id: productId, ...corePayload(f) } as VariantInsert;
}

function formToUpdatePayload(f: VariantFormData): VariantUpdate {
  return corePayload(f);
}

function validateForm(f: VariantFormData): string | null {
  if (!f.title.trim()) return "Название варианта обязательно";
  if (f.price.trim() && isNaN(Number(f.price)))
    return "Цена должна быть числом";
  if (f.old_price.trim() && isNaN(Number(f.old_price)))
    return "Старая цена должна быть числом";
  if (f.quantity.trim()) {
    const q = Number(f.quantity);
    if (isNaN(q) || !Number.isInteger(q))
      return "Количество должно быть целым числом";
  }
  if (f.price.trim() && Number(f.price) < 0)
    return "Цена не может быть отрицательной";
  if (f.old_price.trim() && Number(f.old_price) < 0)
    return "Старая цена не может быть отрицательной";
  if (f.quantity.trim() && Number(f.quantity) < 0)
    return "Количество не может быть отрицательным";
  return null;
}

// ---------------------------------------------------------------------------
// Variant form (create / edit)
// ---------------------------------------------------------------------------

function VariantForm({
  variant,
  onSave,
  onCancel,
}: {
  variant?: ProductVariant;
  onSave: (form: VariantFormData) => Promise<string | null>;
  onCancel: () => void;
}) {
  const isEdit = !!variant;
  const [form, setForm] = useState<VariantFormData>(
    variant ? variantToForm(variant) : EMPTY_FORM,
  );
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function update<K extends keyof VariantFormData>(
    field: K,
    value: VariantFormData[K],
  ) {
    setForm((f) => ({ ...f, [field]: value }));
    setError(null);
  }

  async function handleSubmit() {
    const validationError = validateForm(form);
    if (validationError) {
      setError(validationError);
      return;
    }
    setSaving(true);
    setError(null);
    const result = await onSave(form);
    if (result) {
      setError(result);
      setSaving(false);
    }
  }

  return (
    <div className="space-y-3 p-4">
      {isEdit && variant.variant_id && (
        <div>
          <span className="text-xs text-gray-400">variant_id </span>
          <span className="font-mono text-xs text-gray-500">
            {variant.variant_id}
          </span>
        </div>
      )}

      <FField label="Название">
        <input
          className="input"
          value={form.title}
          onChange={(e) => update("title", e.target.value)}
          placeholder="Название варианта"
        />
      </FField>

      <div className="grid gap-3 sm:grid-cols-4">
        <FField label="Цена">
          <input
            className="input"
            inputMode="decimal"
            value={form.price}
            onChange={(e) => update("price", e.target.value)}
            placeholder="0"
          />
        </FField>
        <FField label="Старая цена">
          <input
            className="input"
            inputMode="decimal"
            value={form.old_price}
            onChange={(e) => update("old_price", e.target.value)}
            placeholder="0"
          />
        </FField>
        <FField label="Количество">
          <input
            className="input"
            inputMode="numeric"
            value={form.quantity}
            onChange={(e) => update("quantity", e.target.value)}
            placeholder="0"
          />
        </FField>
        <FField label="Вес">
          <input
            className="input"
            value={form.weight}
            onChange={(e) => update("weight", e.target.value)}
          />
        </FField>
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        <FField label="Объём / размер">
          <input
            className="input"
            value={form.editions}
            onChange={(e) => update("editions", e.target.value)}
            placeholder="Например: 50мл; 100мл"
          />
        </FField>
        <FField label="Цвет / оттенок">
          <input
            className="input"
            value={form.modifications}
            onChange={(e) => update("modifications", e.target.value)}
          />
        </FField>
      </div>

      <FField label="Фото варианта (URL)">
        <input
          className="input"
          type="url"
          value={form.photo}
          onChange={(e) => update("photo", e.target.value)}
          placeholder="https://…"
        />
      </FField>

      <div className="grid gap-3 sm:grid-cols-3">
        <FField label="Внешний ID">
          <input
            className="input font-mono text-xs"
            value={form.external_id}
            onChange={(e) => update("external_id", e.target.value)}
          />
        </FField>
        <FField label="Parent UID">
          <input
            className="input font-mono text-xs"
            value={form.parent_uid}
            onChange={(e) => update("parent_uid", e.target.value)}
          />
        </FField>
        <FField label="Tilda UID">
          <input
            className="input font-mono text-xs"
            value={form.tilda_uid}
            onChange={(e) => update("tilda_uid", e.target.value)}
          />
        </FField>
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      <div className="flex items-center gap-2 pt-1">
        <button
          className="btn-primary py-1.5 text-xs"
          onClick={handleSubmit}
          disabled={saving}
        >
          {saving
            ? "Сохранение…"
            : isEdit
              ? "Обновить вариант"
              : "Создать вариант"}
        </button>
        <button
          className="btn-secondary py-1.5 text-xs"
          onClick={onCancel}
          disabled={saving}
        >
          Отмена
        </button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Variant display row
// ---------------------------------------------------------------------------

function VariantRow({
  variant: v,
  deleting,
  deleteBlocked,
  onEdit,
  onDelete,
}: {
  variant: ProductVariant;
  deleting: boolean;
  deleteBlocked: boolean;
  onEdit: () => void;
  onDelete: () => void;
}) {
  return (
    <div
      className={`flex items-center justify-between border-b border-gray-50 px-4 py-3 last:border-b-0 ${
        deleting ? "opacity-50" : ""
      }`}
    >
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-baseline gap-x-4 gap-y-1 text-sm">
          <span className="font-medium text-gray-900">
            {v.title || "Без названия"}
          </span>
          {v.price != null && (
            <span className="text-gray-600">{v.price.toLocaleString()}</span>
          )}
          {v.old_price != null && (
            <span className="text-gray-400 line-through">
              {v.old_price.toLocaleString()}
            </span>
          )}
          {v.quantity != null && (
            <span className="text-gray-400">кол-во: {v.quantity}</span>
          )}
          {v.editions && (
            <span className="text-xs text-gray-400">{v.editions}</span>
          )}
        </div>
        <p className="mt-0.5 font-mono text-[11px] text-gray-400">
          {v.variant_id}
        </p>
      </div>

      <div className="ml-4 flex shrink-0 items-center gap-1">
        <button
          className="rounded px-2 py-1 text-xs text-gray-500 transition-colors hover:bg-gray-100 hover:text-gray-700"
          onClick={onEdit}
          disabled={deleting}
        >
          Изменить
        </button>
        <button
          className={`rounded px-2 py-1 text-xs transition-colors ${
            deleteBlocked
              ? "cursor-not-allowed text-gray-300"
              : "text-red-400 hover:bg-red-50 hover:text-red-600"
          }`}
          onClick={onDelete}
          disabled={deleting || deleteBlocked}
          title={
            deleteBlocked ? "Нельзя удалить последний вариант" : undefined
          }
        >
          {deleting ? "…" : "Удалить"}
        </button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Tiny form-field wrapper (local to this file)
// ---------------------------------------------------------------------------

function FField({
  label,
  children,
}: {
  label: string;
  children: ReactNode;
}) {
  return (
    <div>
      <label className="mb-0.5 block text-xs font-medium text-gray-500">
        {label}
      </label>
      {children}
    </div>
  );
}
