/**
 * URL-based image management for a product.
 *
 * No file upload or storage bucket integration — images are
 * added by URL only. The `product-images` bucket does not exist.
 */

import { useState } from "react";
import {
  addImage,
  updateImagePosition,
  deleteImage as apiDelete,
  fetchProductImages,
} from "./api";
import type { ProductImage, ImageInsert } from "../../lib/types/database";

interface Props {
  productId: string;
  initialImages: ProductImage[];
}

export function ImageManager({ productId, initialImages }: Props) {
  const [images, setImages] = useState<ProductImage[]>(initialImages);
  const [urlInput, setUrlInput] = useState("");
  const [adding, setAdding] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function reload() {
    try {
      setImages(await fetchProductImages(productId));
    } catch {
      /* best-effort */
    }
  }

  async function handleAdd() {
    const url = urlInput.trim();
    if (!url) return;

    if (!/^https?:\/\/.+/i.test(url)) {
      setError("Ссылка должна начинаться с http:// или https://");
      return;
    }

    setAdding(true);
    setError(null);

    try {
      const nextPos =
        images.length > 0
          ? Math.max(...images.map((i) => i.position)) + 1
          : 0;

      const payload: ImageInsert = {
        product_id: productId,
        url,
        position: nextPos,
      };

      await addImage(payload);
      setUrlInput("");
      await reload();
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Не удалось добавить фото",
      );
    } finally {
      setAdding(false);
    }
  }

  async function handleDelete(id: string) {
    if (!window.confirm("Удалить это фото?")) return;
    setBusyId(id);
    setError(null);

    try {
      await apiDelete(id);
      await reload();
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Не удалось удалить фото",
      );
    } finally {
      setBusyId(null);
    }
  }

  async function handleMove(index: number, direction: -1 | 1) {
    const targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= images.length) return;

    const a = images[index]!;
    const b = images[targetIndex]!;

    setBusyId(a.id);
    setError(null);

    try {
      await updateImagePosition(a.id, b.position);
      await updateImagePosition(b.id, a.position);
      await reload();
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Не удалось изменить порядок",
      );
    } finally {
      setBusyId(null);
    }
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Enter" && !adding) {
      e.preventDefault();
      handleAdd();
    }
  }

  return (
    <div>
      <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-gray-400">
        Дополнительные фото
        <span className="ml-1.5 text-gray-300">({images.length})</span>
      </h2>
      <p className="mb-2 text-xs text-gray-400">
        Галерея товара. Эти фото показываются в приложении вместе с главным.
        Если список пуст — используется только главное фото.
      </p>

      <div className="rounded-md border border-gray-200 bg-white">
        {/* Add by URL */}
        <div className="flex gap-2 border-b border-gray-100 p-3">
          <input
            className="input flex-1"
            type="url"
            value={urlInput}
            onChange={(e) => {
              setUrlInput(e.target.value);
              setError(null);
            }}
            onKeyDown={handleKeyDown}
            placeholder="Вставьте ссылку на фото (https://…)"
            disabled={adding}
          />
          <button
            className="btn-secondary shrink-0 py-1.5 text-xs"
            onClick={handleAdd}
            disabled={adding || !urlInput.trim()}
          >
            {adding ? "Добавление…" : "Добавить фото"}
          </button>
        </div>

        {/* Error */}
        {error && (
          <div className="border-b border-gray-100 px-3 py-2 text-sm text-red-600">
            {error}
          </div>
        )}

        {/* Row-based image list */}
        {images.length === 0 ? (
          <p className="px-4 py-10 text-center text-sm text-gray-400">
            Фото ещё не добавлены
          </p>
        ) : (
          <ul className="divide-y divide-gray-100">
            {images.map((img, i) => (
              <ImageRow
                key={img.id}
                image={img}
                index={i}
                total={images.length}
                busy={busyId === img.id}
                onMoveUp={() => handleMove(i, -1)}
                onMoveDown={() => handleMove(i, 1)}
                onDelete={() => handleDelete(img.id)}
              />
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Row-based image entry
// ---------------------------------------------------------------------------

function ImageRow({
  image,
  index,
  total,
  busy,
  onMoveUp,
  onMoveDown,
  onDelete,
}: {
  image: ProductImage;
  index: number;
  total: number;
  busy: boolean;
  onMoveUp: () => void;
  onMoveDown: () => void;
  onDelete: () => void;
}) {
  const isFirst = index === 0;
  const isLast = index === total - 1;

  return (
    <li
      className={`flex items-center gap-3 px-3 py-2.5 ${
        busy ? "pointer-events-none opacity-50" : ""
      }`}
    >
      <img
        src={image.url}
        alt={`#${image.position}`}
        className="h-14 w-14 shrink-0 rounded border border-gray-200 object-cover"
        loading="lazy"
        onError={(e) => {
          (e.target as HTMLImageElement).style.display = "none";
        }}
      />

      <div className="min-w-0 flex-1">
        <p className="truncate text-xs text-gray-500" title={image.url}>
          {image.url}
        </p>
        <span className="text-[10px] text-gray-300">
          Позиция {image.position}
        </span>
      </div>

      <div className="flex shrink-0 items-center gap-1">
        <RowBtn
          label="↑"
          title="Переместить выше"
          disabled={isFirst}
          onClick={onMoveUp}
        />
        <RowBtn
          label="↓"
          title="Переместить ниже"
          disabled={isLast}
          onClick={onMoveDown}
        />
        <button
          onClick={onDelete}
          title="Удалить фото"
          className="ml-1 rounded px-1.5 py-0.5 text-xs text-red-400 transition-colors hover:bg-red-50 hover:text-red-600"
        >
          Удалить
        </button>
      </div>
    </li>
  );
}

function RowBtn({
  label,
  title,
  disabled,
  onClick,
}: {
  label: string;
  title: string;
  disabled: boolean;
  onClick: () => void;
}) {
  return (
    <button
      title={title}
      disabled={disabled}
      onClick={onClick}
      className="rounded px-1.5 py-0.5 text-xs text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-700 disabled:cursor-default disabled:text-gray-200 disabled:hover:bg-transparent"
    >
      {label}
    </button>
  );
}
