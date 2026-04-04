import { Routes, Route, Navigate } from "react-router-dom";
import { AdminShell } from "../shared/layout/AdminShell";
import { DashboardPage } from "../modules/dashboard/DashboardPage";
import { ProductListPage } from "../modules/products/ProductListPage";
import { ProductEditorPage } from "../modules/products/ProductEditorPage";

export function AppRoutes() {
  return (
    <Routes>
      <Route element={<AdminShell />}>
        <Route index element={<Navigate to="/products" replace />} />
        <Route path="dashboard" element={<DashboardPage />} />
        <Route path="products" element={<ProductListPage />} />
        <Route path="products/new" element={<ProductEditorPage />} />
        <Route path="products/:id" element={<ProductEditorPage />} />
      </Route>
    </Routes>
  );
}
