import re

with open('mobile/lib/widgets/fixo_cards.dart', 'r') as f:
    content = f.read()

content = content.replace(
    "static const _labels = ['Requested', 'Matched', 'Confirmed', 'Complete'];",
    "static const _labels = ['Requested', 'Payment', 'Booked', 'In Progress', 'Confirmation', 'Completed'];"
)
content = content.replace("List.generate(4,", "List.generate(6,")

with open('mobile/lib/widgets/fixo_cards.dart', 'w') as f:
    f.write(content)
