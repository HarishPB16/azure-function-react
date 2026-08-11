import { useEffect, useState } from 'react';
import type { Product, ProductInput } from '../types/product';

interface Props { product: Product | null; onSubmit: (input: ProductInput) => Promise<void>; onCancel: () => void; }
export function ProductForm({ product, onSubmit, onCancel }: Props) {
  const [name, setName] = useState(''); const [description, setDescription] = useState(''); const [price, setPrice] = useState(''); const [saving, setSaving] = useState(false); const [error, setError] = useState('');
  useEffect(() => { setName(product?.name ?? ''); setDescription(product?.description ?? ''); setPrice(product ? String(product.price) : ''); setError(''); }, [product]);
  async function submit(event: React.FormEvent) {
    event.preventDefault(); const value = Number(price);
    if (!name.trim()) return setError('Name is required.');
    if (!Number.isFinite(value) || value < 0) return setError('Price must be a non-negative number.');
    setSaving(true); setError('');
    try { await onSubmit({ name: name.trim(), description: description.trim(), price: value }); } catch { setError('Could not save the product. Please try again.'); } finally { setSaving(false); }
  }
  return <form className="product-form" onSubmit={submit}><h2>{product ? 'Edit product' : 'Add product'}</h2>{error && <p className="message error">{error}</p>}<label>Name<input maxLength={100} value={name} onChange={(e) => setName(e.target.value)} required /></label><label>Description<textarea maxLength={500} value={description} onChange={(e) => setDescription(e.target.value)} /></label><label>Price<input type="number" min="0" step="0.01" value={price} onChange={(e) => setPrice(e.target.value)} required /></label><div className="form-actions"><button type="submit" disabled={saving}>{saving ? 'Saving…' : 'Save'}</button><button type="button" className="secondary" onClick={onCancel} disabled={saving}>Cancel</button></div></form>;
}
