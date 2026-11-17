/** docs/02-firestore-modeli.md ile uyumlu temel tipler (yalnız şu an kullanılanlar; modül ekledikçe genişler). */
export type Role = 'admin' | 'employee';
export type Permission = 'invoice.write' | 'party.write' | 'stock.write' | 'finance.write' | 'project.write';

export interface UserProfile {
  companyId: string;
  displayName: string;
  email: string;
  role: Role;
  permissions: Partial<Record<Permission, boolean>>;
  active: boolean;
}

export interface CompanySettings {
  allowNegativeStock: boolean;
  defaultVatBp: number;
  invoicePrefix: { sales: string; purchase: string; sales_return: string; purchase_return: string };
}

export interface Company {
  name: string;
  currency: string;
  settings: CompanySettings;
}
