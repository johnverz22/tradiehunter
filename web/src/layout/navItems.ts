import {
  LayoutDashboard,
  Users,
  Briefcase,
  ShieldCheck,
  AlertTriangle,
  Wallet,
  RotateCcw,
  ScrollText,
  Settings,
  Banknote,
} from 'lucide-react';
import type { NavItem } from './SidebarNav';

export const navItems: NavItem[] = [
  { to: '/dashboard', label: 'Dashboard', Icon: LayoutDashboard },
  { to: '/users', label: 'Users', Icon: Users },
  { to: '/jobs', label: 'Jobs', Icon: Briefcase },
  { to: '/credentials', label: 'Credentials', Icon: ShieldCheck },
  { to: '/payments', label: 'Payments', Icon: Wallet },
  { to: '/payouts', label: 'Payouts', Icon: Banknote },
  { to: '/refunds', label: 'Refunds', Icon: RotateCcw },
  { to: '/disputes', label: 'Disputes', Icon: AlertTriangle },
  { to: '/audit-logs', label: 'Audit Logs', Icon: ScrollText },
  { to: '/settings', label: 'Settings', Icon: Settings },
];
