// Component sheet: every web component in its states, rendered by the same emitter as the screens.
import { stack, row, grid, card, text as T, btn, ibtn, badge, status, avatar, field, search, select, choice, seg, tabs, chips, drop, banner, toast, empty, skeleton, stat, dl, stepper, timeline, table, pager, modal, menu, money, mono, tile, STATUS } from './dsl.mjs';

const kinds = ['accent', 'primary', 'secondary', 'ghost', 'danger', 'dangerOutline'];
const cap = (s) => s.replace(/([A-Z])/g, ' $1').replace(/^./, (c) => c.toUpperCase());
export const sheet = [
  { id: 'buttons', title: 'Buttons', note: 'One gold (accent) commit action per view or dialog. Navy primary for other filled actions, secondary for neutral, danger only for destructive.', nodes: [
    row({}, ...kinds.map((k) => btn(cap(k), k))),
    row({}, btn('Small', 'primary', { sz: 'sm' }), btn('Default', 'primary'), btn('Large', 'primary', { sz: 'lg' }), btn('With icon', 'secondary', { ic: 'plus' }), ibtn('bell', 'Notifications', 'secondary'), ibtn('x', 'Close', 'ghost')),
    row({}, btn('Disabled', 'primary', { disabled: true }), btn('Disabled', 'accent', { disabled: true }), btn('Saving', 'accent', { loading: true })),
  ] },
  { id: 'fields', title: 'Form controls', note: 'Label above, help below. Errors say what went wrong and how to fix it. Optional is marked, required is the default.', nodes: [
    grid({ cols: 3 },
      field('Default', '', { ph: 'Placeholder text' }), field('Filled', 'staff@tradiehunter.co.nz', { ic: 'mail' }), field('Focused', 'Mere Tane', { focus: true }),
      field('Invalid', 'mere@', { ic: 'mail', err: 'Enter a full email address, like name@example.co.nz.' }), field('Disabled', 'Locked by superadmin', { disabled: true }), field('With help', '', { ph: '0.00', help: 'NZD, incl. GST.' }),
      field('Select', 'All statuses', { kind: 'select' }), field('Optional note', '', { kind: 'textarea', opt: true, ph: 'Add context for the audit log.' }), stack({ gap: 8 }, choice('check', 'Checkbox', true), choice('check', 'Unchecked', false), choice('radio', 'Radio selected', true), choice('switch', 'Switch on', true), choice('switch', 'Switch off', false))),
    row({}, search('Search'), seg(['Day', 'Week', 'Month'], 1), chips([{ v: 'All', on: true }, { v: 'Needs action' }, { v: 'Overdue' }])),
    tabs(['Open', 'Escalated', 'Resolved'], 0),
    drop('up', 'Drop a file or choose one'),
  ] },
  { id: 'status', title: 'Status badges', note: 'Tone comes from the status map (ast/dsl.mjs STATUS). Text always carries the meaning; the dot is decoration.', nodes: [
    row({}, badge('Neutral'), badge('Info', 'info'), badge('Ok', 'ok'), badge('Warn', 'warn'), badge('Danger', 'danger'), badge('With dot', 'ok', { dot: true }), badge('Large', 'info', { lg: true, dot: true })),
    row({}, ...Object.keys(STATUS).map((s) => status(s))),
  ] },
  { id: 'feedback', title: 'Feedback', note: 'Banners are inline and persistent. Toasts are for short confirmations; errors and warnings stay on screen until dismissed.', nodes: [
    banner('info', 'Heads up', 'Reviews close for editing 24 hours after a job completes.'), banner('ok', 'Payment verified', 'JOB-1042 moved to Booked.'),
    banner('warn', 'Receipt is blurry', 'Ask the homeowner to upload a clearer photo.', { action: btn('Contact homeowner', 'ghost', { sz: 'sm' }) }), banner('danger', 'Could not load payments', 'Check your connection and try again.', { action: btn('Retry', 'secondary', { sz: 'sm' }) }),
    row({ align: 'start' }, toast('ok', 'Saved', 'Settings updated.'), toast('danger', 'Could not verify', 'The server rejected the request.')),
    grid({ cols: 2 }, card({ flush: true }, empty('inbox', 'Nothing to review', 'New receipts will appear here as homeowners upload them.')), card({}, skeleton(4))),
  ] },
  { id: 'data', title: 'Data display', note: 'Tables scroll inside their container. Numbers and money right-align with tabular figures. Row actions are secondary; the page owns the gold action.', nodes: [
    grid({ cols: 3 }, stat('Open disputes', '2', { ic: 'alert', tone: 'danger' }), stat('Payments to verify', '3', { ic: 'wallet' }), stat('Pending verifications', '5', { ic: 'shield', tone: 'warn', hint: 'Needs action', attention: true })),
    table([{ h: 'Tradie', k: 'link' }, { h: 'Job' }, { h: 'Net', k: 'money' }, { h: 'Status', k: 'status' }, { h: 'Actions', k: 'actions', sr: true }],
      [[{ v: 'Aroha Walker', sub: 'Plumber' }, 'JOB-1038', '$432.00', 'Open', [btn('Process', 'primary', { sz: 'sm' })]], [{ v: 'Tane Rewi', sub: 'Electrician' }, 'JOB-1027', '$135.00', 'Resolved', [btn('View', 'secondary', { sz: 'sm' })]]], { caption: 'Table, default density', pager: pager(1, 2, 24, 1, 12) }),
    row({}, avatar('KW', 'sm'), avatar('KW'), avatar('KW', 'lg'), tile('shield'), tile('check', { tone: 'ok' }), tile('alert', { tone: 'danger' })),
    grid({ cols: 2 }, card({ title: 'Description list' }, dl([{ l: 'Rate', v: '$70.00 / hr', money: true }, { l: 'Reference', v: 'FX-4821', mono: true }, { l: 'Status', badge: status('Booked') }, { l: 'Total', v: '$261.00', money: true, total: true }])),
      card({ title: 'Timeline' }, timeline([{ t: '14 Nov, 9:12 am', v: 'Check-in recorded', s: 'done' }, { t: '14 Nov, 8:00 am', v: 'Extra cost requested', meta: 'Awaiting homeowner', s: 'warn' }, { t: '13 Nov, 4:40 pm', v: 'Dispute opened', s: 'danger' }]))),
    card({ title: 'Stepper · normal, then halted' }, stepper([{ v: 'Requested', s: 'done' }, { v: 'Booked', s: 'done' }, { v: 'In progress', s: 'current' }, { v: 'Awaiting confirmation', s: 'todo' }, { v: 'Completed', s: 'todo' }]),
      stepper([{ v: 'Requested', s: 'done' }, { v: 'Booked', s: 'done' }, { v: 'Disputed', sub: 'Escalated', s: 'halt' }])),
  ] },
  { id: 'overlay', title: 'Overlays', note: 'Dialogs trap focus, close on Esc and return focus to the trigger. On phones they become bottom sheets.', nodes: [
    row({ align: 'start' }, modal('Reject payment', [T('The homeowner will be asked to upload a new receipt.', 'bodySm', { tone: 'soft' }), field('Reason', '', { kind: 'textarea', ph: 'What is wrong with this receipt?' })], [btn('Cancel', 'secondary'), btn('Reject payment', 'danger')], { size: 'sm', inline: true }),
      menu([{ v: 'Profile', ic: 'user' }, { v: 'Sign out', ic: 'logout' }])),
  ] },
];
