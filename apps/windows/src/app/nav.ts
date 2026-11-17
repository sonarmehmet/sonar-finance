import {
  LayoutDashboard, FileText, Users, Landmark, ArrowLeftRight, FolderKanban, Boxes,
  ScrollText, BarChart3, Archive, UserCog, Settings, type LucideIcon,
} from 'lucide-react';

export interface NavItem {
  key: string;          // tr.json menu.* anahtarı
  path: string;
  icon: LucideIcon;
  /** ertelenen modüller pasif gösterilir (docs/07) */
  disabled?: boolean;
  /** sidebar'da bu öğeden ÖNCE ayırıcı çizgi */
  sepBefore?: boolean;
}

export const NAV: NavItem[] = [
  { key: 'overview', path: '/overview', icon: LayoutDashboard },
  { key: 'invoices', path: '/invoices', icon: FileText },
  { key: 'parties', path: '/parties', icon: Users },
  { key: 'cashBank', path: '/cash-bank', icon: Landmark, sepBefore: true },
  { key: 'incomeExpense', path: '/income-expense', icon: ArrowLeftRight },
  { key: 'projects', path: '/projects', icon: FolderKanban },
  { key: 'stock', path: '/stock', icon: Boxes, sepBefore: true },
  { key: 'chequesNotes', path: '/cheques-notes', icon: ScrollText, disabled: true },
  { key: 'reports', path: '/reports', icon: BarChart3, sepBefore: true },
  { key: 'documents', path: '/documents', icon: Archive, disabled: true },
  { key: 'users', path: '/users', icon: UserCog, sepBefore: true },
  { key: 'settings', path: '/settings', icon: Settings },
];
