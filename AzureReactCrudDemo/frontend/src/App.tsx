import { useCallback, useEffect, useState } from "react";
import axios from "axios";
import { InteractionStatus } from "@azure/msal-browser";
import { useIsAuthenticated, useMsal } from "@azure/msal-react";
import { loginRequest } from "./authConfig";
import { ProductForm } from "./components/ProductForm";
import { ProductTable } from "./components/ProductTable";
import { productService } from "./services/productService";
import type { Product, ProductInput } from "./types/product";
import "./styles.css";

export default function App() {
  const isAuthenticated = useIsAuthenticated();
  const { accounts, inProgress, instance } = useMsal();

  if (inProgress !== InteractionStatus.None) {
    return <main className="auth-page"><p>Completing Microsoft Entra sign-in…</p></main>;
  }

  if (!isAuthenticated) {
    return (
      <main className="auth-page">
        <section className="auth-card">
          <h1>Azure React CRUD Demo</h1>
          <p>Sign in with your organization account to manage products.</p>
          <button onClick={() => void instance.loginRedirect(loginRequest)}>Sign in with Microsoft</button>
        </section>
      </main>
    );
  }

  return <ProductApplication userName={accounts[0]?.name ?? accounts[0]?.username ?? "Signed-in user"} onSignOut={() => void instance.logoutRedirect()} />;
}

function ProductApplication({ userName, onSignOut }: { userName: string; onSignOut: () => void }) {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [editing, setEditing] = useState<Product | null | undefined>(undefined);
  const loadProducts = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      setProducts(await productService.getAll());
    } catch (err) {
      setError(
        axios.isAxiosError(err)
          ? `Could not load products: ${err.response?.data?.message ?? err.message}`
          : "Could not load products.",
      );
    } finally {
      setLoading(false);
    }
  }, []);
  useEffect(() => {
    void loadProducts();
  }, [loadProducts]);
  async function save(input: ProductInput) {
    const wasEditing = editing !== null;
    if (editing) await productService.update(editing.id, input);
    else await productService.create(input);
    setEditing(undefined);
    setSuccess(wasEditing ? "Product updated." : "Product added.");
    await loadProducts();
  }
  async function deleteProduct(product: Product) {
    if (!window.confirm(`Delete “${product.name}”?`)) return;
    setError("");
    try {
      await productService.remove(product.id);
      setSuccess("Product deleted.");
      await loadProducts();
    } catch {
      setError("Could not delete the product.");
    }
  }
  return (
    <main className="page">
      <header>
        <div>
          <h1>Products</h1>
          <p>Azure React CRUD Demo</p>
        </div>
        <div className="header-actions">
          <span className="user-name">{userName}</span>
          <button
            onClick={() => {
              setSuccess("");
              setEditing(null);
            }}
          >
            Add product
          </button>
          <button className="secondary" onClick={onSignOut}>Sign out</button>
        </div>
      </header>
      {success && <p className="message success">{success}</p>}
      {error && <p className="message error">{error}</p>}
      {editing !== undefined && (
        <ProductForm
          product={editing}
          onSubmit={save}
          onCancel={() => setEditing(undefined)}
        />
      )}
      {loading ? (
        <p className="loading">Loading products…</p>
      ) : (
        <ProductTable
          products={products}
          onEdit={(p) => {
            setSuccess("");
            setEditing(p);
          }}
          onDelete={deleteProduct}
        />
      )}
    </main>
  );
}
