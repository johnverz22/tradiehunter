import React, { useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Banner } from '../../../components/Banner';
import { Button } from '../../../components/Button';
import { Field } from '../../../components/Field';
import { useQuoteSettings, useUpdateQuoteSettings } from '../hooks/useQuoteSettings';

const hours = (label: string) =>
  z
    .number({ invalid_type_error: `${label} must be a number` })
    .int('Whole hours only')
    .min(1, 'Minimum 1 hour')
    .max(720, 'Maximum 720 hours (30 days)');

const schema = z.object({
  boardWindowHours: hours('Board window'),
  validityHours: hours('Quote validity'),
});

type QuoteForm = z.infer<typeof schema>;

/** Plan 10 (Q7.2): how long open projects take quotes, and how long a quote stays valid. */
export const QuoteSettingsCard: React.FC = () => {
  const { data, isLoading, isError } = useQuoteSettings();
  const update = useUpdateQuoteSettings();

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isDirty },
  } = useForm<QuoteForm>({ resolver: zodResolver(schema), defaultValues: data });

  useEffect(() => {
    if (data) reset(data);
  }, [data, reset]);

  const onSubmit = async (values: QuoteForm) => {
    await update.mutateAsync(values);
    reset(values);
  };

  return (
    <section className="card" aria-labelledby="quote-settings-title">
      <div className="card-head">
        <h2 id="quote-settings-title">Quotes</h2>
      </div>
      <div className="card-body">
        {isLoading && (
          <p className="muted" role="status" aria-busy="true">
            Loading quote settings…
          </p>
        )}
        {isError && <Banner variant="error">Could not load quote settings.</Banner>}
        {update.isSuccess && !isDirty && <Banner variant="success">Quote settings saved.</Banner>}
        {update.isError && (
          <Banner variant="error">
            Failed to save quote settings. Only a Superadmin can change them.
          </Banner>
        )}
        {data && (
          <form onSubmit={handleSubmit(onSubmit)} className="stack" noValidate>
            <div className="grid c2">
              <Field
                label="Board window (hours)"
                error={errors.boardWindowHours?.message}
                help="How long a new open project accepts quotes. Applies to jobs posted after the change."
              >
                {(a11y) => (
                  <input
                    {...a11y}
                    className="field"
                    type="number"
                    inputMode="numeric"
                    {...register('boardWindowHours', { valueAsNumber: true })}
                  />
                )}
              </Field>
              <Field
                label="Quote validity (hours)"
                error={errors.validityHours?.message}
                help="How long a submitted quote stays valid. Applies to quotes submitted after the change."
              >
                {(a11y) => (
                  <input
                    {...a11y}
                    className="field"
                    type="number"
                    inputMode="numeric"
                    {...register('validityHours', { valueAsNumber: true })}
                  />
                )}
              </Field>
            </div>
            <div>
              <Button type="submit" kind="accent" disabled={!isDirty} loading={update.isPending}>
                {update.isPending ? 'Saving…' : 'Save quote settings'}
              </Button>
            </div>
          </form>
        )}
      </div>
    </section>
  );
};
