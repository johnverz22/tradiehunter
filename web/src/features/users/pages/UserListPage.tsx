import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Search } from 'lucide-react';
import { PageHeader } from '../../../components/PageHeader';
import { FilterBar } from '../../../components/FilterBar';
import { DataTable, type ColumnDef, type RowAction } from '../../../components/DataTable';
import { StatusBadge } from '../../../components/StatusBadge';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { Pagination } from '../../../components/Pagination';
import { useUserList, useVerifyUser } from '../hooks/useUsers';
import { AccountStatusModal, type AccountStatusAction } from '../components/AccountStatusModal';
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
    type: 'verify';
    id: string;
    name: string;
  } | null>(null);
  const [statusChange, setStatusChange] = useState<{
    action: AccountStatusAction;
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
    await verifyMutation.mutateAsync(confirmAction.id);
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
        <Link to={`/users/${user.id}`} className="cell-link">
          {user.fullName || '—'}
        </Link>
      ),
    },
    {
      key: 'email',
      header: 'Email',
      priority: 'detail',
      sortable: true,
      cell: (user) => <span className="mono muted">{user.email}</span>,
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
        <span className="muted">
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
      cell: (user) => <StatusBadge status={user.isVerified ? 'Verified' : 'Unverified'} />,
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
        onClick: () => setStatusChange({ action: 'deactivate', id: user.id, name: user.fullName }),
        variant: 'danger',
      });
    } else {
      actions.push({
        label: 'Reactivate',
        onClick: () => setStatusChange({ action: 'reactivate', id: user.id, name: user.fullName }),
        variant: 'ghost',
      });
    }
    return actions;
  };

  return (
    <>
      <PageHeader title="Users" description="Homeowners, tradies and staff" />

      {/* Filters */}
      <FilterBar
        activeFiltersCount={activeFiltersCount}
        onClear={() => {
          setRole('');
          setFlaggedOnly(false);
          setPage(1);
        }}
      >
        <label className="input-icon">
          <span className="sr-only">Search users by name or email</span>
          <Search size={20} aria-hidden="true" />
          <input
            type="search"
            className="field"
            placeholder="Search name or email…"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
          />
        </label>
        <span className="select-wrap">
          <select
            className="select"
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
        <label className="choice">
          <input
            type="checkbox"
            className="check"
            checked={flaggedOnly}
            onChange={(e) => {
              setFlaggedOnly(e.target.checked);
              setPage(1);
            }}
          />
          Flagged accounts only
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

      {/* Verify confirm */}
      <ConfirmModal
        open={confirmAction !== null}
        title={`Verify ${confirmAction?.name ?? ''}?`}
        message="This will mark the tradie as verified. They will be eligible for job matches."
        confirmLabel="Verify"
        onConfirm={handleConfirm}
        onCancel={() => setConfirmAction(null)}
      />

      {/* Deactivate / reactivate with required note */}
      <AccountStatusModal
        action={statusChange?.action ?? null}
        user={statusChange ? { id: statusChange.id, name: statusChange.name } : null}
        onClose={() => setStatusChange(null)}
      />
    </>
  );
};
