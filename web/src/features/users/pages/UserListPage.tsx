import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { Search, ChevronDown, ChevronUp, CheckCircle, XCircle, } from 'lucide-react';
import { StatusBadge } from '../../../components/StatusBadge';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { Pagination } from '../../../components/Pagination';
import { useUserList, useVerifyUser, useDeactivateUser } from '../hooks/useUsers';

const PAGE_SIZE = 20;

type SortKey = 'fullName' | 'email' | 'role' | 'createdAt';

export const UserListPage: React.FC = () => {
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

  const { data, isLoading } = useUserList({ search, role, flaggedOnly, page, pageSize: PAGE_SIZE, sortBy, sortDesc });
  const verifyMutation = useVerifyUser();
  const deactivateMutation = useDeactivateUser();

  const toggleSort = (key: SortKey) => {
    if (sortBy === key) setSortDesc((d) => !d);
    else { setSortBy(key); setSortDesc(false); }
  };

  const SortIcon = ({ col }: { col: SortKey }) =>
    sortBy === col
      ? sortDesc
        ? <ChevronDown size={13} className="inline ml-1" />
        : <ChevronUp size={13} className="inline ml-1" />
      : null;

  const handleConfirm = async () => {
    if (!confirmAction) return;
    if (confirmAction.type === 'verify') await verifyMutation.mutateAsync(confirmAction.id);
    else await deactivateMutation.mutateAsync(confirmAction.id);
    setConfirmAction(null);
  };

  return (
    <div className="space-y-5">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-[var(--ink)]">Users</h1>
        {data && (
          <div className="flex flex-wrap gap-4 mt-3">
            <div className="stat-pill">
              <strong>{data.totalCount.toLocaleString()}</strong> {role || 'All roles'}
            </div>
            <div className="stat-pill">
              <strong>{data.items.length}</strong> on this page
            </div>
          </div>
        )}
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-48">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--ink-soft)]" />
          <input
            type="search"
            className="field field-search"
            placeholder="Search name or email…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          />
        </div>
        <span className="select-wrap">
          <select
            className="select-field"
            value={role}
            onChange={(e) => { setRole(e.target.value); setPage(1); }}
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
            onChange={(e) => { setFlaggedOnly(e.target.checked); setPage(1); }}
            className="rounded border-gray-300 text-[var(--brand-500)] focus:ring-[var(--brand-500)]"
          />
          Flagged Accounts Only
        </label>
      </div>

      {/* Table */}
      <div className="table-container">
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                {(
                  [
                    ['fullName', 'Name'],
                    ['email', 'Email'],
                    ['role', 'Role'],
                    ['createdAt', 'Joined'],
                  ] as [SortKey, string][]
                ).map(([key, label]) => (
                  <th
                    key={key}
                    onClick={() => toggleSort(key)}
                    className="th th-sortable"
                  >
                    {label}
                    <SortIcon col={key} />
                  </th>
                ))}
                <th className="th">Status</th>
                <th className="th">Verified</th>
                <th className="th text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="td text-center cell-muted">Loading…</td>
                </tr>
              ) : data?.items.length === 0 ? (
                <tr>
                  <td colSpan={7} className="td text-center cell-muted">No users found.</td>
                </tr>
              ) : (
                data?.items.map((user) => (
                  <tr key={user.id}>
                    <td className="td">
                      <Link to={`/users/${user.id}`} className="cell-link flex items-center gap-2">
                        {user.fullName || '—'}
                      </Link>
                    </td>
                    <td className="td mono cell-muted">{user.email}</td>
                    <td className="td"><StatusBadge status={user.role} /></td>
                    <td className="td cell-muted">
                      {new Date(user.createdAtUtc).toLocaleDateString()}
                    </td>
                    <td className="td">
                      <StatusBadge status={user.isActive ? 'Active' : 'Inactive'} />
                    </td>
                    <td className="td">
                      {user.isVerified ? (
                        <span className="pill pill-green">
                          <CheckCircle size={12} className="inline -mt-0.5" /> Verified
                        </span>
                      ) : (
                        <span className="pill pill-amber">
                          <XCircle size={12} className="inline -mt-0.5" /> Unverified
                        </span>
                      )}
                    </td>
                    <td className="td">
                      <div className="flex items-center justify-end gap-2">
                        {!user.isVerified && user.role === 'Tradie' && (
                          <button
                            className="btn btn-ghost !py-1 !px-2.5 !text-xs"
                            onClick={() =>
                              setConfirmAction({ type: 'verify', id: user.id, name: user.fullName })
                            }
                          >
                            Verify
                          </button>
                        )}
                        {user.isActive && (
                          <button
                            className="btn btn-danger !py-1 !px-2.5 !text-xs"
                            onClick={() =>
                              setConfirmAction({
                                type: 'deactivate',
                                id: user.id,
                                name: user.fullName,
                              })
                            }
                          >
                            Deactivate
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {data && (
          <Pagination
            page={data.page}
            totalPages={data.totalPages}
            pageSize={data.pageSize}
            totalCount={data.totalCount}
            itemLabel="users"
            onPageChange={setPage}
          />
        )}
      </div>

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
