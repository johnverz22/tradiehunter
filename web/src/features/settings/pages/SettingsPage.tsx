import React, { useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Save } from 'lucide-react';
import { PageHeader } from '../../../components/PageHeader';
import { Banner } from '../../../components/Banner';
import { useSettings, useUpdateSettings } from '../hooks/useSettings';
import type { AdminSettings } from '../../../services/adminApi';

const schema = z.object({
  currency: z.string().min(1, 'Currency is required').max(10),
  currencySymbol: z.string().min(1, 'Symbol is required').max(5),
  timezone: z.string().min(1, 'Timezone is required'),
  phoneFormat: z.string().min(1, 'Phone format is required'),
  defaultMatchRadiusKm: z
    .number({ invalid_type_error: 'Must be a number' })
    .min(1, 'Minimum 1 km')
    .max(500, 'Maximum 500 km'),
  featureChatEnabled: z.boolean(),
  featureReviewsEnabled: z.boolean(),
  featureSchedulingEnabled: z.boolean(),
});

type SettingsForm = z.infer<typeof schema>;

export const SettingsPage: React.FC = () => {
  const { data: settings, isLoading } = useSettings();
  const updateMutation = useUpdateSettings();

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isDirty },
  } = useForm<SettingsForm>({
    resolver: zodResolver(schema),
    defaultValues: settings,
  });

  // Populate form once settings load
  useEffect(() => {
    if (settings) reset(settings);
  }, [settings, reset]);

  const onSubmit = async (data: SettingsForm) => {
    await updateMutation.mutateAsync(data as AdminSettings);
    reset(data); // clear isDirty after successful save
  };

  if (isLoading)
    return <div className="text-[var(--ink-soft)] text-sm p-4">Loading settings…</div>;

  return (
    <div className="max-w-2xl space-y-6">
      <PageHeader
        title="Settings"
        description="Platform-wide locale and feature configuration."
      />

      {updateMutation.isSuccess && (
        <Banner variant="success">Settings saved successfully.</Banner>
      )}

      {updateMutation.isError && (
        <Banner variant="error">Failed to save settings. Please try again.</Banner>
      )}

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        {/* Locale */}
        <section className="card space-y-4">
          <h2 className="card-title">Locale &amp; Region</h2>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              label="Currency code"
              placeholder="NZD"
              error={errors.currency?.message}
              {...register('currency')}
            />
            <FormField
              label="Currency symbol"
              placeholder="$"
              error={errors.currencySymbol?.message}
              {...register('currencySymbol')}
            />
          </div>

          <FormField
            label="Timezone"
            placeholder="Pacific/Auckland"
            error={errors.timezone?.message}
            hint="IANA timezone name, e.g. Pacific/Auckland, Australia/Sydney"
            {...register('timezone')}
          />

          <FormField
            label="Phone format / country code"
            placeholder="+64"
            error={errors.phoneFormat?.message}
            {...register('phoneFormat')}
          />
        </section>

        {/* Matching */}
        <section className="card space-y-4">
          <h2 className="card-title">Matching</h2>
          <FormField
            label="Default match radius (km)"
            type="number"
            placeholder="25"
            error={errors.defaultMatchRadiusKm?.message}
            {...register('defaultMatchRadiusKm', { valueAsNumber: true })}
          />
        </section>

        {/* Feature flags */}
        <section className="card space-y-2">
          <h2 className="card-title">Feature Flags</h2>
          <ToggleField
            label="Chat"
            description="Enable in-app chat for jobs"
            {...register('featureChatEnabled')}
          />
          <ToggleField
            label="Reviews"
            description="Enable post-job reviews"
            {...register('featureReviewsEnabled')}
          />
          <ToggleField
            label="Scheduling"
            description="Enable appointment scheduling"
            {...register('featureSchedulingEnabled')}
          />
        </section>

        {/* Save button - sticky footer on mobile, standard flex on desktop */}
        <div
          className="sticky bottom-0 sm:static bg-[var(--paper)] sm:bg-transparent py-3 sm:py-0 -mx-4 sm:mx-0 px-4 sm:px-0 border-t sm:border-t-0 border-[var(--paper-line)] flex justify-end z-10"
          style={{ paddingBottom: 'max(var(--safe-bottom), 12px)' }}
        >
          <button
            type="submit"
            disabled={!isDirty || updateMutation.isPending}
            className="btn btn-primary w-full sm:w-auto justify-center min-h-[44px]"
          >
            <Save size={14} />
            {updateMutation.isPending ? 'Saving…' : 'Save Settings'}
          </button>
        </div>
      </form>
    </div>
  );
};

// ── Dumb field components ──────────────────────────────────────────────────────

interface FormFieldProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
  hint?: string;
}

const FormField = React.forwardRef<HTMLInputElement, FormFieldProps>(
  ({ label, error, hint, ...props }, ref) => (
    <div>
      <label className="block text-sm font-medium text-[var(--ink)] mb-1">{label}</label>
      <input
        ref={ref}
        className={error ? 'field field-invalid' : 'field'}
        {...props}
      />
      {hint && !error && <p className="text-xs text-[var(--ink-soft)] mt-1">{hint}</p>}
      {error && <p className="text-xs text-[var(--red)] mt-1">{error}</p>}
    </div>
  ),
);
FormField.displayName = 'FormField';

interface ToggleFieldProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
  description: string;
}

const ToggleField = React.forwardRef<HTMLInputElement, ToggleFieldProps>(
  ({ label, description, ...props }, ref) => (
    <label className="flex items-center justify-between gap-4 cursor-pointer py-2 px-1 rounded hover:bg-[var(--paper)] transition-colors min-h-[44px]">
      <div>
        <p className="text-sm font-medium text-[var(--ink)]">{label}</p>
        <p className="text-xs text-[var(--ink-soft)]">{description}</p>
      </div>
      <input
        ref={ref}
        type="checkbox"
        className="w-5 h-5 accent-[var(--brand-500)] cursor-pointer shrink-0"
        {...props}
      />
    </label>
  ),
);
ToggleField.displayName = 'ToggleField';
