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
  avgMatchToAwaitingPaymentHours?: number;
  avgPaymentVerificationHours?: number;
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


export interface AccountFlag {
  id: number;
  userId: string;
  type: 'RepeatCanceller' | 'RepeatNoShow' | 'Abuse' | 'Manual';
  counter: number;
  thresholdHit: boolean;
  createdBy?: string;
  createdAtUtc: string;
  note?: string;
  resolved: boolean;
  resolvedAtUtc?: string;
}

export interface AdminUserDetail extends AdminUserListItem {
  flags: AccountFlag[];
  tradeType?: string;
  businessName?: string;
  averageRating: number;
  reviewCount: number;
  recentJobs: AdminJobSummary[];
  recentReviews: AdminReviewSummary[];
}

export interface UserListParams {
  search?: string;
  flaggedOnly?: boolean;
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

export const warnUser = (id: string, reason: string): Promise<void> =>
  api.post(`/admin/users/${id}/warn`, { reason }).then(() => undefined);

export const suspendUser = (id: string, reason: string): Promise<void> =>
  api.post(`/admin/users/${id}/suspend`, { reason }).then(() => undefined);

export const resolveUserFlags = (id: string): Promise<void> =>
  api.post(`/admin/users/${id}/flags/resolve`).then(() => undefined);

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


export interface DisputeEvidence {
  id: number;
  submittedBy: string;
  type: 'Photo' | 'Text' | 'Document';
  fileKey?: string;
  downloadUrl?: string; // for Photo/Document
  textContent?: string; // for Text
  createdAtUtc: string;
}

export interface AdminTimeLog {
  id: number;
  jobId: number;
  tradieUserId: string;
  checkInAtUtc: string;
  checkOutAtUtc?: string;
}

export interface AdminDisputeDetail extends AdminDisputeListItem {
  evidence: DisputeEvidence[];
  timeLogs: AdminTimeLog[];
  chatTranscript: AdminChatMessage[];
  homeownerDetail?: AdminUserDetail;
  tradieDetail?: AdminUserDetail;
}

export interface ResolveDisputeRequest {
  outcome: 'FullRefund' | 'PartialRefund' | 'NoRefund' | 'None';
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

// ── Credential verification (P1-10) ───────────────────────────────────────────

/** `License` | `Insurance` | `Certification` | `Other` — server serializes the enum name. */
export type CredentialType = 'License' | 'Insurance' | 'Certification' | 'Other';

export interface PendingCredential {
  id: number;
  type: CredentialType;
  tradieUserId: string;
  tradieName: string;
  tradieEmail: string;
  tradeType?: string;
  businessName?: string;
  originalFileName: string;
  /** Private-bucket SAS URL; expires 15 minutes after the queue was fetched. */
  downloadUrl: string;
}

export interface ReviewedCredential extends PendingCredential {
  status: 'Approved' | 'Rejected';
  rejectReason?: string;
  reviewedById?: string;
  reviewedAtUtc?: string;
  /** Resulting verification state of the tradie (≥1 approved credential). */
  tradieIsVerified: boolean;
}

export interface CredentialQueueParams {
  page?: number;
  pageSize?: number;
}

export const fetchPendingCredentials = (
  params: CredentialQueueParams = {},
): Promise<PagedResult<PendingCredential>> =>
  api.get('/admin/credentials/pending', { params }).then((r) => r.data);

export interface ReviewCredentialRequest {
  status: 'Approved' | 'Rejected';
  /** Required by the backend when Status is `Rejected`. */
  rejectReason?: string;
}

export const reviewCredential = (
  id: number,
  body: ReviewCredentialRequest,
): Promise<ReviewedCredential> =>
  api.post(`/admin/credentials/${id}/review`, body).then((r) => r.data);

// ── Manual payment queue (P4-08) ──────────────────────────────────────────────

/** Payment state: Pending | Submitted | Verified | Rejected | Expired. */
export type PaymentState = 'Pending' | 'Submitted' | 'Verified' | 'Rejected' | 'Expired';

export interface PendingPayment {
  id: number;
  jobId: number;
  jobTitle: string;
  homeownerName: string;
  homeownerEmail: string;
  amount: number;
  currency: string;
  /** Transfer reference to match against the bank statement. */
  reference: string;
  status: PaymentState;
  method?: string;
  submittedAtUtc?: string;
  /** P10-16: server-computed wait, used for the queue's urgency thresholds. */
  minutesSinceSubmission?: number;
  /** Times staff have already sent this payment back. */
  reUploadCount: number;
  /** Private-container SAS URL for the receipt image; expires 15 minutes after load. */
  receiptUrl: string;
}

/** Shape returned by verify/reject — the homeowner's view of the payment afterwards. */
export interface PaymentResult {
  paymentId: number;
  jobId: number;
  jobStatus: string;
  amount: number;
  currency: string;
  reference: string;
  status: PaymentState;
  rejectReason?: string;
  reUploadCount: number;
  verifiedAtUtc?: string;
}

export interface PaymentQueueParams {
  page?: number;
  pageSize?: number;
}

export const fetchPendingPayments = (
  params: PaymentQueueParams = {},
): Promise<PagedResult<PendingPayment>> =>
  api.get('/admin/payments/pending', { params }).then((r) => r.data);

export const verifyPayment = (id: number): Promise<PaymentResult> =>
  api.post(`/admin/payments/${id}/verify`).then((r) => r.data);

export interface RejectPaymentBody {
  /** Required by the backend, and shown verbatim to the homeowner. */
  reason: string;
}

export const rejectPayment = (id: number, body: RejectPaymentBody): Promise<PaymentResult> =>
  api.post(`/admin/payments/${id}/reject`, body).then((r) => r.data);

// ── Audit log (P8-07) ─────────────────────────────────────────────────────────

export interface AuditLogEntry {
  id: number;
  userId?: string;
  action: string;
  entityType?: string;
  entityId?: string;
  oldValues?: string;
  newValues?: string;
  ipAddress?: string;
  createdAtUtc: string;
}

export interface AuditLogParams {
  fromUtc?: string;
  toUtc?: string;
  action?: string;
  userId?: string;
  page?: number;
  pageSize?: number;
}

export const fetchAuditLogs = (
  params: AuditLogParams = {},
): Promise<PagedResult<AuditLogEntry>> =>
  api.get('/admin/audit-logs', { params }).then((r) => r.data);

// ── Refund queue (P6-04 / P6-05) ─────────────────────────────────────────────

export type RefundStatus = 'None' | 'Pending' | 'Processed';

export interface RefundSummary {
  id: string;
  jobId: number;
  jobTitle: string;
  homeownerName: string;
  homeownerEmail: string;
  paymentId?: number;
  suggestedAmount: number;
  finalAmount: number;
  penalty: number;
  hoursWorked: number;
  hoursWorkedAmount: number;
  status: RefundStatus;
  cancelReasonCode?: string;
  createdAtUtc: string;
  processedAtUtc?: string;
  transferReference?: string;
  /** P8-03: short-lived signed URL for the proof-of-transfer file. */
  proofDownloadUrl?: string;
}

export interface RefundQueueParams {
  page?: number;
  pageSize?: number;
}

export const fetchPendingRefunds = (
  params: RefundQueueParams = {},
): Promise<PagedResult<RefundSummary>> =>
  api.get('/admin/refunds/pending', { params }).then((r) => r.data);

export interface ProcessRefundBody {
  finalAmount: number;
  penalty: number;
  hoursWorked: number;
  transferReference: string;
  /** Optional proof-of-transfer file. */
  proof?: File;
}

export const processRefund = (id: string, body: ProcessRefundBody): Promise<RefundSummary> => {
  const form = new FormData();
  form.append('finalAmount', String(body.finalAmount));
  form.append('penalty', String(body.penalty));
  form.append('hoursWorked', String(body.hoursWorked));
  form.append('transferReference', body.transferReference);
  if (body.proof) form.append('proof', body.proof);
  return api.post(`/admin/refunds/${id}/process`, form, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }).then((r) => r.data);
};

// ── Payout queue (P10-03 / P10-06) ────────────────────────────────────────────

/** Payout state: Pending | Scheduled | Processed | Failed. */
export type PayoutStatus = 'Pending' | 'Scheduled' | 'Processed' | 'Failed';

/** Batch state: Open | Processing | Completed. */
export type PayoutBatchStatus = 'Open' | 'Processing' | 'Completed';

export interface PayoutQueueItem {
  id: string;
  tradieId: string;
  tradieName: string;
  jobId: number;
  jobReferenceCode: string;
  jobTitle: string;
  grossAmount: number;
  commissionPercent: number;
  commissionAmount: number;
  /** Gross minus commission — what the tradie actually receives. */
  netAmount: number;
  status: PayoutStatus;
  payoutBatchId?: string | null;
  bankAccountName?: string | null;
  /** Last four digits only; the full number is never sent to a client. */
  bankAccountLast4?: string | null;
  /** False when the payout was created before the tradie supplied bank details. */
  hasBankDetails: boolean;
  createdAtUtc: string;
  processedAtUtc?: string | null;
  transferReference?: string | null;
}

export interface PayoutBatchSummary {
  id: string;
  periodStartUtc: string;
  periodEndUtc: string;
  totalAmount: number;
  payoutCount: number;
  processedCount: number;
  status: PayoutBatchStatus;
  createdAtUtc: string;
  completedAtUtc?: string | null;
}

export interface PayoutBatchDetail extends PayoutBatchSummary {
  payouts: PayoutQueueItem[];
}

export interface PayoutQueueParams {
  page?: number;
  pageSize?: number;
}

export const fetchPendingPayouts = (
  params: PayoutQueueParams = {},
): Promise<PagedResult<PayoutQueueItem>> =>
  api.get('/admin/payouts/pending', { params }).then((r) => r.data);

export const fetchPayoutBatches = (
  params: PayoutQueueParams = {},
): Promise<PagedResult<PayoutBatchSummary>> =>
  api.get('/admin/payouts/batches', { params }).then((r) => r.data);

export const fetchPayoutBatch = (id: string): Promise<PayoutBatchDetail> =>
  api.get(`/admin/payouts/batches/${id}`).then((r) => r.data);

/** 204 on success — the processed payout leaves the queue. */
export const processPayout = (id: string, transferReference: string): Promise<void> =>
  api.post(`/admin/payouts/${id}/process`, { transferReference }).then((r) => r.data);

export const completePayoutBatch = (id: string): Promise<{ message: string }> =>
  api.post(`/admin/payouts/batches/${id}/complete`).then((r) => r.data);

// ── White-label brand config (P10-15 / P10-28) ───────────────────────────────

export interface BrandConfig {
  appName: string;
  supportEmail: string;
  supportHoursDisplay: string;
}

export interface LocaleConfig {
  defaultCurrency: string;
  currencySymbol: string;
  phoneCountryCode: string;
  defaultTimezone: string;
  distanceUnit: string;
  materialsDisclaimer: string;
  [key: string]: unknown;
}

export interface AppConfig {
  locale: LocaleConfig;
  commissionPercent: number;
  brand: BrandConfig;
}

/**
 * Public (unauthenticated) so the login screen can render the right wordmark —
 * the brand name is not secret and must not be hardcoded per white-label partner.
 */
export const fetchAppConfig = (): Promise<AppConfig> =>
  api.get('/config/locale').then((r) => r.data);
