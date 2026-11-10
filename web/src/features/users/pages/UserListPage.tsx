import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Search, CheckCircle, XCircle } from 'lucide-react';
import { PageHeader } from '../../../components/PageHeader';
import { FilterBar } from '../../../components/FilterBar';
import { DataTable, type ColumnDef, type RowAction } from '../../../components/DataTable';
import { StatusBadge } from '../../../components/StatusBadge';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { Pagination } from '../../../components/Pagination';
import { useUserList, useVerifyUser, useDeactivateUser } from '../hooks/useUsers';
import type { AdminUserListItem } from '../../../services/adminApi';

const PAGE_SIZE = 20;

type SortKey = 'fullName' | 'email' | 'role' | 'createdAt';

export const UserListPage: React.FC = () => {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const [role, setRole] = useState('');
  const [flaggedOnly, setFlaggedOnly] = useState(false);
  const [page, setPage] = useState(1);
  const [sortBy, setSortBy] = useState<SortKey>('createdAt');
  const [sortDesc, setSortDesc] = useState(true);

  const [confirmAction, setConfirmAction] = useState<{
    type: 'verify' | 'deactivate';
    id: string;
    name: string;
  } | null>(null);

  const { data, isLoading } = useUserList({
    search,
    role,
    flaggedOnly,
    page,
    pageSize: PAGE_SIZE,
    sortBy,
    sortDesc,
  });
  const verifyMutation = useVerifyUser();
  const deactivateMutation = useDeactivateUser();

  const toggleSort = (key: string) => {
    const k = key as SortKey;
    if (sortBy === k) setSortDesc((d) => !d);
    else {
      setSortBy(k);
      setSortDesc(false);
    }
  };

  const handleConfirm = async () => {
    if (!confirmAction) return;
    if (confirmAction.type === 'verify') await verifyMutation.mutateAsync(confirmAction.id);
    else await deactivateMutation.mutateAsync(confirmAction.id);
    setConfirmAction(null);
  };

  const activeFiltersCount = (role ? 1 : 0) + (flaggedOnly ? 1 : 0);

  const columns: ColumnDef<AdminUserListItem>[] = [
    {
      key: 'fullName',
      header: 'Name',
      priority: 'primary',
      sortable: true,
      cell: (user) => (
        <Link to={`/users/${user.id}`} className="cell-link flex items-center gap-2">
          {user.fullName || '—'}
        </Link>
      ),
    },
    {
      key: 'email',
      header: 'Email',
      priority: 'detail',
      sortable: true,
      cell: (user) => <span className="mono cell-muted">{user.email}</span>,
    },
    {
      key: 'role',
      header: 'Role',
      priority: 'secondary',
      sortable: true,
      cell: (user) => <StatusBadge status={user.role} />,
    },
    {
      key: 'createdAt',
      header: 'Joined',
      priority: 'detail',
      sortable: true,
      cell: (user) => (
        <span className="cell-muted">
          {new Date(user.createdAtUtc).toLocaleDateString()}
        </span>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      priority: 'secondary',
      cell: (user) => (
        <StatusBadge status={user.isActive ? 'Active' : 'Inactive'} />
      ),
    },
    {
      key: 'verified',
      header: 'Verified',
      priority: 'secondary',
      cell: (user) =>
        user.isVerified ? (
          <span className="pill pill-green">
            <CheckCircle size={12} className="inline -mt-0.5" /> Verified
          </span>
        ) : (
          <span className="pill pill-amber">
            <XCircle size={12} className="inline -mt-0.5" /> Unverified
          </span>
        ),
    },
  ];

  const rowActions = (user: AdminUserListItem): RowAction[] => {
    const actions: RowAction[] = [];
    if (!user.isVerified && user.role === 'Tradie') {
      actions.push({
        label: 'Verify',
        onClick: () => setConfirmAction({ type: 'verify', id: user.id, name: user.fullName }),
        variant: 'ghost',
        primary: true,
      });
    }
    if (user.isActive) {
      actions.push({
        label: 'Deactivate',
        onClick: () => setConfirmAction({ type: 'deactivate', id: user.id, name: user.fullName }),
        variant: 'danger',
      });
    }
    return actions;
  };

  return (
    <div className="space-y-5">
      {/* Header */}
      <PageHeader
        title="Users"
        meta={
          data && (
            <>
              <div className="stat-pill">
                <strong>{data.totalCount.toLocaleString()}</strong> {role || 'All roles'}
              </div>
              <div className="stat-pill">
                <strong>{data.items.length}</strong> on this page
              </div>
            </>
          )
        }
      />

      {/* Filters */}
      <FilterBar
        activeFiltersCount={activeFiltersCount}
        onClear={() => {
          setRole('');
          setFlaggedOnly(false);
          setPage(1);
        }}
      >
        <div className="relative flex-1 min-w-48">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--ink-soft)]" />
          <input
            type="search"
            className="field field-search"
            placeholder="Search name or email…"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
          />
        </div>
        <span className="select-wrap">
          <select
            className="select-field"
            value={role}
            onChange={(e) => {
              setRole(e.target.value);
              setPage(1);
            }}
            aria-label="Filter by role"
          >
            <option value="">All roles</option>
            <option value="Superadmin">Superadmin</option>
            <option value="Staff">Staff</option>
            <option value="Homeowner">Homeowner</option>
            <option value="Tradie">Tradie</option>
          </select>
        </span>
        <label className="flex items-center gap-2 text-sm text-[var(--ink)] cursor-pointer">
          <input
            type="checkbox"
            checked={flaggedOnly}
            onChange={(e) => {
              setFlaggedOnly(e.target.checked);
              setPage(1);
            }}
            className="rounded border-gray-300 text-[var(--brand-500)] focus:ring-[var(--brand-500)]"
          />
          Flagged Accounts Only
        </label>
      </FilterBar>

      {/* Table */}
      <DataTable
        columns={columns}
        rows={data?.items}
        getRowKey={(u) => u.id}
        onRowClick={(u) => navigate(`/users/${u.id}`)}
        isLoading={isLoading}
        sortState={{ key: sortBy, desc: sortDesc }}
        onSort={toggleSort}
        rowActions={rowActions}
        empty="No users found."
        pagination={
          data ? (
            <Pagination
              page={data.page}
              totalPages={data.totalPages}
              pageSize={data.pageSize}
              totalCount={data.totalCount}
              itemLabel="users"
              onPageChange={setPage}
            />
          ) : undefined
        }
      />

      {/* Confirm modal */}
      <ConfirmModal
        open={confirmAction !== null}
        title={
          confirmAction?.type === 'verify'
            ? `Verify ${confirmAction?.name}?`
            : `Deactivate ${confirmAction?.name}?`
        }
        message={
          confirmAction?.type === 'verify'
            ? 'This will mark the tradie as verified. They will be eligible for job matches.'
            : 'This will disable the user\'s login access. This action can be reversed by re-activating the account.'
        }
        confirmLabel={confirmAction?.type === 'verify' ? 'Verify' : 'Deactivate'}
        destructive={confirmAction?.type === 'deactivate'}
        onConfirm={handleConfirm}
        onCancel={() => setConfirmAction(null)}
      />
    </div>
  );
};
