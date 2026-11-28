/**
 * AccountStatusModal — deactivate / reactivate dialog with the required staff note.
 *
 * Shared by the user list and the user detail page so both ask for the same note and report
 * the same email outcome. The note is recorded in the audit log and shown on the user page.
 */
import React, { useState } from 'react';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { Field } from '../../../components/Field';
import { useToast } from '../../../components/toast-context';
import { useDeactivateUser, useReactivateUser } from '../hooks/useUsers';

export type AccountStatusAction = 'deactivate' | 'reactivate';

interface Props {
  action: AccountStatusAction | null;
  user: { id: string; name: string } | null;
  onClose: () => void;
  /** Called after the API call succeeds, before the dialog closes. */
  onDone?: (action: AccountStatusAction) => void;
}

export const AccountStatusModal: React.FC<Props> = ({ action, user, onClose, onDone }) => {
  const [note, setNote] = useState('');
  const [error, setError] = useState<string | null>(null);
  const deactivate = useDeactivateUser();
  const reactivate = useReactivateUser();
  const { toast } = useToast();

  const isDeactivate = action === 'deactivate';
  const busy = deactivate.isPending || reactivate.isPending;

  const close = () => {
    setNote('');
    setError(null);
    onClose();
  };

  const confirm = async () => {
    if (!action || !user) return;
    setError(null);
    try {
      const result =
        action === 'deactivate'
          ? await deactivate.mutateAsync({ id: user.id, reason: note.trim() })
          : await reactivate.mutateAsync({ id: user.id, note: note.trim() });
      toast(
        result.emailSent
          ? {
              tone: 'ok',
              title: action === 'deactivate' ? 'User deactivated' : 'User reactivated',
              text: 'The user was emailed about the change.',
            }
          : {
              tone: 'warn',
              title: action === 'deactivate' ? 'User deactivated' : 'User reactivated',
              text: 'The notification email could not be sent. Contact the user directly.',
            },
      );
      onDone?.(action);
      close();
    } catch {
      setError('Could not complete this action. Check your connection and try again.');
    }
  };

  return (
    <ConfirmModal
      open={action !== null && user !== null}
      title={`${isDeactivate ? 'Deactivate' : 'Reactivate'} ${user?.name ?? ''}?`}
      message={
        isDeactivate
          ? 'They are signed out and cannot log in, and they stop appearing in tradie suggestions. We email them about it. Add a note for the record.'
          : 'They can log in again and, if verified and available, appear in tradie suggestions again. We email them about it. Add a note for the record.'
      }
      confirmLabel={busy ? 'Saving…' : isDeactivate ? 'Deactivate' : 'Reactivate'}
      destructive={isDeactivate}
      confirmDisabled={note.trim().length === 0 || busy}
      onConfirm={confirm}
      onCancel={close}
    >
      <Field
        label="Note"
        help="Required. Saved in the audit log and shown on the user page. It is not included in the email."
        error={error ?? undefined}
      >
        {(a11y) => (
          <textarea
            {...a11y}
            className="textarea"
            rows={3}
            maxLength={500}
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder={isDeactivate ? 'Why is this account being deactivated?' : 'Why is access being restored?'}
            autoFocus
            data-autofocus
          />
        )}
      </Field>
    </ConfirmModal>
  );
};
