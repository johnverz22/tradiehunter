import React, { useEffect, useId } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { PageHeader } from '../../../components/PageHeader';
import { Banner } from '../../../components/Banner';
import { Button } from '../../../components/Button';
import { Field } from '../../../components/Field';
import { useSettings, useUpdateSettings } from '../hooks/useSettings';
import type { AdminSettings } from '../../../services/adminApi';
import { QuoteSettingsCard } from '../components/QuoteSettingsCard';

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
    return (
      <>
        <PageHeader title="Settings" description="Platform-wide locale and feature configuration." />
        <p className="muted" role="status" aria-busy="true">
          Loading settings…
        </p>
      </>
    );

  return (
    <>
      <PageHeader
        title="Settings"
        description="Platform-wide locale and feature configuration."
        actions={
          <Button
            type="submit"
            form="settings-form"
            kind="accent"
            disabled={!isDirty}
            loading={updateMutation.isPending}
          >
            {updateMutation.isPending ? 'Saving…' : 'Save changes'}
          </Button>
        }
      />

      {updateMutation.isSuccess && (
        <Banner variant="success">Settings saved successfully.</Banner>
      )}

      {updateMutation.isError && (
        <Banner variant="error">Failed to save settings. Please try again.</Banner>
      )}

      <form id="settings-form" onSubmit={handleSubmit(onSubmit)} className="stack">
        {/* Locale */}
        <section className="card">
          <div className="card-head">
            <h2>Locale &amp; region</h2>
          </div>
          <div className="card-body">
            <div className="grid c2">
              <Field label="Currency code" error={errors.currency?.message}>
                {(a11y) => (
                  <input {...a11y} className="field" placeholder="NZD" {...register('currency')} />
                )}
              </Field>
              <Field label="Currency symbol" error={errors.currencySymbol?.message}>
                {(a11y) => (
                  <input
                    {...a11y}
                    className="field"
                    placeholder="$"
                    {...register('currencySymbol')}
                  />
                )}
              </Field>
            </div>

            <Field
              label="Timezone"
              error={errors.timezone?.message}
              help="IANA timezone name, e.g. Pacific/Auckland, Australia/Sydney"
            >
              {(a11y) => (
                <input
                  {...a11y}
                  className="field"
                  placeholder="Pacific/Auckland"
                  {...register('timezone')}
                />
              )}
            </Field>

            <Field label="Phone format / country code" error={errors.phoneFormat?.message}>
              {(a11y) => (
                <input {...a11y} className="field" placeholder="+64" {...register('phoneFormat')} />
              )}
            </Field>
          </div>
        </section>

        {/* Matching */}
        <section className="card">
          <div className="card-head">
            <h2>Matching</h2>
          </div>
          <div className="card-body">
            <Field
              label="Default match radius (km)"
              error={errors.defaultMatchRadiusKm?.message}
            >
              {(a11y) => (
                <input
                  {...a11y}
                  className="field"
                  type="number"
                  placeholder="25"
                  {...register('defaultMatchRadiusKm', { valueAsNumber: true })}
                />
              )}
            </Field>
          </div>
        </section>

        {/* Feature flags */}
        <section className="card">
          <div className="card-head">
            <h2>Feature flags</h2>
          </div>
          <div className="card-body">
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
          </div>
        </section>
      </form>

      {/* Quotes (own form and endpoint, plan 10 Q7.2) */}
      <div style={{ marginTop: 'var(--sp-4)' }}>
        <QuoteSettingsCard />
      </div>
    </>
  );
};

// ── Toggle row ─────────────────────────────────────────────────────────────────

interface ToggleFieldProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
  description: string;
}

const ToggleField = React.forwardRef<HTMLInputElement, ToggleFieldProps>(
  ({ label, description, ...props }, ref) => {
    const descId = useId();
    return (
      <label className="choice">
        <input
          ref={ref}
          type="checkbox"
          role="switch"
          className="switch"
          aria-describedby={descId}
          {...props}
        />
        <span className="stack" style={{ gap: 'var(--sp-1)' }}>
          <span className="t-title">{label}</span>
          <span className="t-meta c-soft" id={descId}>
            {description}
          </span>
        </span>
      </label>
    );
  },
);
ToggleField.displayName = 'ToggleField';
