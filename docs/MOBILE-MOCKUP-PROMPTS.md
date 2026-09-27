# Fixo Mobile App Mockup Prompts

This file contains structured prompts that can be copy-pasted into an AI tool (Claude, ChatGPT, etc.) to generate self-contained HTML mockups for each of the Fixo MVP mobile screens. 

Each prompt includes the complete design system token values inline so the AI doesn't need external context. The output will be a single HTML file sized to a 375×812 mobile viewport, suitable for viewing in a browser.

---

### Screen 1: Splash Screen

**Role**: All

**Prompt**:

> Generate a single, self-contained HTML file for a mobile app splash screen.
>
> **Design Requirements:**
> - Viewport: 375px wide by 812px high. Wrap the entire design in a container with these exact dimensions, centered on the page with a subtle shadow to look like a phone screen.
> - Fonts (import from Google Fonts): 'Space Grotesk' (display/headings), 'IBM Plex Sans' (body text).
> - Colors: 
>   - Brand 900: hsl(209, 60%, 15%)
>   - Brand 500: hsl(209, 60%, 50%)
>   - Amber (accent): #E38B29
>   - Paper (background): #F6F4EE
>   - Ink (text): #1D2226
> - Spacing: Use a 4px base system (4, 8, 16, 24, 32, 48px).
> - Include dark mode support via `@media (prefers-color-scheme: dark)` where background becomes dark and text becomes light.
>
> **Content & Layout:**
> - Background: A subtle linear gradient using the Brand colors (e.g., Brand 900 to Brand 500).
> - Center of screen: The "Fixo" wordmark. Style the wordmark using Space Grotesk, 700 weight, large size (e.g., 48px), in white or paper color. Add an Amber dot (`.`) at the end of "Fixo".
> - Below the wordmark: The tagline "Get it sorted." in IBM Plex Sans, medium weight, slightly transparent or lighter text.
> - Layout should be flex-based, perfectly centering the content vertically and horizontally.

---

### Screen 2: Onboarding (3 slides)

**Role**: All

**Prompt**:

> Generate a single, self-contained HTML file for a mobile app onboarding carousel screen.
>
> **Design Requirements:**
> - Viewport: 375px wide by 812px high. Wrap the entire design in a container with these exact dimensions, centered on the page with a subtle shadow to look like a phone screen.
> - Fonts (import from Google Fonts): 'Space Grotesk' (display/headings), 'IBM Plex Sans' (body text).
> - Colors: 
>   - Brand 900: hsl(209, 60%, 15%)
>   - Brand 100: hsl(209, 60%, 90%)
>   - Amber (primary CTA): #E38B29
>   - Paper (background): #F6F4EE
>   - Ink (text): #1D2226
> - Radius: 4px.
> - Spacing: Use a 4px base system (4, 8, 16, 24, 32, 48px).
> - Include dark mode support via `@media (prefers-color-scheme: dark)`.
>
> **Content & Layout:**
> - Display the first slide of a 3-slide carousel.
> - Illustration area: A large placeholder block (Brand 100 background with rounded corners) taking up the top 50% of the screen.
> - Heading: "Describe your problem" in Space Grotesk, 700 weight, 24px, Ink color.
> - Body text: "Tell us what needs fixing and we'll connect you with the right local professionals." in IBM Plex Sans, 16px.
> - Below text: Carousel indicators (3 dots). The active dot should be Amber, inactive dots should be light gray or Brand 100.
> - Bottom area: Two buttons side-by-side or stacked. 
>   - Primary button: "Next", background Amber, text white, 4px border radius, bold, 48px height, full width.
>   - Secondary link/button: "Skip", ghost style (no background), Ink text.
> - Layout: Flex column, with generous spacing (24px or 32px) between elements in the bottom half. Include the Fixo wordmark small at the top.

---

### Screen 3: Login / Sign Up

**Role**: All

**Prompt**:

> Generate a single, self-contained HTML file for a mobile app login screen.
>
> **Design Requirements:**
> - Viewport: 375px wide by 812px high, wrapped in a phone-frame div.
> - Fonts: 'Space Grotesk' (headings), 'IBM Plex Sans' (body/inputs) via Google Fonts.
> - Colors: Brand 900 hsl(209, 60%, 15%), Brand 100 hsl(209, 60%, 90%), Amber #E38B29, Paper #F6F4EE, Ink #1D2226.
> - Radius: 4px for all inputs and buttons.
> - Spacing: 4px base system (8, 16, 24, 32px).
> - Dark mode support via CSS media query.
>
> **Content & Layout:**
> - Top: "Fixo." wordmark in Space Grotesk, 700 weight, 32px (with Amber dot).
> - Heading: "Welcome back" (Space Grotesk, 24px).
> - Form fields (IBM Plex Sans):
>   - Email label + input field (placeholder "e.g. kiaora@example.co.nz"). Inputs should have 1px solid border, 48px height, 4px radius.
>   - Password label + input field + "Forgot password?" link aligned right.
> - Main CTA: "Sign in" button (Amber background, white text, 48px height, full width, 4px radius).
> - Divider: "or continue with" text flanked by 1px lines.
> - Social CTA: Google sign-in button (white background, 1px border, centered text with a simple "G" icon placeholder).
> - Bottom footer: "Don't have an account? Create account" link. 
> - Use padding of 24px on the left and right of the screen.

---

### Screen 4: Sign Up

**Role**: All

**Prompt**:

> Generate a single, self-contained HTML file for a mobile app sign-up screen.
>
> **Design Requirements:**
> - Viewport: 375px wide by 812px high, wrapped in a phone-frame div.
> - Fonts: 'Space Grotesk' (headings), 'IBM Plex Sans' (body/inputs) via Google Fonts.
> - Colors: Brand 900 hsl(209, 60%, 15%), Brand 100 hsl(209, 60%, 90%), Amber #E38B29, Paper #F6F4EE, Ink #1D2226.
> - Radius: 4px for all inputs and buttons.
> - Spacing: 4px base system (8, 16, 24, 32px).
> - Dark mode support.
>
> **Content & Layout:**
> - Top header with a subtle back arrow icon.
> - Heading: "Join Fixo." (Space Grotesk, 24px, Amber dot).
> - Role Selector: A segmented control or two large tappable cards side-by-side to choose between "I'm a Homeowner" (selected state: Amber border, light amber bg) and "I'm a Tradie" (unselected state).
> - Form fields (IBM Plex Sans, 48px height, 4px radius, 1px border):
>   - Full Name (placeholder "Jane Doe")
>   - Email (placeholder "jane@example.co.nz")
>   - Password
> - Main CTA: "Create account" button (Amber background, white text, 48px height, full width, 4px radius, bold).
> - Scrollable container if content exceeds 812px height. Padding 24px around the edges.

---

### Screen 5: Homeowner Home

**Role**: Homeowner

**Prompt**:

> Generate a single, self-contained HTML file for a homeowner dashboard/home screen.
>
> **Design Requirements:**
> - Viewport: 375px wide by 812px high, phone-frame wrapper.
> - Fonts: 'Space Grotesk' (headings), 'IBM Plex Sans' (body), 'IBM Plex Mono' (data/reference numbers).
> - Colors: Brand 900 hsl(209, 60%, 15%), Brand 500 hsl(209, 60%, 50%), Amber #E38B29, Green #3A7D5C, Paper #F6F4EE, Ink #1D2226, White #FFFFFF.
> - Radius: 4px for cards and buttons.
> - Dark mode support.
>
> **Content & Layout:**
> - App Bar: "Fixo." wordmark on left, user avatar (circle) on right.
> - Greeting: "Hey Sarah," (Space Grotesk, 24px), "Here are your active jobs."
> - Active Jobs List: Display two job cards.
>   - Card style: White background (or dark gray in dark mode), subtle drop shadow, 4px border radius, 16px padding.
>   - Job 1: "Fix leaking kitchen pipe", Subtitle: "Plumbing • Mt Eden", Status badge (Green bg, white text: "Matched"), small status stepper graphic showing progress (Requested -> Matched -> Confirmed).
>   - Job 2: "Rewire garage lights", Subtitle: "Electrical • Mt Eden", Status badge (Amber bg, white text: "Requested").
> - Empty state (hidden in code but design a small section for it): "No past jobs."
> - Floating Action Button (FAB): Fixed at bottom right. Circular or pill-shaped, Amber background, white text "+ Post a Job", large shadow.
> - Bottom Navigation Bar: Home (active, Brand 500), Messages, Profile icons (inactive, gray).

---

### Screen 6: Post a Job

**Role**: Homeowner

**Prompt**:

> Generate a single, self-contained HTML file for a "Post a Job" screen.
>
> **Design Requirements:**
> - Viewport: 375px wide by 812px high, phone-frame wrapper.
> - Fonts: 'Space Grotesk' (headings), 'IBM Plex Sans' (body).
> - Colors: Brand 500 hsl(209, 60%, 50%), Amber #E38B29, Red #B23A2E, Paper #F6F4EE, Ink #1D2226, Gray borders.
> - Radius: 4px for inputs, 16px or full-rounded for choice chips.
> - Dark mode support.
>
> **Content & Layout:**
> - App Bar: Back button, Title "Post a Job" (Space Grotesk).
> - Scrollable form area (24px padding):
>   - Section 1: "What do you need?" (heading). Choice chips wrapped in a flex layout: "Plumbing", "Electrical", "Painting", "Carpentry" (selected state: Brand 500 bg, white text), "General", "Other".
>   - Section 2: "Describe the issue". Textarea (120px height, 4px radius, 1px border), placeholder: "E.g., The pipe under the kitchen sink is leaking heavily...".
>   - Section 3: "Photos (Optional)". A dashed-border dropzone box with a camera icon and "Tap to add photos".
>   - Section 4: "Urgency". Toggle button or two selectable cards: "Normal (Whenever)" and "Urgent (ASAP)".
>   - Section 5: "Location". Input field with a pin icon, pre-filled with "Grey Lynn, Auckland".
> - Bottom fixed area: "Post Job" button (Amber bg, white text, 48px height, 4px radius, full width). Add a subtle top shadow to this fixed area.

---

### Screen 7: Matching / Searching

**Role**: Homeowner

**Prompt**:

> Generate a single, self-contained HTML file for a loading/matching screen.
>
> **Design Requirements:**
> - Viewport: 375px wide by 812px high, phone-frame wrapper.
> - Fonts: 'Space Grotesk' (headings), 'IBM Plex Sans' (body).
> - Colors: Brand 900 hsl(209, 60%, 15%), Brand 500 hsl(209, 60%, 50%), Brand 100 hsl(209, 60%, 90%), Amber #E38B29, Paper #F6F4EE, Ink #1D2226.
> - Dark mode support.
>
> **Content & Layout:**
> - Full screen layout, centered content, flex-direction column.
> - Main visual: A pulsing radar or expanding ripple animation created with CSS keyframes. Use concentric circles in Brand 100 and Brand 500 colors radiating outwards.
> - Inside the center circle: A subtle magnifying glass or tool icon.
> - Text below animation: "Finding tradies near you..." in Space Grotesk, 24px, Ink color.
> - Subtext: "Plumbing • Urgent • Grey Lynn" in IBM Plex Sans, 14px, gray text.
> - Bottom area (pushed to bottom): A "Cancel" ghost button (no background, Ink text, 4px radius).
> - The entire screen should feel dynamic and calming despite the 'Urgent' status.

---

### Screen 8: Match Result

**Role**: Homeowner

**Prompt**:

> Generate a single, self-contained HTML file for a match result screen.
>
> **Design Requirements:**
> - Viewport: 375px wide by 812px high, phone-frame wrapper.
> - Fonts: 'Space Grotesk' (headings), 'IBM Plex Sans' (body).
> - Colors: Brand 500 hsl(209, 60%, 50%), Amber #E38B29, Green #3A7D5C, Paper #F6F4EE, Ink #1D2226.
> - Radius: 4px.
> - Spacing: 4px base (8, 16, 24px).
> - Dark mode support.
>
> **Content & Layout:**
> - Header: "Match Found!" (Space Grotesk, 28px, Brand 500 color), centered.
> - Tradie Card: Large central card (White bg, 4px radius, shadow).
>   - Top of card: Avatar image placeholder (circular), Name "David Wiremu", Trade "Master Plumber".
>   - Verified Badge: Small tick icon with "Verified" text in Green.
>   - Stats row: Distance "1.2 km away", Star rating "★ 4.9 (124 reviews)".
>   - Bio snippet: "Specializing in emergency leak repairs and general residential plumbing."
> - Actions (below card):
>   - Primary CTA: "Request David" (Amber bg, white text, 48px height, 4px radius, full width, bold).
>   - Secondary CTA: "See More Matches" (Ghost style, Brand 500 text, full width).
> - Confetti or celebratory subtle design elements in the background are optional but a nice touch. Padding around content should be 24px.

---

### Screen 9: Tradie Home (Dashboard)

**Role**: Tradie

**Prompt**:

> Generate a single, self-contained HTML file for a tradie dashboard screen.
>
> **Design Requirements:**
> - Viewport: 375px wide by 812px high, phone-frame wrapper.
> - Fonts: 'Space Grotesk' (headings), 'IBM Plex Sans' (body), 'IBM Plex Mono' (stats).
> - Colors: Brand 900 hsl(209, 60%, 15%), Brand 500 hsl(209, 60%, 50%), Amber #E38B29, Red #B23A2E, Paper #F6F4EE, Ink #1D2226, White #FFFFFF.
> - Radius: 4px.
> - Dark mode support.
>
> **Content & Layout:**
> - App Bar: "Fixo." wordmark, right aligned toggle switch for "Online/Offline" status (currently green/Online).
> - Greeting: "Hey James," (Space Grotesk).
> - Stats Row (flex horizontal, scrolling or grid): 3 small cards showing "Jobs: 42", "Rating: 4.8", "Response: 95%" using IBM Plex Mono for the numbers.
> - Section: "Incoming Requests" (Heading).
>   - Request Card: "Emergency Pipe Burst" (bold), location "Ponsonby (3.5 km)".
>   - Urgency Badge: Red background, white text "URGENT".
>   - Preview image thumbnail of the problem.
>   - Small text: "Requested by Sarah H. • 5 mins ago".
> - Section: "Active Jobs".
>   - Job Card: "Install shower head", "Mt Eden", status "Confirmed".
> - Bottom Navigation Bar: Dashboard (active), Jobs, Messages, Profile.

---

### Screen 10: Incoming Request Detail

**Role**: Tradie

**Prompt**:

> Generate a single, self-contained HTML file for an incoming job request detail screen.
>
> **Design Requirements:**
> - Viewport: 375px wide by 812px high, phone-frame wrapper.
> - Fonts: 'Space Grotesk' (headings), 'IBM Plex Sans' (body).
> - Colors: Brand 500 hsl(209, 60%, 50%), Amber #E38B29, Red #B23A2E, Paper #F6F4EE, Ink #1D2226, Light Gray borders.
> - Radius: 4px.
> - Dark mode support.
>
> **Content & Layout:**
> - Top App Bar: Back button, Title "Job Request".
> - Scroll view:
>   - Map Placeholder Area: A 150px tall gray rectangle with a map pin indicating the rough location (Ponsonby, Auckland).
>   - Header area: "Emergency Pipe Burst" (Space Grotesk, 24px), Red "URGENT" badge.
>   - Details grid: Distance "3.5 km", Client "Sarah H. (★ 5.0)", Posted "10 mins ago".
>   - Description section: "Kitchen sink pipe has burst and water is leaking onto the floor. Need someone ASAP to cap it or fix it."
>   - Photos section: A horizontal scrolling list of 2 placeholder images showing a wet floor and pipes under a sink.
> - Fixed Bottom Area (white bg, top shadow, padding 16px):
>   - Flex row of two buttons.
>   - Left: "Decline" (Ghost button, border, Ink text, 4px radius).
>   - Right: "Accept Job" (Amber background, white text, 4px radius, flex-grow: 2).

---

### Screen 11: Chat + Job Status

**Role**: All

**Prompt**:

> Generate a single, self-contained HTML file for an active job chat screen.
>
> **Design Requirements:**
> - Viewport: 375px wide by 812px high, phone-frame wrapper.
> - Fonts: 'Space Grotesk' (headings), 'IBM Plex Sans' (body).
> - Colors: Brand 900 hsl(209, 60%, 15%), Brand 100 hsl(209, 60%, 90%), Amber #E38B29, Green #3A7D5C, Paper #F6F4EE, Ink #1D2226.
> - Radius: 4px.
> - Dark mode support.
>
> **Content & Layout:**
> - Header: Back arrow, Avatar of the other person, Name "David (Plumber)", phone icon button on the right.
> - Status Stepper (pinned below header): A horizontal progress bar or step indicator showing 4 states: Requested (done), Matched (done), Confirmed (current, highlighted in Green), Complete (pending).
> - Chat Area (scrollable, paper background):
>   - Time separator: "Today 2:14 PM".
>   - Received message bubble (left aligned, Brand 100 background, dark text, 4px radius with top-left corner less rounded): "Kia ora Sarah, I'm about 15 minutes away."
>   - Sent message bubble (right aligned, Brand 900 background, white text, 4px radius with top-right corner less rounded): "Great, see you soon. Driveway is on the left."
> - Message Input Area (fixed at bottom):
>   - Input field (light gray bg, 4px radius) with placeholder "Type a message...".
>   - Send button (Amber colored arrow icon or text next to the input).
>   - Camera/attachment icon button on the left of the input.

---

### Screen 12: Profile (Tradie view)

**Role**: Tradie

**Prompt**:

> Generate a single, self-contained HTML file for a tradie public profile screen.
>
> **Design Requirements:**
> - Viewport: 375px wide by 812px high, phone-frame wrapper.
> - Fonts: 'Space Grotesk' (headings), 'IBM Plex Sans' (body).
> - Colors: Brand 500 hsl(209, 60%, 50%), Amber #E38B29, Green #3A7D5C, Paper #F6F4EE, Ink #1D2226.
> - Radius: 4px.
> - Dark mode support.
>
> **Content & Layout:**
> - Header: Back button, Title "Profile".
> - Profile Top Section (centered):
>   - Large circular avatar placeholder (80x80px).
>   - Name: "David Wiremu" (Space Grotesk, 24px).
>   - Trade: "Master Plumber".
>   - Badges: "Verified" (Green), "Member since 2023".
> - Stats Row: Grid of 3 items. "★ 4.9 (124 reviews)", "150+ Jobs", "100% Response".
> - Edit Button: "Edit Profile" (Ghost button, full width, 4px radius).
> - Reviews Section (below):
>   - Heading: "Recent Reviews".
>   - Review Item 1: Reviewer "Michael T.", Stars (5 Amber stars), Date "2 days ago", Comment "Fast, professional, and sorted the leak in no time. Highly recommend."
>   - Review Item 2: Reviewer "Emma J.", Stars (5 Amber stars), Date "1 week ago", Comment "Great comms and arrived on time."
> - Padding 24px around the layout.

---

### Screen 13: Rating / Review (Modal)

**Role**: Homeowner

**Prompt**:

> Generate a single, self-contained HTML file showing a rating/review modal overlay.
>
> **Design Requirements:**
> - Viewport: 375px wide by 812px high, phone-frame wrapper.
> - Fonts: 'Space Grotesk' (headings), 'IBM Plex Sans' (body).
> - Colors: Brand 900 hsl(209, 60%, 15%), Amber #E38B29, Paper #F6F4EE, Ink #1D2226, backdrop overlay (rgba 0,0,0,0.5).
> - Radius: 4px for elements, maybe 16px for the top corners of the bottom sheet modal.
> - Dark mode support.
>
> **Content & Layout:**
> - Background: The Homeowner dashboard screen, blurred or darkened by a semi-transparent black overlay.
> - Modal Container: A bottom-sheet style modal sliding up from the bottom, taking up the lower 60% of the screen. White/Paper background.
> - Modal Header: "Job Complete!" (Space Grotesk, 24px), centered.
> - Job Summary: "Fix leaking kitchen pipe with David (Plumber)".
> - Rating Input: "How was the service?". Five large outline stars (★), with the first 4 filled in Amber, the last one outline.
> - Comment Input: Textarea placeholder "Write a review... (Optional)", 100px height, 1px border, 4px radius.
> - Actions:
>   - "Submit Review" button (Amber bg, white text, full width, 48px height, 4px radius).
>   - "Skip for now" link (centered text, Ink color, below the submit button).

---

### Screen 14: Settings

**Role**: All

**Prompt**:

> Generate a single, self-contained HTML file for an app settings screen.
>
> **Design Requirements:**
> - Viewport: 375px wide by 812px high, phone-frame wrapper.
> - Fonts: 'Space Grotesk' (headings), 'IBM Plex Sans' (body).
> - Colors: Brand 500 hsl(209, 60%, 50%), Red #B23A2E, Paper #F6F4EE, Ink #1D2226, light gray for dividers.
> - Radius: 4px.
> - Dark mode support.
>
> **Content & Layout:**
> - Header: "Settings" (Space Grotesk, 24px, left aligned).
> - List View Menu (each item should have a label, an optional icon, and a right chevron arrow):
>   - Section Heading: "Account".
>   - Item: "Personal Details"
>   - Item: "Payment Methods"
>   - Section Heading: "Preferences".
>   - Item: "Notifications" (with a toggle switch instead of an arrow)
>   - Item: "Language" (Subtitle: English)
>   - Section Heading: "Support".
>   - Item: "Help Center"
>   - Item: "Terms of Service"
> - Bottom Area:
>   - "Log Out" button (Ghost button, Red text, full width, 4px radius, 48px height).
>   - App Version text "v1.0.0" centered, small, light gray.
> - Layout spacing: 16px padding on items, 1px borders between list items.
