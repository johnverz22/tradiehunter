with open('docs/specs/v1.2/P0-foundation.md', 'r') as f:
    content = f.read()

content = content.replace(
    '### P0-09',
    'DONE_P009'
).replace(
    '### P0-10',
    'DONE_P010'
)

# Wait, simple replace is easier
content = content.replace('[ ] UI reflects the new linear flow', '[x] UI reflects the new linear flow')
content = content.replace('[ ] Disputed and Cancelled states show appropriate', '[x] Disputed and Cancelled states show appropriate')
content = content.replace('[ ] `JobStatus` enum in Dart updated', '[x] `JobStatus` enum in Dart updated')

content = content.replace('[ ] All 10 new statuses are styled correctly', '[x] All 10 new statuses are styled correctly')
content = content.replace('[ ] TypeScript types are updated', '[x] TypeScript types are updated')

with open('docs/specs/v1.2/P0-foundation.md', 'w') as f:
    f.write(content)
