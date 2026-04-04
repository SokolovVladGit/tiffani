import { useEffect, useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { PageHeader } from "../../shared/ui/PageHeader";
import { useProducts } from "./useProducts";
import {
  PAGE_SIZE,
  toggleProductActive,
  type StatusFilter,
  type MarkFilter,
  type SortOption,
} from "./api";

export function ProductListPage() {
  const navigate = useNavigate();
  const {
    rows,
    totalCount,
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
  } = useProducts();

  const [searchInput, setSearchInput] = useState("");
  const [togglingId, setTogglingId] = useState<string | null>(null);
  const [toggleError, setToggleError] = useState<string | null>(null);

  async function handleToggleActive(
    e: React.MouseEvent,
    id: string,
    currentlyActive: boolean,
  ) {
    e.stopPropagation();
    setTogglingId(id);
    setToggleError(null);
    try {
      await toggleProductActive(id, !currentlyActive);
      refresh();
    } catch (err: unknown) {
      setToggleError(
        err instanceof Error
          ? err.message
          : "Не удалось изменить видимость",
      );
    } finally {
      setTogglingId(null);
    }
  }

  useEffect(() => {
    const timer = setTimeout(() => {
      setFilters({ search: searchInput });
    }, 300);
    return () => clearTimeout(timer);
  }, [searchInput, setFilters]);

  const from = page * PAGE_SIZE + 1;
  const to = Math.min((page + 1) * PAGE_SIZE, totalCount);
  const hasData = rows.length > 0;
  const showSkeleton = loading && !hasData;
  const showEmpty = !loading && !hasData && !error;

  function handleClearFilters() {
    setSearchInput("");
    resetFilters();
  }

  return (
    <div>
      {/* Header */}
      <div className="flex items-center justify-between">
        <PageHeader
          title="Товары"
          description={
            totalCount > 0
              ? `${totalCount.toLocaleString()} товар(ов)`
              : undefined
          }
        />
        <Link to="/products/new" className="btn-primary">
          Добавить товар
        </Link>
      </div>

      {/* Filters row 1: search + sort */}
      <div className="mt-4 flex flex-wrap items-center gap-3">
        <input
          type="text"
          placeholder="Поиск по названию, внешнему ID или Tilda UID…"
          className="input min-w-[260px] max-w-sm flex-1"
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
        />

        <select
          className="input w-auto"
          value={filters.sort}
          onChange={(e) =>
            setFilters({ sort: e.target.value as SortOption })
          }
        >
          <option value="newest">Сначала новые</option>
          <option value="oldest">Сначала старые</option>
          <option value="title_asc">Название А → Я</option>
          <option value="title_desc">Название Я → А</option>
        </select>
      </div>

      {/* Filters row 2: dropdowns + clear */}
      <div className="mt-2 flex flex-wrap items-center gap-3">
        <select
          className="input w-auto"
          value={filters.status}
          onChange={(e) =>
            setFilters({ status: e.target.value as StatusFilter })
          }
        >
          <option value="all">Все статусы</option>
          <option value="active">Видимые</option>
          <option value="inactive">Скрытые</option>
        </select>

        <select
          className="input w-auto"
          value={filters.mark}
          onChange={(e) =>
            setFilters({ mark: e.target.value as MarkFilter })
          }
        >
          <option value="">Все метки</option>
          <option value="NEW">NEW</option>
          <option value="ХИТ">ХИТ</option>
          <option value="SALE">SALE</option>
          <option value="none">Без метки</option>
        </select>

        {brands.length > 0 && (
          <select
            className="input w-auto"
            value={filters.brand}
            onChange={(e) => setFilters({ brand: e.target.value })}
          >
            <option value="">Все бренды</option>
            {brands.map((b) => (
              <option key={b} value={b}>
                {b}
              </option>
            ))}
          </select>
        )}

        {categories.length > 0 && (
          <select
            className="input w-auto"
            value={filters.category}
            onChange={(e) => setFilters({ category: e.target.value })}
          >
            <option value="">Все категории</option>
            {categories.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </select>
        )}

        {hasActiveFilters && (
          <button
            className="text-xs font-medium text-gray-500 hover:text-gray-700"
            onClick={handleClearFilters}
          >
            Сбросить фильтры
          </button>
        )}
      </div>

      {/* Error */}
      {error && (
        <div className="mt-6 rounded-md border border-red-200 bg-red-50 px-4 py-3">
          <p className="text-sm text-red-700">{error}</p>
          <button
            onClick={retry}
            className="mt-2 text-sm font-medium text-red-600 hover:text-red-500"
          >
            Попробовать снова
          </button>
        </div>
      )}

      {/* Toggle error */}
      {toggleError && (
        <div className="mt-2 rounded-md border border-amber-200 bg-amber-50 px-4 py-2 text-sm text-amber-700">
          {toggleError}
        </div>
      )}

      {/* Table */}
      {!error && (
        <div
          className={`mt-4 overflow-hidden rounded-md border border-gray-200 bg-white transition-opacity ${
            loading && hasData ? "opacity-60" : ""
          }`}
        >
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 bg-gray-50/80 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                <th className="w-12 px-4 py-3" />
                <th className="px-4 py-3">Название</th>
                <th className="hidden px-4 py-3 md:table-cell">Бренд</th>
                <th className="hidden px-4 py-3 lg:table-cell">Категория</th>
                <th className="px-4 py-3">Метка</th>
                <th className="px-4 py-3">Видимость</th>
                <th className="hidden px-4 py-3 text-right sm:table-cell">
                  Дата
                </th>
              </tr>
            </thead>
            <tbody>
              {showSkeleton &&
                Array.from({ length: 10 }).map((_, i) => (
                  <tr key={i} className="border-b border-gray-50">
                    <td className="px-4 py-3">
                      <div className="h-9 w-9 animate-pulse rounded bg-gray-100" />
                    </td>
                    <td className="px-4 py-3" colSpan={6}>
                      <div className="h-4 w-2/3 animate-pulse rounded bg-gray-100" />
                    </td>
                  </tr>
                ))}

              {showEmpty && (
                <tr>
                  <td
                    colSpan={7}
                    className="px-4 py-16 text-center text-gray-400"
                  >
                    {hasActiveFilters
                      ? "Нет товаров, соответствующих фильтрам"
                      : "Товаров пока нет"}
                  </td>
                </tr>
              )}

              {hasData &&
                rows.map((product) => {
                  const inactive = !product.is_active;
                  const toggling = togglingId === product.id;
                  return (
                    <tr
                      key={product.id}
                      onClick={() => navigate(`/products/${product.id}`)}
                      className={`cursor-pointer border-b border-gray-50 transition-colors hover:bg-gray-50 ${
                        inactive ? "opacity-50" : ""
                      }`}
                    >
                      <td className="px-4 py-2.5">
                        {product.photo ? (
                          <img
                            src={product.photo}
                            alt=""
                            className="h-9 w-9 rounded object-cover"
                            loading="lazy"
                          />
                        ) : (
                          <div className="flex h-9 w-9 items-center justify-center rounded bg-gray-100 text-[10px] text-gray-400">
                            —
                          </div>
                        )}
                      </td>
                      <td className="px-4 py-2.5 font-medium text-gray-900">
                        {product.title}
                      </td>
                      <td className="hidden px-4 py-2.5 text-gray-500 md:table-cell">
                        {product.brand ?? "—"}
                      </td>
                      <td className="hidden px-4 py-2.5 text-gray-500 lg:table-cell">
                        {product.category ?? "—"}
                      </td>
                      <td className="px-4 py-2.5">
                        {product.mark ? (
                          <span className="inline-block rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-600">
                            {product.mark}
                          </span>
                        ) : (
                          <span className="text-gray-300">—</span>
                        )}
                      </td>
                      <td className="px-4 py-2.5">
                        <button
                          onClick={(e) =>
                            handleToggleActive(e, product.id, product.is_active)
                          }
                          disabled={toggling}
                          title={
                            product.is_active
                              ? "Нажмите, чтобы скрыть из приложения"
                              : "Нажмите, чтобы показать в приложении"
                          }
                          className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium transition-colors ${
                            product.is_active
                              ? "bg-emerald-50 text-emerald-700 hover:bg-emerald-100"
                              : "bg-gray-100 text-gray-500 hover:bg-gray-200"
                          } ${toggling ? "animate-pulse" : ""}`}
                        >
                          {toggling
                            ? "…"
                            : product.is_active
                              ? "Виден"
                              : "Скрыт"}
                        </button>
                      </td>
                      <td className="hidden px-4 py-2.5 text-right text-xs text-gray-400 sm:table-cell">
                        {product.created_at
                          ? shortDate(product.created_at)
                          : "—"}
                      </td>
                    </tr>
                  );
                })}
            </tbody>
          </table>

          {/* Pagination */}
          {totalCount > 0 && (
            <div className="flex items-center justify-between border-t border-gray-100 px-4 py-3">
              <span className="text-xs text-gray-500">
                {from.toLocaleString()}–{to.toLocaleString()} из{" "}
                {totalCount.toLocaleString()}
                {totalPages > 1 && (
                  <span className="ml-2 text-gray-400">
                    (стр. {page + 1} из {totalPages})
                  </span>
                )}
              </span>
              <div className="flex gap-2">
                <button
                  className="btn-secondary py-1.5 text-xs"
                  disabled={page === 0 || loading}
                  onClick={() => setPage(page - 1)}
                >
                  Назад
                </button>
                <button
                  className="btn-secondary py-1.5 text-xs"
                  disabled={page >= totalPages - 1 || loading}
                  onClick={() => setPage(page + 1)}
                >
                  Вперёд
                </button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function shortDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString("ru-RU", {
      day: "numeric",
      month: "short",
      year: "numeric",
    });
  } catch {
    return iso;
  }
}
