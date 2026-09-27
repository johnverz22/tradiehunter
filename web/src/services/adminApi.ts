import api from './api';

// ── Shared ────────────────────────────────────────────────────────────────────

export interface PagedResult<T> {
  items: T[];
  totalCount: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

// ── Stats ─────────────────────────────────────────────────────────────────────

export interface AdminStats {
  totalUsers: number;
  activeJobs: number;
  pendingDisputes: number;
  todaySignups: number;
  jobsByStatus: Record<string, number>;
  signupsOverTime: Record<string, number>;
}

export const fetchStats = (): Promise<AdminStats> =>
  api.get('/admin/stats').then((r) => r.data);

// ── Metrics ───────────────────────────────────────────────────────────────────

export interface MetricsWindow {
  activationRatePct: number;
  avgMatchToConfirmationHours: number;
  tradieResponseRatePct: number;
  reviewCompletionRatePct: number;
  totalJobs: number;
  totalSignups: number;
}

export interface AdminMetrics {
  last7Days: MetricsWindow;
  last30Days: MetricsWindow;
  allTime: MetricsWindow;
}

export const fetchMetrics = (): Promise<AdminMetrics> =>
  api.get('/admin/metrics').then((r) => r.data);

// ── Users ─────────────────────────────────────────────────────────────────────

export interface AdminUserListItem {
  id: string;
  fullName: string;
  email: string;
  role: string;
  isActive: boolean;
  isVerified: boolean;
  createdAtUtc: string;
  jobCount: number;
}

export interface AdminReviewSummary {
  id: string;
  jobId: number;
  reviewerName: string;
  rating: number;
  comment?: string;
  createdAtUtc: string;
}

export interface AdminJobSummary {
  id: number;
  title: string;
  category: string;
  status: string;
  homeownerName: string;
  tradeName?: string;
  createdAtUtc: string;
  updatedAtUtc: string;
}

export interface AdminUserDetail extends AdminUserListItem {
  tradeType?: string;
  businessName?: string;
  averageRating: number;
  reviewCount: number;
  recentJobs: AdminJobSummary[];
  recentReviews: AdminReviewSummary[];
}

export interface UserListParams {
  search?: string;
  role?: string;
  isActive?: boolean;
  page?: number;
  pageSize?: number;
  sortBy?: string;
  sortDesc?: boolean;
}

export const fetchUsers = (params: UserListParams = {}): Promise<PagedResult<AdminUserListItem>> =>
  api.get('/admin/users', { params }).then((r) => r.data);

export const fetchUserDetail = (id: string): Promise<AdminUserDetail> =>
  api.get(`/admin/users/${id}`).then((r) => r.data);

export const verifyUser = (id: string): Promise<void> =>
  api.post(`/admin/users/${id}/verify`).then(() => undefined);

export const deactivateUser = (id: string): Promise<void> =>
  api.post(`/admin/users/${id}/deactivate`).then(() => undefined);

// ── Jobs ──────────────────────────────────────────────────────────────────────

export interface AdminChatMessage {
  id: number;
  senderName: string;
  senderId: string;
  content: string;
  sentAtUtc: string;
  readAtUtc?: string;
}

export interface AdminStatusHistory {
  id: number;
  fromStatus: string;
  toStatus: string;
  changedByUserId: string;
  changedByName?: string;
  changedAtUtc: string;
  reason?: string;
}

export interface JobPhoto {
  id: number;
  url: string;
  originalFileName?: string;
}

export interface AdminJobDetail extends AdminJobSummary {
  homeownerId: string;
  matchedTradieId?: string;
  description: string;
  urgency: string;
  address?: string;
  scheduledDateUtc?: string;
  scheduleStatus: string;
  photos: JobPhoto[];
  chatTranscript: AdminChatMessage[];
  statusHistory: AdminStatusHistory[];
}

export interface JobListParams {
  status?: string;
  search?: string;
  page?: number;
  pageSize?: number;
  sortBy?: string;
  sortDesc?: boolean;
}

export const fetchJobs = (params: JobListParams = {}): Promise<PagedResult<AdminJobSummary>> =>
  api.get('/admin/jobs', { params }).then((r) => r.data);

export const fetchJobDetail = (id: number): Promise<AdminJobDetail> =>
  api.get(`/admin/jobs/${id}`).then((r) => r.data);

// ── Disputes ──────────────────────────────────────────────────────────────────

export interface AdminDisputeListItem {
  jobId: number;
  jobTitle: string;
  homeownerName: string;
  tradieName?: string;
  status: string;
  disputeStatus: string;
  flagReason?: string;
  flaggedAtUtc: string;
}

export interface AdminDisputeDetail extends AdminDisputeListItem {
  chatTranscript: AdminChatMessage[];
  homeownerDetail?: AdminUserDetail;
  tradieDetail?: AdminUserDetail;
}

export interface ResolveDisputeRequest {
  action: string;
  note?: string;
}

export const fetchDisputes = (params: {
  disputeStatus?: string;
  page?: number;
  pageSize?: number;
}): Promise<PagedResult<AdminDisputeListItem>> =>
  api.get('/admin/disputes', { params }).then((r) => r.data);

export const fetchDisputeDetail = (jobId: number): Promise<AdminDisputeDetail> =>
  api.get(`/admin/disputes/${jobId}`).then((r) => r.data);

export const resolveDispute = (jobId: number, body: ResolveDisputeRequest): Promise<void> =>
  api.post(`/admin/disputes/${jobId}/resolve`, body).then(() => undefined);

// ── Settings ──────────────────────────────────────────────────────────────────

export interface AdminSettings {
  currency: string;
  currencySymbol: string;
  timezone: string;
  phoneFormat: string;
  defaultMatchRadiusKm: number;
  featureChatEnabled: boolean;
  featureReviewsEnabled: boolean;
  featureSchedulingEnabled: boolean;
}

export const fetchSettings = (): Promise<AdminSettings> =>
  api.get('/admin/settings').then((r) => r.data);

export const updateSettings = (body: AdminSettings): Promise<AdminSettings> =>
  api.put('/admin/settings', body).then((r) => r.data);
