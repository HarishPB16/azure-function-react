import axios from 'axios';
import type { Product, ProductInput } from '../types/product';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'http://localhost:7071/api',
  headers: { 'Content-Type': 'application/json' },
});

export const productService = {
  async getAll(): Promise<Product[]> {
    return (await api.get<Product[]>('/products')).data;
  },
  async create(input: ProductInput): Promise<Product> {
    return (await api.post<Product>('/products', input)).data;
  },
  async update(id: number, input: ProductInput): Promise<Product> {
    return (await api.put<Product>(`/products/${id}`, input)).data;
  },
  async remove(id: number): Promise<void> {
    await api.delete(`/products/${id}`);
  },
};
