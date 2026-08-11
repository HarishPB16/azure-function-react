import type { Product } from '../types/product';

interface Props {
  products: Product[];
  onEdit: (product: Product) => void;
  onDelete: (product: Product) => void;
}

export function ProductTable({ products, onEdit, onDelete }: Props) {
  if (products.length === 0) return <p className="empty">No products yet. Add the first one.</p>;

  return (
    <div className="table-wrap">
      <table>
        <thead><tr><th>ID</th><th>Name</th><th>Description</th><th>Price</th><th>Actions</th></tr></thead>
        <tbody>
          {products.map((product) => (
            <tr key={product.id}>
              <td>{product.id}</td><td>{product.name}</td><td>{product.description || '—'}</td>
              <td>{new Intl.NumberFormat(undefined, { style: 'currency', currency: 'INR' }).format(product.price)}</td>
              <td className="actions"><button className="secondary" onClick={() => onEdit(product)}>Edit</button><button className="danger" onClick={() => onDelete(product)}>Delete</button></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
