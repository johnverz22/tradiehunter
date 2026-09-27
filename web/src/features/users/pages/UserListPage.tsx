import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { Search, CheckCircle, XCircle, ChevronUp, ChevronDown } from 'lucide-react';
import { StatusBadge } from '../../../components/StatusBadge';
import { Pagination } from '../../../components/Pagination';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { useUserList, useVerifyUser, useDeactivateUser } from '../hooks/useUsers';

type SortKey = 'fullName' | 'email' | 'role' | 'createdAt';

export const UserListPage: React.FC = () => {
  const [search, setSearch] = useState('');
  const [role, setRole] = useState('');
  const [page, setPage] = useState(1);
  const [sortBy, setSortBy] = useState<SortKey>('createdAt');
  const [sortDesc, setSortDesc] = useState(true);

  const [confirmAction, setConfirmAction] = useState<{
    type: 'verify' | 'deactivate';
    id: string;
    name: string;
  } | null>(null);

  const { data, isLoading } = useUserList({ search, role, page, pageSize: 20, sortBy, sortDesc });
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
        <p className="text-sm text-[var(--ink-soft)]">
          {data ? `${data.totalCount.toLocaleString()} total` : ''}
        </p>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--ink-soft)]" />
          <input
            type="search"
            placeholder="Search name or email…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            className="w-full pl-8 pr-3 py-2 text-sm border border-[var(--paper-line)] rounded bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:ring-2 focus:ring-[var(--brand-500)]"
          />
        </div>
        <select
          value={role}
          onChange={(e) => { setRole(e.target.value); setPage(1); }}
          className="px-3 py-2 text-sm border border-[var(--paper-line)] rounded bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:ring-2 focus:ring-[var(--brand-500)]"
        >
          <option value="">All roles</option>
          <option value="Admin">Admin</option>
          <option value="Homeowner">Homeowner</option>
          <option value="Tradie">Tradie</option>
        </select>
      </div>

      {/* Table */}
      <div className="border border-[var(--paper-line)] rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-[var(--paper-line)]/50">
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
                    className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide cursor-pointer hover:text-[var(--ink)] select-none"
                  >
                    {label}
                    <SortIcon col={key} />
                  </th>
                ))}
                <th className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Status</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Verified</th>
                <th className="px-4 py-3 text-right text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--paper-line)]">
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-[var(--ink-soft)]">
                    Loading…
                  </td>
                </tr>
              ) : data?.items.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-[var(--ink-soft)]">
                    No users found.
                  </td>
                </tr>
              ) : (
                data?.items.map((user) => (
                  <tr
                    key={user.id}
                    className="hover:bg-[var(--paper-line)]/30 transition-colors"
                  >
                    <td className="px-4 py-3 font-medium text-[var(--ink)]">
                      <Link
                        to={`/users/${user.id}`}
                        className="hover:text-[var(--brand-500)] hover:underline"
                      >
                        {user.fullName || '—'}
                      </Link>
                    </td>
                    <td className="px-4 py-3 text-[var(--ink-soft)]">{user.email}</td>
                    <td className="px-4 py-3">
                      <StatusBadge status={user.role} />
                    </td>
                    <td className="px-4 py-3 text-[var(--ink-soft)]">
                      {new Date(user.createdAtUtc).toLocaleDateString()}
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge status={user.isActive ? 'Active' : 'Inactive'} />
                    </td>
                    <td className="px-4 py-3">
                      {user.isVerified ? (
                        <span className="inline-flex items-center gap-1 text-xs text-green-600 dark:text-green-400">
                          <CheckCircle size={13} /> Verified
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 text-xs text-[var(--ink-soft)]">
                          <XCircle size={13} /> Unverified
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center justify-end gap-2">
                        {!user.isVerified && user.role === 'Tradie' && (
                          <button
                            onClick={() =>
                              setConfirmAction({ type: 'verify', id: user.id, name: user.fullName })
                            }
                            className="text-xs px-2.5 py-1 rounded border border-[var(--brand-300)] text-[var(--brand-700)] hover:bg-[var(--brand-100)] transition-colors"
                          >
                            Verify
                          </button>
                        )}
                        {user.isActive && (
                          <button
                            onClick={() =>
                              setConfirmAction({
                                type: 'deactivate',
                                id: user.id,
                                name: user.fullName,
                              })
                            }
                            className="text-xs px-2.5 py-1 rounded border border-red-200 text-[var(--red)] hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
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
      </div>

      {data && (
        <Pagination
          page={data.page}
          totalPages={data.totalPages}
          onPageChange={setPage}
        />
      )}

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
