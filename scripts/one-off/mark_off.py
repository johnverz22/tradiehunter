import re

with open('docs/specs/v1.2/P0-foundation.md', 'r') as f:
    content = f.read()

# Mark off everything from P0-01 to P0-08
sections = content.split('### P0-')
new_sections = [sections[0]]

for section in sections[1:]:
    num = int(section[:2])
    if num <= 8:
        section = section.replace('[ ]', '[x]')
    new_sections.append('### P0-' + section)

with open('docs/specs/v1.2/P0-foundation.md', 'w') as f:
    f.write(''.join(new_sections))
