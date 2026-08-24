# MakanSpot Modules and Screen Requirements

## Purpose

This document defines the essential screens required for the MakanSpot Figma mockup and interactive application. Related functions are combined into the same screen where possible to reduce unnecessary navigation, repeated screens, and user overwhelm.

Dialogs, filters, tabs, dropdowns, bottom sheets, and success messages are treated as interface components rather than separate screens.

The application consists of five modules:

1. User Authentication and Profile
2. Smart Food Planner
3. Community Discovery
4. Discovery Journey
5. Administration

---

# Module 1: User Authentication and Profile

## Module Purpose

This module allows users to register, log in, recover their password, and manage their profile.

## Screen 1.1: Login Screen

### What Users Can Do

- Enter their email and password.
- Show or hide their password.
- Log in.
- Navigate to registration.
- Navigate to password recovery.

### Screen Content

- MakanSpot logo.
- Email field.
- Password field.
- Show or hide password icon.
- Login button.
- Forgot Password link.
- Create Account link.

### Validation and System Responses

- Validate that both fields are completed.
- Authenticate the entered credentials.
- Display an error for invalid credentials.
- Maintain the login session after successful authentication.

### App Interaction

- Login → Home and Discovery Screen.
- Create Account → Registration Screen.
- Forgot Password → Forgot Password Screen.

---

## Screen 1.2: Registration Screen

### What Users Can Do

- Create a new account.
- Enter their profile and account information.
- Upload an optional profile picture.
- Submit the registration form.
- Return to Login.

### Screen Content

- Profile picture placeholder.
- Username or display name field.
- Email field.
- Password field.
- Confirm password field.
- Create Account button.
- Login link.

### Validation and System Responses

- Validate required fields.
- Validate the email format.
- Ensure both passwords match.
- Prevent duplicate email registration.
- Display field-level error messages.
- Display a success popup after registration.

### App Interaction

- Create Account → Success popup → Login Screen.
- Login link → Login Screen.

---

## Screen 1.3: Forgot Password Screen

### What Users Can Do

- Enter their registered email.
- Request a password reset link.
- Resend the reset email.
- Return to Login.

### Screen Content

- Instructions.
- Email field.
- Send Reset Link button.
- Back to Login link.
- Email-sent confirmation state.

### Validation and System Responses

- Validate the email field.
- Verify that the account exists.
- Display an error for an invalid or unregistered email.
- Replace the form with a confirmation message after the email is sent.
- Provide a Resend Email action within the same screen.

### App Interaction

- Send Reset Link → Confirmation state on the same screen.
- Back to Login → Login Screen.

---

## Screen 1.4: Create New Password Screen

### What Users Can Do

- Enter a new password.
- Confirm the password.
- Submit the password change.

### Screen Content

- New password field.
- Confirm password field.
- Show or hide password icons.
- Reset Password button.

### Validation and System Responses

- Validate both fields.
- Ensure both passwords match.
- Display an error for invalid input.
- Display a success popup after the password is changed.

### App Interaction

- Reset Password → Success popup → Login Screen.

---

## Screen 1.5: Profile Screen

### What Users Can Do

- View their profile information.
- View their profile title.
- View their community score.
- View achievement previews.
- Open their posts.
- Open their discovery journey.
- Edit their profile.
- Log out.

### Screen Content

- Profile picture.
- Username.
- Email.
- Profile title.
- Community score.
- Badge preview.
- Edit Profile button.
- My Posts option.
- Discovery Journey option.
- Logout option.

### System Behaviour

- Display the user's latest profile information.
- Display their current score, title, and achievements.
- Show a confirmation dialog when Logout is selected.

### App Interaction

- Edit Profile → Edit Profile Screen.
- My Posts → My Posts Screen.
- Discovery Journey → Discovery Journey Screen.
- Badge preview → Achievements and Progress Screen.
- Logout → Confirmation dialog → Login Screen.

---

## Screen 1.6: Edit Profile Screen

### What Users Can Do

- Update their display name.
- Update their personal information.
- Change their profile picture.
- Save or cancel changes.

### Screen Content

- Current profile picture.
- Change Photo action.
- Editable profile fields.
- Save Changes button.
- Cancel button.

### Validation and System Responses

- Validate required fields.
- Preview the selected profile picture.
- Display a success message after saving.
- Display an error if the update fails.

### App Interaction

- Save Changes → Updated Profile Screen.
- Cancel → Profile Screen.

---

# Module 2: Smart Food Planner

## Module Purpose

This module allows users to search for and discover hidden or underrated restaurants using location, cuisine, budget, and personalized recommendations.

## Screen 2.1: Home and Discovery Screen

### What Users Can Do

- Search for restaurants, dishes, or cuisines.
- Select a location.
- Use their current location.
- Filter restaurants by cuisine and budget.
- Generate personalized recommendations.
- Browse nearby restaurants.
- Browse hidden gems.
- Browse recently added restaurants.
- Open restaurant details.

### Screen Content

- Greeting and profile picture.
- Search bar.
- Current or selected location.
- Location filter.
- Cuisine filter.
- Budget filter.
- Recommended for You section.
- Nearby Restaurants section.
- Hidden Gems section.
- Newest Listings section.
- Restaurant cards.
- Bottom navigation bar.

### Filter Options

#### Location

- Current location.
- Manually entered location.
- Previously selected location.

#### Cuisine

Examples may include:

- Malay.
- Chinese.
- Indian.
- Nyonya.
- Western.
- Japanese.
- Korean.
- Street food.
- Desserts.

#### Budget

- Low.
- Medium.
- High.

### Restaurant Card Content

- Restaurant image, when available.
- Restaurant name.
- Cuisine.
- Rating, when available.
- Distance.
- Budget information.
- Hidden-gem or recommendation label.

### System Behaviour

- Search using restaurant names, cuisines, dishes, or keywords.
- Apply location, cuisine, and budget filters.
- Personalize recommendations using available preferences and interaction history.
- Display hidden restaurants obtained from supported data sources.
- Display a clear no-results state when no matching restaurants are found.

### App Interaction

- Submit search → Restaurant Results Screen.
- View all recommendations → Restaurant Results Screen.
- Apply filters → Updated Home content or Restaurant Results Screen.
- Restaurant card → Restaurant Details Screen.

---

## Screen 2.2: Restaurant Results Screen

### Purpose

This reusable screen displays results from searches, recommendations, categories, nearby listings, hidden gems, and recently added restaurants.

### What Users Can Do

- View matching restaurants.
- Change the search keyword.
- Change filters.
- Sort results.
- Open restaurant details.

### Screen Content

- Screen title based on the entry point.
- Search bar.
- Active filter chips.
- Location filter.
- Cuisine filter.
- Budget filter.
- Sort control.
- Number of results.
- Restaurant cards.
- Empty results state.

### Sorting Options

- Popularity.
- Recommendation score.
- Distance.
- Newest listings.

### System Behaviour

- Update results after search, filtering, or sorting.
- Maintain the user's selected criteria.
- Display a no-results message when necessary.

### App Interaction

- Change search or filters → Updated result list.
- Select sorting option → Reordered result list.
- Restaurant card → Restaurant Details Screen.
- Back → Home and Discovery Screen.

---

## Screen 2.3: Restaurant Details Screen

### What Users Can Do

- View available restaurant information.
- View images or videos.
- View the restaurant on an embedded map.
- Open external navigation.
- View community reviews.
- Create a review.
- Open an existing community post.

### Screen Content

- Restaurant cover image.
- Restaurant name.
- Cuisine.
- Address.
- Operating hours.
- Contact information.
- Rating.
- Budget information.
- Description.
- Source platform indicator.
- Embedded map preview.
- Open in Maps button.
- Community review section.
- Write Review button.

### Information Availability

Only information available from the source should be displayed.

Missing information may be labelled:

- Information not available.
- Operating hours unavailable.
- Contact information unavailable.

The interface must not invent missing restaurant information.

### App Interaction

- Open in Maps → External map simulation.
- Write Review → Create Restaurant Review Screen.
- Community review → Community Post Details Screen.
- Back → Previous results or Home screen.

---

# Module 3: Community Discovery

## Module Purpose

This module allows users to share restaurant experiences, interact with community posts, and report inappropriate content.

## Screen 3.1: Community Feed Screen

### What Users Can Do

- Browse community posts.
- Search posts or restaurants.
- Create a restaurant review.
- Like posts.
- Open posts and comments.
- Open another user's profile.
- Report inappropriate posts.

### Screen Content

- Community header.
- Search bar.
- Create Review button.
- Community post cards.
- Post owner information.
- Profile title.
- Restaurant name.
- Review preview.
- Photos or videos.
- Like count.
- Comment count.
- Like button.
- Comment button.
- More Options button.

### System Behaviour

- Retrieve posts or restaurants based on the search keyword.
- Update like and unlike states.
- Display the latest community content.
- Provide reporting through the More Options menu.

### App Interaction

- Create Review → Create Restaurant Review Screen.
- Post card or comments → Community Post Details Screen.
- Like → Updated like state.
- More Options → Report Content dialog.

---

## Screen 3.2: Create Restaurant Review Screen

### What Users Can Do

- Search for and select a restaurant.
- Write a review.
- Upload photos.
- Upload videos.
- Preview uploaded media.
- Submit or cancel the review.

### Screen Content

- Restaurant search and selection field.
- Inline restaurant search results.
- Selected restaurant preview.
- Review text field.
- Add Photo button.
- Add Video button.
- Media preview.
- Post Review button.
- Cancel button.

### Validation and System Responses

- Require a selected restaurant.
- Require the necessary review content.
- Preview selected media.
- Display a success message after submission.
- Automatically record the restaurant in the user's visit history.

### App Interaction

- Search and select restaurant → Restaurant selected on the same screen.
- Add media → Media preview.
- Post Review → Community Post Details Screen.
- Cancel → Previous screen.

---

## Screen 3.3: Community Post Details Screen

### What Users Can Do

- View the complete post.
- View photos or videos.
- Like or unlike the post.
- View all comments and replies.
- Add a comment.
- Reply to a comment.
- Report the post or a comment.
- Open the restaurant details.
- Open the post owner's profile.

### Screen Content

- Post owner information.
- Restaurant information.
- Full review.
- Media gallery.
- Like count and button.
- Comment and reply section.
- Comment input field.
- More Options menu for the post.
- More Options menu for individual comments.

### System Behaviour

- Display comments directly below the post.
- Display replies under their parent comments.
- Update comments and likes after submission.
- Open a reusable reporting dialog for posts or comments.

### App Interaction

- Restaurant name → Restaurant Details Screen.
- Submit comment → Updated comment section.
- Reply → Inline reply field.
- Report post or comment → Report Content dialog.

---

## Screen 3.4: My Posts Screen

### What Users Can Do

- View active posts.
- View archived posts.
- Open a post.
- Edit a post.
- Archive a post.

### Screen Content

- Active and Archived tabs.
- User post cards.
- Edit action.
- Archive action.
- Empty state.

### System Behaviour

- Display active and archived content in separate tabs.
- Open the selected post in normal or editing mode.
- Show an archive confirmation dialog before archiving.

### App Interaction

- Post card → Community Post Details Screen.
- Edit → Edit Post Screen.
- Archive → Confirmation dialog → Updated My Posts Screen.

---

## Screen 3.5: Edit Post Screen

### What Users Can Do

- Edit review text.
- Add or remove media.
- Save changes.
- Cancel editing.

### Screen Content

- Selected restaurant information.
- Existing review text.
- Existing media.
- Add Media action.
- Remove Media action.
- Save Changes button.
- Cancel button.

### System Behaviour

- Validate edited content.
- Display a success message after saving.

### App Interaction

- Save Changes → Updated Community Post Details Screen.
- Cancel → My Posts Screen.

---

## Reusable Component: Report Content Dialog

This is not a standalone screen.

### What Users Can Do

- Report a post or comment.
- Select a report reason.
- Enter additional information.
- Submit or cancel the report.

### Screen Content

- Content type being reported.
- Report reason options.
- Additional information field.
- Submit Report button.
- Cancel button.

### System Behaviour

- Record the report.
- Send it to the administrator moderation queue.
- Display a success message after submission.

---

# Module 4: Discovery Journey

## Module Purpose

This module records the user's restaurant exploration and displays their visits, statistics, map, achievements, score, and profile title.

## Screen 4.1: Discovery Journey Screen

### What Users Can Do

- View their exploration overview.
- View restaurants visited.
- View reviews submitted.
- View cuisines explored.
- View community score.
- View profile title.
- View recent achievements.
- Open visit history.
- Open the exploration map.
- Open detailed achievement progress.

### Screen Content

- Profile summary.
- Current profile title.
- Community score.
- Restaurants Visited card.
- Reviews Submitted card.
- Cuisines Explored card.
- Recent achievements.
- Progress toward the next badge or title.
- Visit History button.
- Exploration Map button.
- View All Progress button.

### System Behaviour

- Calculate statistics from the user's recorded activities.
- Display the latest score, badges, and title.
- Update the journey after a restaurant review is submitted.

### App Interaction

- Visit History → Visit History Screen.
- Exploration Map → Exploration Map Screen.
- View All Progress → Achievements and Progress Screen.

---

## Screen 4.2: Visit History Screen

### What Users Can Do

- View previously visited restaurants.
- Search or filter visit history.
- Open restaurant details.
- Open the review connected to a visit.

### Screen Content

- Search or filter control.
- Visit history list.
- Restaurant image.
- Restaurant name.
- Visit date.
- Related review preview.
- Empty history state.

### System Behaviour

- Add a restaurant after the user submits a review.
- Preserve previous visits and activities.

### App Interaction

- Restaurant → Restaurant Details Screen.
- Review → Community Post Details Screen.

---

## Screen 4.3: Exploration Map Screen

### What Users Can Do

- View visited restaurants on a map.
- Select a restaurant marker.
- Open restaurant details.

### Screen Content

- Interactive map.
- Visited restaurant markers.
- Total visited locations.
- Selected restaurant preview card.

### App Interaction

- Select marker → Restaurant preview.
- Restaurant preview → Restaurant Details Screen.

---

## Screen 4.4: Achievements and Progress Screen

### What Users Can Do

- View their current community score.
- View their current profile title.
- View earned badges.
- View locked badges.
- View achievement requirements.
- View score increases and deductions.
- View progress toward the next title or badge.

### Screen Content

- Community score.
- Current title.
- Next-title progress.
- Earned Badges tab.
- Locked Badges tab.
- Score History tab.
- Badge descriptions.
- Achievement requirements.
- Progress indicators.

### Score-Increasing Activities

- Posting restaurant reviews.
- Sharing community content.
- Daily logins.
- Other approved contributions.

### Score-Deduction Activities

- Confirmed content violations.
- Validated reports.
- Other predefined guideline violations.

### System Behaviour

- Award badges after milestones are reached.
- Calculate the community score.
- Apply deductions after confirmed violations.
- Assign profile titles according to predefined criteria.

---

# Module 5: Administration

## Module Purpose

This module allows administrators to manage users, restaurant information, reported content, and application analytics.

A desktop dashboard layout is recommended for this module.

## Screen 5.1: Administrator Login Screen

### What Administrators Can Do

- Enter administrator credentials.
- Log in to the administration interface.

### Screen Content

- MakanSpot Admin branding.
- Email field.
- Password field.
- Login button.

### System Behaviour

- Authenticate administrator credentials.
- Display an error for invalid credentials.

### App Interaction

- Login → Admin Dashboard.

---

## Screen 5.2: Admin Dashboard

### What Administrators Can Do

- View key system statistics.
- View moderation summaries.
- Navigate to management sections.

### Screen Content

- Sidebar navigation.
- Total Registered Users card.
- Total Restaurants card.
- Total Posts card.
- Total Comments card.
- Pending Reports card.
- Recent activity or moderation summary.

### App Interaction

- Users → User Management Screen.
- Restaurants → Restaurant Management Screen.
- Reports → Content Moderation Screen.

---

## Screen 5.3: User Management Screen

### What Administrators Can Do

- Search and filter users.
- View account information.
- Edit user details.
- Activate or deactivate accounts.

### Screen Content

- Search bar.
- Status filter.
- User table.
- Username.
- Email.
- Community score.
- Account status.
- View or Manage action.

### App Interaction

- Manage User → User Details and Management Screen.

---

## Screen 5.4: User Details and Management Screen

### What Administrators Can Do

- View user information.
- Edit permitted account information.
- View account status.
- Activate or deactivate the account.

### Screen Content

- Profile picture.
- Username.
- Email.
- Profile title.
- Community score.
- Account status.
- Editable account fields.
- Save Changes button.
- Activate or Deactivate button.

### System Behaviour

- Validate account updates.
- Show a confirmation dialog before status changes.
- Display a success or error message after an action.

---

## Screen 5.5: Restaurant Management Screen

### What Administrators Can Do

- Search for restaurants.
- View restaurant records.
- Add a restaurant.
- Open and manage restaurant information.
- Remove restaurant records.

### Screen Content

- Restaurant search bar.
- Restaurant table.
- Restaurant name.
- Address.
- Source platform.
- Rating.
- Add Restaurant button.
- Manage action.

### App Interaction

- Add Restaurant → Restaurant Details and Management Screen in create mode.
- Manage → Restaurant Details and Management Screen.

---

## Screen 5.6: Restaurant Details and Management Screen

### What Administrators Can Do

- View restaurant information.
- Add or edit restaurant details.
- Verify collected information.
- Remove the restaurant record.

### Screen Content

- Restaurant image.
- Restaurant name field.
- Address field.
- Operating hours field.
- Contact field.
- Cuisine field.
- Rating field.
- Source information.
- Verification status.
- Save Changes button.
- Remove Restaurant button.

### System Behaviour

- Validate required information.
- Save updated restaurant details.
- Show a confirmation dialog before removal.
- Display success or error messages.

---

## Screen 5.7: Content Moderation Screen

### What Administrators Can Do

- View reported posts.
- View reported comments.
- Filter reports by status.
- View pending, removed, or dismissed reports.
- Open a report for review.

### Screen Content

- Reported Posts tab.
- Reported Comments tab.
- Status filter.
- Report queue.
- Content preview.
- Content owner.
- Report reason.
- Number of reports.
- Report date.
- Moderation status.
- Review action.

### App Interaction

- Select report → Moderation Details Screen.

---

## Screen 5.8: Moderation Details Screen

### What Administrators Can Do

- View the complete reported post or comment.
- View the related restaurant or post.
- View report reasons.
- Remove inappropriate content.
- Dismiss invalid reports.

### Screen Content

- Content owner.
- Full reported content.
- Related context.
- Uploaded media, when applicable.
- Report reasons.
- Report count.
- Current moderation status.
- Removal reason field.
- Remove Content button.
- Dismiss Report button.

### System Behaviour

- Require a removal reason before removing content.
- Remove confirmed inappropriate content from public view.
- Resolve related reports.
- Record the moderation action.
- Prevent repeated action on already resolved content.
- Show confirmation dialogs before removal or dismissal.

---

# Final Essential Screen Count

## User Application

### Module 1: Authentication and Profile

1. Login Screen
2. Registration Screen
3. Forgot Password Screen
4. Create New Password Screen
5. Profile Screen
6. Edit Profile Screen

### Module 2: Smart Food Planner

7. Home and Discovery Screen
8. Restaurant Results Screen
9. Restaurant Details Screen

### Module 3: Community Discovery

10. Community Feed Screen
11. Create Restaurant Review Screen
12. Community Post Details Screen
13. My Posts Screen
14. Edit Post Screen

### Module 4: Discovery Journey

15. Discovery Journey Screen
16. Visit History Screen
17. Exploration Map Screen
18. Achievements and Progress Screen

## Administrator Interface

19. Administrator Login Screen
20. Admin Dashboard
21. User Management Screen
22. User Details and Management Screen
23. Restaurant Management Screen
24. Restaurant Details and Management Screen
25. Content Moderation Screen
26. Moderation Details Screen

## Reusable Components, Not Separate Screens

- Logout confirmation dialog.
- Archive confirmation dialog.
- Account activation or deactivation dialog.
- Restaurant removal confirmation dialog.
- Report Content dialog.
- Success toast or popup.
- Error message.
- Filter controls.
- Sorting controls.
- Empty state.
- Loading state.
