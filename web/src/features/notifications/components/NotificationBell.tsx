/**
 * NotificationBell — staff alert bell in TopBar with unread badge and dropdown.
 * Polls every 30s and refetches on window focus (plan 09 N6.3).
 */
import React, { useEffect, useId, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bell, CheckCheck } from 'lucide-react';
import { Badge } from '../../../components/Badge';
import { Button, IconButton } from '../../../components/Button';
import { EmptyState } from '../../../components/EmptyState';
import type { StaffNotification } from '../../../services/adminApi';
import {
  useMarkAllNotificationsRead,
  useMarkNotificationRead,
  useStaffNotifications,
} from '../hooks/useStaffNotifications';

function resolveNotificationPath(n: StaffNotification): string {
  if (n.adminPath) return n.adminPath;
  switch (n.entityType) {
    case 'payment':
      return '/payments';
    case 'credential':
      return '/credentials';
    case 'dispute':
    case 'dispute-evidence':
      return `/disputes/${n.entityId}`;
    case 'flag': {
      const userId = n.entityId.split(':')[0];
      return userId ? `/users/${userId}` : '/users';
    }
    case 'user':
      return `/users/${n.entityId}`;
    case 'payout-batch':
      return '/payouts';
    case 'job':
      return `/jobs/${n.entityId}`;
    default:
      return '/dashboard';
  }
}

function formatRelativeTime(isoUtc: string): string {
  const ms = Date.now() - new Date(isoUtc).getTime();
  if (Number.isNaN(ms) || ms < 60_000) return 'Just now';
  const mins = Math.floor(ms / 60_000);
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

export const NotificationBell: React.FC = () => {
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const panelId = useId();

  const { data } = useStaffNotifications(20);
  const markRead = useMarkNotificationRead();
  const markAllRead = useMarkAllNotificationsRead();

  const items = data?.items ?? [];
  const unreadCount = data?.unreadCount ?? 0;

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent | TouchEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setOpen(false);
        triggerRef.current?.focus();
      }
    };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('touchstart', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('touchstart', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  const handleSelect = (n: StaffNotification) => {
    if (!n.readUtc) {
      markRead.mutate(n.id);
    }
    setOpen(false);
    navigate(resolveNotificationPath(n));
  };

  return (
    <div ref={rootRef} className="relative">
      <IconButton
        ref={triggerRef}
        label={unreadCount > 0 ? `Notifications (${unreadCount} unread)` : 'Notifications'}
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-controls={open ? panelId : undefined}
        onClick={() => setOpen((o) => !o)}
      >
        <Bell size={18} aria-hidden="true" />
        {unreadCount > 0 && (
          <Badge tone="danger" className="notif-bell-count">
            {unreadCount > 99 ? '99+' : unreadCount}
          </Badge>
        )}
      </IconButton>

      {open && (
        <div
          id={panelId}
          role="dialog"
          aria-label="Staff notifications"
          className="menu notif-menu absolute right-0 top-full z-50 mt-2"
        >
          <div className="notif-menu-head">
            <div className="flex items-center gap-2">
              <strong className="t-title">Notifications</strong>
              {unreadCount > 0 && <Badge tone="info">{unreadCount} unread</Badge>}
            </div>
            {unreadCount > 0 && (
              <Button
                kind="ghost"
                size="sm"
                icon={<CheckCheck size={14} />}
                loading={markAllRead.isPending}
                onClick={() => markAllRead.mutate()}
              >
                Mark all read
              </Button>
            )}
          </div>

          {items.length === 0 ? (
            <EmptyState title="No notifications" icon={<Bell size={20} />}>
              You&apos;re all caught up.
            </EmptyState>
          ) : (
            <ul className="notif-list">
              {items.map((n) => {
                const isUnread = !n.readUtc;
                return (
                  <li key={n.id}>
                    <button
                      type="button"
                      className={`notif-item ${isUnread ? 'notif-item-unread' : ''}`.trim()}
                      onClick={() => handleSelect(n)}
                    >
                      <div className="notif-item-top">
                        <span className="notif-item-title">{n.title}</span>
                        <span className="notif-item-time">{formatRelativeTime(n.createdUtc)}</span>
                      </div>
                      <p className="notif-item-body">{n.body}</p>
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      )}
    </div>
  );
};
