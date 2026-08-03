# MakanSpot Design System

## 1. Overview

### Design System Name

MakanSpot Modern Mamak Design System

### Purpose

The MakanSpot Design System provides consistent visual and interaction standards for the mobile application and administrator dashboard. It helps the design and development team create reusable interface components and maintain a consistent Malaysian mamak-inspired identity.

### Design Direction

The interface is inspired by Malaysian mamak restaurants through warm colours, cream surfaces, menu-board details, subtle tile patterns, food photography, and friendly local language.

### Design Principles

1. Food content should remain the main visual focus.
2. Interfaces should be simple and easy to navigate.
3. Malaysian elements should be subtle and consistent.
4. Components should be reusable across modules.
5. Text and controls should remain accessible and readable.

---

# 2. Foundations

## 2.1 Colour Palette

| Token | Colour | Hex | Usage |
|---|---|---:|---|
| Primary | Mamak Orange | `#D96C27` | Main buttons, active navigation and selected filters |
| Primary Dark | Burnt Orange | `#A9471B` | Pressed states and strong emphasis |
| Background | Roti Canai Beige | `#F7EBD8` | Main page background |
| Surface | Condensed Milk Cream | `#FFF9EF` | Cards, inputs, dialogs and navigation |
| Border | Soft Flour Beige | `#EAD8BE` | Borders and separators |
| Text Primary | Kopi-O Brown | `#3B2921` | Headings and main body text |
| Text Secondary | Teh Tarik Brown | `#7A4B2A` | Secondary text and icons |
| Text Muted | Muted Cocoa | `#927B6B` | Placeholder and supporting text |
| Highlight | Curry Yellow | `#E5A62F` | Ratings, achievements and pending status |
| Success | Banana Leaf Green | `#52734D` | Success, verified and open status |
| Error | Sambal Red | `#B84232` | Errors and destructive actions |

### Colour Rules

- Beige and cream should form most of the interface.
- Orange should highlight important actions.
- Brown should be used for readable text and supporting icons.
- Green, yellow and red should mainly communicate status.
- Status must not rely on colour alone; labels or icons must also be shown.

---

## 2.2 Typography

### Primary Typeface

**Poppins**

Used for:

- Page titles.
- Section headings.
- Restaurant names.
- Buttons.
- Navigation labels.
- Statistics.

### Secondary Typeface

**Inter**

Used for:

- Body text.
- Restaurant details.
- Community posts.
- Forms.
- Timestamps.
- Administrator tables.

### Type Scale

| Style | Size | Weight | Usage |
|---|---:|---|---|
| Display | 32 px | Bold | Splash screen and major messages |
| Page Title | 24 px | Bold | Main screen titles |
| Section Heading | 20 px | Semi-bold | Content sections |
| Card Title | 16 px | Semi-bold | Restaurant and post titles |
| Body | 14–16 px | Regular | Main content |
| Supporting Text | 12–14 px | Regular | Metadata and descriptions |
| Button | 15–16 px | Semi-bold | Button labels |
| Navigation | 11–12 px | Medium | Bottom navigation |

### Typography Rules

- Body text should not be smaller than 14 px.
- Decorative fonts may only be used for promotional headings.
- Long content must use the secondary typeface.
- Text must have sufficient contrast against the background.

---

## 2.3 Spacing

MakanSpot uses an 8-point spacing system.

| Token | Size | Usage |
|---|---:|---|
| XS | 4 px | Icon and text spacing |
| SM | 8 px | Small internal spacing |
| MD | 16 px | Standard component padding |
| LG | 24 px | Section spacing |
| XL | 32 px | Large content separation |
| XXL | 48 px | Major page separation |

### Layout Rules

- Mobile horizontal padding: 16 px.
- Standard section spacing: 24 px.
- Administrator content padding: 24–32 px.
- Touch targets should be at least 44–48 px.

---

## 2.4 Shape

| Element | Radius |
|---|---:|
| Small controls | 8 px |
| Input fields | 12 px |
| Buttons | 12–16 px |
| Cards | 16 px |
| Images | 16–20 px |
| Dialogs | 20–24 px |
| Filter chips | Fully rounded |

Cards should use cream surfaces, thin beige borders and light shadows.

---

## 2.5 Elevation

| Level | Usage |
|---|---|
| Level 0 | Flat backgrounds and inline sections |
| Level 1 | Cards and statistic containers |
| Level 2 | Bottom navigation, dropdowns and bottom sheets |
| Level 3 | Dialogs and important overlays |

Heavy shadows should be avoided.

---

## 2.6 Iconography

Use rounded outline icons with consistent stroke widths.

Required icon groups:

- Navigation.
- Search and filtering.
- Restaurant information.
- Community interaction.
- Journey and achievements.
- Administration and moderation.

Mamak-inspired icons such as a teh tarik cup, plate, receipt or shop sign may be used for decorative purposes and achievements.

---

## 2.7 Malaysian Visual Identity

The main cultural element is a simplified mamak floor-tile pattern.

### Suitable Use

- Authentication headers.
- Profile headers.
- Journey banners.
- Empty states.
- Achievement cards.
- Promotional banners.

### Restrictions

- Use at low opacity.
- Do not place behind form fields.
- Do not use on every card.
- Do not mix multiple traditional pattern styles.

---

# 3. Components

## 3.1 Buttons

### Primary Button

Used for the main action on a screen.

Examples:

- Login.
- Apply Filters.
- Post Review.
- Save Changes.

Style:

- Orange background.
- Cream text.
- 48–52 px height.
- 12–16 px radius.

States:

- Default.
- Pressed.
- Disabled.
- Loading.

### Secondary Button

Used for supporting actions.

Style:

- Cream background.
- Brown outline.
- Brown text.

### Text Button

Used for low-priority actions and links.

Style:

- Transparent background.
- Orange text.

### Destructive Button

Used for removal, deactivation and reporting actions.

Style:

- Sambal-red background or outline.
- Confirmation required before execution.

---

## 3.2 Input Fields

Required input components:

- Text field.
- Password field.
- Search field.
- Dropdown.
- Multiline review field.
- Media upload field.

States:

- Default.
- Focused.
- Filled.
- Error.
- Disabled.
- Success.

All fields must use visible labels and clear validation messages.

---

## 3.3 Search Bar

Style:

- Cream surface.
- Brown search icon.
- Rounded shape.
- Optional clear icon.

Placeholder example:

“Cari restoran, makanan atau kawasan”

---

## 3.4 Filter Chips

### Unselected

- Cream background.
- Brown border.
- Brown text.

### Selected

- Orange background.
- Cream text.

Examples:

- Near Me.
- Budget.
- Open Now.
- Mamak.
- Street Food.
- Desserts.

---

## 3.5 Restaurant Card

Content:

- Restaurant image.
- Restaurant name.
- Cuisine.
- Distance.
- Budget.
- Rating, when available.
- One or two labels.
- Bookmark action.

Possible labels:

- Hidden Gem.
- Community Favourite.
- Budget Friendly.
- Open Now.
- New Spot.

The food image should remain the main visual focus.

---

## 3.6 Community Post Card

Content:

- User profile.
- Username and title.
- Restaurant name.
- Review preview.
- Image or video.
- Like and comment actions.
- More-options menu.

---

## 3.7 Statistic Card

Used for:

- Restaurants visited.
- Reviews submitted.
- Cuisines explored.
- Community score.
- Administrator statistics.

Content:

- Icon.
- Main value.
- Short label.
- Optional progress information.

---

## 3.8 Achievement Card

Content:

- Badge icon.
- Badge name.
- Description.
- Progress.
- Locked or unlocked state.

Visual inspiration may include plates, table numbers, receipts and mamak signboards.

---

## 3.9 Navigation

### Mobile Bottom Navigation

Items:

1. Home
2. Discover
3. Community
4. Journey
5. Profile

Selected item:

- Orange icon and label.

Unselected item:

- Brown icon and label.

### Administrator Sidebar

Items:

1. Dashboard
2. User Management
3. Restaurant Management
4. Content Moderation
5. Logout

Style:

- Dark-brown background.
- Cream text.
- Orange selected indicator.

---

## 3.10 Dialogs

Dialogs are used for:

- Logout.
- Archive post.
- Account deactivation.
- Restaurant removal.
- Content removal.
- Report dismissal.

Every confirmation dialog must include:

- Clear title.
- Short explanation.
- Confirm action.
- Cancel action.

---

## 3.11 Status Labels

| Status | Colour |
|---|---|
| Open / Active / Verified | Green |
| Pending / Trending | Yellow |
| Hidden Gem / Selected | Orange |
| Removed / Error / Deactivated | Red |
| Closed / Dismissed | Grey |

Every status should include text or an icon.

---

# 4. Patterns

## 4.1 Search and Filter Pattern

The search bar appears at the top of restaurant discovery screens.

Filters appear beneath it as horizontal chips.

Results update after:

- Search submission.
- Filter selection.
- Sort selection.

Active filters remain visible on the results screen.

---

## 4.2 Form Pattern

Forms should:

- Use one clear label per field.
- Show validation near the related field.
- Place the main action at the bottom.
- Preserve entered content after minor errors.
- Use dialogs only for irreversible actions.

---

## 4.3 Feedback Pattern

### Success

Use a toast, snackbar or small popup.

### Error

Show the reason and a recovery action where possible.

### Loading

Use skeleton cards for content lists and a spinner for short actions.

### Empty State

Include:

- Simple mamak-inspired illustration.
- Clear message.
- Suggested next action.

---

## 4.4 Community Interaction Pattern

Community posts support:

- Like.
- Comment.
- Reply.
- Report.
- Open restaurant.
- Open user profile.

Comments and replies appear on the post details screen rather than on separate screens.

---

## 4.5 Destructive Action Pattern

Destructive actions require:

1. User selects the action.
2. System displays confirmation.
3. User confirms.
4. System performs the action.
5. System displays feedback.

---

# 5. Content Guidelines

## Tone

- Friendly.
- Clear.
- Local.
- Encouraging.
- Inclusive.

## Language

The main interface should remain understandable in English, with selected Malay phrases used for personality.

Examples:

- Makan Apa Hari Ini?
- Hidden Gems Sekitar Anda.
- Sedap Dekat Sini.
- Lokasi Kedai.
- Community.

Functional buttons should remain direct:

- Search.
- Apply Filters.
- Write Review.
- Save Changes.
- Report.
- Open in Maps.

---

# 6. Accessibility

- Body text must be at least 14 px.
- Main mobile text should preferably be 16 px.
- Controls should be at least 44–48 px.
- Inputs must have visible labels.
- Errors must explain what went wrong.
- Status must use labels or icons in addition to colour.
- Decorative patterns must not reduce readability.
- Primary content must maintain sufficient contrast.

---

# 7. Responsive Rules

## Mobile Application

- Target frame: approximately 390 × 844 px.
- Single-column layout.
- Horizontal scrolling for filters.
- Bottom navigation.
- Sticky actions where useful.

## Administrator Dashboard

- Target frame: approximately 1440 px wide.
- Fixed sidebar.
- Flexible content area.
- Tables for management screens.
- Multi-column statistic cards.

---

# 8. Figma Library Structure

Create the Figma library using the following pages:

1. Cover and Guidelines
2. Foundations
3. Components
4. Patterns
5. Mobile Screens
6. Administrator Screens
7. App Flows

Each reusable component should include:

- Variants.
- States.
- Naming convention.
- Auto layout.
- Colour styles.
- Text styles.
- Spacing rules.