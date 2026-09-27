import React, { useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Save, CheckCircle } from 'lucide-react';
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
      <div>
        <h1 className="text-xl font-bold text-[var(--ink)]">Settings</h1>
        <p className="text-sm text-[var(--ink-soft)]">Platform-wide locale and feature configuration.</p>
      </div>

      {updateMutation.isSuccess && (
        <div className="flex items-center gap-2 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg px-4 py-3 text-sm text-green-700 dark:text-green-400">
          <CheckCircle size={14} />
          Settings saved successfully.
        </div>
      )}

      {updateMutation.isError && (
        <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg px-4 py-3 text-sm text-[var(--red)]">
          Failed to save settings. Please try again.
        </div>
      )}

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        {/* Locale */}
        <section className="border border-[var(--paper-line)] rounded-lg p-5 space-y-4">
          <h2 className="text-sm font-semibold text-[var(--ink)]">Locale &amp; Region</h2>

          <div className="grid grid-cols-2 gap-4">
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
        <section className="border border-[var(--paper-line)] rounded-lg p-5 space-y-4">
          <h2 className="text-sm font-semibold text-[var(--ink)]">Matching</h2>
          <FormField
            label="Default match radius (km)"
            type="number"
            placeholder="25"
            error={errors.defaultMatchRadiusKm?.message}
            {...register('defaultMatchRadiusKm', { valueAsNumber: true })}
          />
        </section>

        {/* Feature flags */}
        <section className="border border-[var(--paper-line)] rounded-lg p-5 space-y-3">
          <h2 className="text-sm font-semibold text-[var(--ink)]">Feature Flags</h2>
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

        {/* Save */}
        <div className="flex justify-end">
          <button
            type="submit"
            disabled={!isDirty || updateMutation.isPending}
            className="flex items-center gap-2 px-5 py-2.5 text-sm font-medium rounded bg-[var(--brand-500)] text-white hover:bg-[var(--brand-700)] disabled:opacity-50 disabled:cursor-not-allowed transition-colors focus:outline-none focus:ring-2 focus:ring-[var(--brand-500)] focus:ring-offset-2"
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
        className={[
          'w-full px-3 py-2 text-sm border rounded bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:ring-2 focus:ring-[var(--brand-500)]',
          error ? 'border-[var(--red)]' : 'border-[var(--paper-line)]',
        ].join(' ')}
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
    <label className="flex items-center justify-between gap-4 cursor-pointer">
      <div>
        <p className="text-sm font-medium text-[var(--ink)]">{label}</p>
        <p className="text-xs text-[var(--ink-soft)]">{description}</p>
      </div>
      <input
        ref={ref}
        type="checkbox"
        className="w-4 h-4 accent-[var(--brand-500)] cursor-pointer"
        {...props}
      />
    </label>
  ),
);
ToggleField.displayName = 'ToggleField';
