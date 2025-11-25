#!/bin/bash

# GitHub Configuration for Personal Project
GITHUB_USER="DenisTopallaj-UHasselt"
REPO_NAME="temp-project"
PROJECT_NUMBER=2

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}GitHub Issues Creator for Scrum User Stories${NC}"
echo -e "${BLUE}===========================================${NC}\n"

# Check if GitHub CLI is installed
if ! command -v gh &>/dev/null; then
	echo -e "${RED}Error: GitHub CLI (gh) is not installed.${NC}"
	echo "Please install it from: https://cli.github.com/"
	exit 1
fi

# Check authentication
echo -e "${BLUE}Checking GitHub CLI authentication...${NC}"
if ! gh auth status &>/dev/null; then
	echo -e "${RED}Not authenticated. Please run the following command:${NC}"
	echo -e "${GREEN}gh auth login --scopes 'project,repo'${NC}"
	echo ""
	echo "Or refresh your token with:"
	echo -e "${GREEN}gh auth refresh --scopes 'project,repo'${NC}"
	exit 1
fi

echo -e "${BLUE}Checking if project scope is available...${NC}"
# Test if we can access projects
if ! gh api graphql -f query="query { viewer { login } }" &>/dev/null; then
	echo -e "${RED}Error: Cannot access GitHub API. Please re-authenticate with:${NC}"
	echo -e "${GREEN}gh auth refresh --scopes 'project,repo'${NC}"
	exit 1
fi

# Get the project node ID (for personal projects)
echo -e "${BLUE}Fetching project node ID...${NC}"
PROJECT_NODE_ID=$(gh api graphql -f query="
  query {
    user(login: \"$GITHUB_USER\") {
      projectV2(number: $PROJECT_NUMBER) {
        id
      }
    }
  }
" --jq '.data.user.projectV2.id' 2>&1)

if [ -z "$PROJECT_NODE_ID" ] || [[ "$PROJECT_NODE_ID" == *"error"* ]] || [[ "$PROJECT_NODE_ID" == *"null"* ]]; then
	echo -e "${RED}Error: Could not fetch project node ID.${NC}"
	echo "Response: $PROJECT_NODE_ID"
	echo ""
	echo "Please ensure:"
	echo "1. Your username is correct: $GITHUB_USER"
	echo "2. Your project number is correct: $PROJECT_NUMBER"
	echo "3. You have re-authenticated with project scope:"
	echo -e "   ${GREEN}gh auth refresh --scopes 'project,repo'${NC}"
	exit 1
fi

echo -e "${GREEN}Project Node ID: $PROJECT_NODE_ID${NC}\n"

# Function to create labels if they don't exist
create_labels_if_needed() {
	echo -e "${BLUE}Setting up repository labels...${NC}"

	# Define all labels we'll use
	declare -A labels=(
		["backend"]="0052CC"
		["frontend"]="1D76DB"
		["api"]="0E8A16"
		["database"]="D93F0B"
		["authentication"]="FBCA04"
		["todo-management"]="C5DEF5"
		["user-management"]="BFD4F2"
		["blacklist"]="D4C5F9"
		["study-mode"]="FEF2C0"
		["integration"]="F9D0C4"
		["algorithm"]="C2E0C6"
		["automation"]="BFDADC"
		["ui"]="E99695"
		["browser-extension"]="F7C6C7"
		["blocking"]="D73A4A"
		["high-priority"]="B60205"
		["medium-priority"]="D93F0B"
		["low-priority"]="0E8A16"
		["architecture"]="5319E7"
	)

	for label in "${!labels[@]}"; do
		color="${labels[$label]}"
		# Check if label exists
		if ! gh label list --repo "$GITHUB_USER/$REPO_NAME" | grep -q "^$label"; then
			echo "Creating label: $label"
			gh label create "$label" --color "$color" --repo "$GITHUB_USER/$REPO_NAME" 2>/dev/null || true
		fi
	done

	echo -e "${GREEN}Labels setup complete!${NC}\n"
}

# Create labels before creating issues
create_labels_if_needed
# Function to create an issue and add it to the project
create_issue() {
	local title="$1"
	local body="$2"
	local labels="$3"

	echo -e "${BLUE}Creating issue: $title${NC}"

	# Create the issue
	ISSUE_URL=$(gh issue create \
		--repo "$GITHUB_USER/$REPO_NAME" \
		--title "$title" \
		--body "$body" \
		--label "$labels" \
		2>&1)

	if [ $? -ne 0 ]; then
		echo -e "${RED}Failed to create issue: $title${NC}"
		echo "$ISSUE_URL"
		return 1
	fi

	# Extract issue number from URL
	ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -oP '\d+$')

	# Get issue node ID
	ISSUE_NODE_ID=$(gh api graphql -f query="
      query {
        repository(owner: \"$GITHUB_USER\", name: \"$REPO_NAME\") {
          issue(number: $ISSUE_NUMBER) {
            id
          }
        }
      }
    " --jq '.data.repository.issue.id')

	# Add issue to project
	gh api graphql -f query="
      mutation {
        addProjectV2ItemById(input: {projectId: \"$PROJECT_NODE_ID\", contentId: \"$ISSUE_NODE_ID\"}) {
          item {
            id
          }
        }
      }
    " >/dev/null 2>&1

	echo -e "${GREEN}✓ Created and added to project: $ISSUE_URL${NC}\n"
	sleep 1 # Rate limiting protection
}

# ==========================================
# SERVER-SIDE USER STORIES
# ==========================================

echo -e "${BLUE}========== SERVER-SIDE FEATURES ==========${NC}\n"

# Todo Management
create_issue \
	"[Backend] Create Todo API Endpoint" \
	"**As a** user
**I want to** create a todo through the API
**So that** I can add tasks to my planner

## Acceptance Criteria
- [ ] API endpoint accepts todo details (name, description, due date, priority, tags/categories)
- [ ] System validates required fields (task name, due date)
- [ ] System saves the todo to the MySQL database
- [ ] System returns the created todo with generated ID
- [ ] If user chooses automatic planning, system plans the todo using the algorithm
- [ ] System handles conflicts with existing events
- [ ] System supports recurring todos with recurrence pattern

## Technical Notes
- Endpoint: \`POST /api/todos\`
- Validate due date is in the future
- Return appropriate HTTP status codes (201 Created, 400 Bad Request, etc.)

## Related Use Case
Create a Todo (Main scenario + Alternative scenarios)" \
	"backend,api,todo-management,high-priority"

create_issue \
	"[Backend] Retrieve Todos API Endpoint" \
	"**As a** user
**I want to** retrieve my todos through the API
**So that** I can view all my tasks

## Acceptance Criteria
- [ ] API endpoint retrieves all todos for authenticated user
- [ ] System supports filtering by priority, category, date range
- [ ] System supports search by keyword
- [ ] System returns todos sorted by due date or custom preferences
- [ ] System returns appropriate message when no todos exist
- [ ] System handles database connection errors gracefully
- [ ] System can highlight study-related tasks when in study mode

## Technical Notes
- Endpoint: \`GET /api/todos\`
- Support query parameters for filtering and sorting
- Return cached data if database is unavailable

## Related Use Case
Retrieve Todos (Main scenario + Alternative scenarios)" \
	"backend,api,todo-management,high-priority"

create_issue \
	"[Backend] Edit Todo API Endpoint" \
	"**As a** user
**I want to** edit an existing todo through the API
**So that** I can update task details as needed

## Acceptance Criteria
- [ ] API endpoint accepts todo ID and updated fields
- [ ] System validates all updated fields
- [ ] System checks for conflicts if date changed
- [ ] If type changed from manual to automatic, system generates subtasks
- [ ] If type changed from automatic to manual, system deletes future subtasks
- [ ] System reschedules flexible tasks when necessary
- [ ] System saves changes to database

## Technical Notes
- Endpoint: \`PUT /api/todos/:id\` or \`PATCH /api/todos/:id\`
- Support partial updates
- Return updated todo object

## Related Use Case
Editing a Todo (Main scenario + Alternative scenarios)" \
	"backend,api,todo-management,medium-priority"

create_issue \
	"[Backend] Delete Todo API Endpoint" \
	"**As a** user
**I want to** delete todos through the API
**So that** I can remove completed or unwanted tasks

## Acceptance Criteria
- [ ] API endpoint accepts todo ID
- [ ] System validates todo exists and belongs to user
- [ ] System removes todo from database
- [ ] System supports bulk deletion of multiple todos
- [ ] System returns success confirmation
- [ ] System handles cascade deletion of related subtasks

## Technical Notes
- Endpoint: \`DELETE /api/todos/:id\`
- Support soft delete for potential recovery
- Return 204 No Content on success

## Related Use Case
Deleting of Todos (Main scenario + Alternative scenarios)" \
	"backend,api,todo-management,medium-priority"

# Account Management
create_issue \
	"[Backend] User Registration API Endpoint" \
	"**As a** new user
**I want to** create an account through the API
**So that** I can start using the automatic planner

## Acceptance Criteria
- [ ] API endpoint accepts username, email, password
- [ ] System validates username is unique
- [ ] System validates password complexity requirements
- [ ] System validates all required fields are filled
- [ ] System hashes password before storage
- [ ] System creates user record in MySQL database
- [ ] System automatically logs user in after registration
- [ ] System returns user data and authentication token

## Technical Notes
- Endpoint: \`POST /api/auth/register\`
- Use bcrypt or similar for password hashing
- Implement password complexity rules (min length, special chars, etc.)

## Related Use Case
Creating an account (Main scenario + Alternative scenarios)" \
	"backend,api,authentication,high-priority"

create_issue \
	"[Backend] User Login API Endpoint" \
	"**As a** registered user
**I want to** log in through the API
**So that** I can access my planner data

## Acceptance Criteria
- [ ] API endpoint accepts username/email and password
- [ ] System validates credentials against database
- [ ] System returns authentication token on success
- [ ] System returns appropriate error for invalid credentials
- [ ] System creates user session
- [ ] System implements rate limiting for security

## Technical Notes
- Endpoint: \`POST /api/auth/login\`
- Use JWT or session tokens
- Return 401 Unauthorized for invalid credentials

## Related Use Case
User logs in (Main scenario + Alternative scenarios)" \
	"backend,api,authentication,high-priority"

create_issue \
	"[Backend] Password Recovery System" \
	"**As a** user who forgot their password
**I want to** recover my password through email
**So that** I can regain access to my account

## Acceptance Criteria
- [ ] API endpoint initiates password recovery
- [ ] System sends recovery email with unique code
- [ ] Code expires after 10 minutes
- [ ] System validates recovery code
- [ ] System allows password reset with valid code
- [ ] System handles invalid/expired codes appropriately

## Technical Notes
- Endpoints: \`POST /api/auth/forgot-password\` and \`POST /api/auth/reset-password\`
- Store recovery codes securely (hashed)
- Integrate with email service

## Related Use Case
Password recovery (Main scenario + Alternative scenarios)" \
	"backend,api,authentication,medium-priority"

create_issue \
	"[Backend] Edit Account API Endpoint" \
	"**As a** user
**I want to** edit my account details through the API
**So that** I can keep my information up to date

## Acceptance Criteria
- [ ] API endpoint accepts updated account fields
- [ ] System validates email format and username uniqueness
- [ ] System requires all mandatory fields
- [ ] System saves changes to database
- [ ] System returns updated account information
- [ ] System handles concurrent updates

## Technical Notes
- Endpoint: \`PUT /api/account\` or \`PATCH /api/account\`
- Support partial updates
- Validate email before updating

## Related Use Case
Editing Account (Main scenario + Alternative scenarios)" \
	"backend,api,user-management,medium-priority"

create_issue \
	"[Backend] Delete Account API Endpoint" \
	"**As a** user
**I want to** delete my account through the API
**So that** I can remove all my data from the system

## Acceptance Criteria
- [ ] API endpoint requires user authentication
- [ ] System requires confirmation before deletion
- [ ] System deletes user account and all associated data
- [ ] System removes todos, blacklist entries, and preferences
- [ ] System implements cascade deletion
- [ ] System handles cancellation of deletion request

## Technical Notes
- Endpoint: \`DELETE /api/account\`
- Consider soft delete with recovery period
- Ensure GDPR compliance

## Related Use Case
Deleting an account (Main scenario + Alternative scenarios)" \
	"backend,api,user-management,medium-priority"

# Database
create_issue \
	"[Backend] MySQL Database Schema Design" \
	"**As a** developer
**I want to** design the database schema
**So that** all application data can be stored efficiently

## Acceptance Criteria
- [ ] Design users table (id, username, email, password_hash, created_at)
- [ ] Design todos table (id, user_id, title, description, due_date, priority, type, recurrence_pattern)
- [ ] Design blacklist table (id, user_id, url, category, created_at)
- [ ] Design whitelist table (id, user_id, url, blacklist_id)
- [ ] Design calendar_sync table (id, user_id, provider, credentials, sync_enabled)
- [ ] Define foreign key relationships
- [ ] Create indexes for performance
- [ ] Document schema with ER diagram

## Technical Notes
- Use InnoDB engine for transactions
- Implement proper normalization
- Consider partitioning for large tables

## Related Use Case
General database requirements" \
	"backend,database,high-priority,architecture"

# Blacklist Management
create_issue \
	"[Backend] Create Blacklist Entry API Endpoint" \
	"**As a** user
**I want to** add websites to my blacklist through the API
**So that** I can block distracting sites during study mode

## Acceptance Criteria
- [ ] API endpoint accepts URL and category
- [ ] System validates URL format
- [ ] System checks for duplicate entries
- [ ] System saves blacklist entry to database
- [ ] System returns created blacklist entry
- [ ] System handles invalid URL formats

## Technical Notes
- Endpoint: \`POST /api/blacklist\`
- Validate URL using regex
- Support wildcard domains (e.g., *.youtube.com)

## Related Use Case
Creating a Blacklist Link (Main scenario + Alternative scenarios)" \
	"backend,api,blacklist,medium-priority"

create_issue \
	"[Backend] Edit Blacklist Entry API Endpoint" \
	"**As a** user
**I want to** edit blacklist entries through the API
**So that** I can update URL details or categories

## Acceptance Criteria
- [ ] API endpoint accepts blacklist entry ID and updates
- [ ] System validates updated URL format
- [ ] System saves changes to database
- [ ] System returns updated entry
- [ ] System handles invalid URLs

## Technical Notes
- Endpoint: \`PUT /api/blacklist/:id\` or \`PATCH /api/blacklist/:id\`
- Validate URL format
- Return 404 if entry not found

## Related Use Case
Editing a blacklist link (Main scenario + Alternative scenarios)" \
	"backend,api,blacklist,low-priority"

create_issue \
	"[Backend] Delete Blacklist Entry API Endpoint" \
	"**As a** user
**I want to** remove websites from my blacklist through the API
**So that** I can allow access to previously blocked sites

## Acceptance Criteria
- [ ] API endpoint accepts blacklist entry ID
- [ ] System validates entry exists and belongs to user
- [ ] System removes entry from database
- [ ] System supports bulk deletion
- [ ] System prevents deletion during study mode
- [ ] System handles associated whitelist entries

## Technical Notes
- Endpoint: \`DELETE /api/blacklist/:id\`
- Consider cascade deletion for related whitelist entries
- Return 403 Forbidden if in study mode

## Related Use Case
Deleting a blacklist link (Main scenario + Alternative scenarios)" \
	"backend,api,blacklist,low-priority"

create_issue \
	"[Backend] Retrieve Blacklist API Endpoint" \
	"**As a** user
**I want to** retrieve my blacklist through the API
**So that** I can view all blocked websites

## Acceptance Criteria
- [ ] API endpoint retrieves all blacklist entries for user
- [ ] System returns entries with categories
- [ ] System supports filtering by category
- [ ] System includes associated whitelist entries

## Technical Notes
- Endpoint: \`GET /api/blacklist\`
- Support query parameters for filtering
- Return empty array if no entries exist

## Related Use Case
Blacklist management" \
	"backend,api,blacklist,medium-priority"

# External Calendar Sync
create_issue \
	"[Backend] Google Calendar Integration" \
	"**As a** user
**I want to** sync my Google Calendar through the API
**So that** my external events appear in the planner

## Acceptance Criteria
- [ ] API endpoint initiates Google OAuth flow
- [ ] System stores encrypted credentials
- [ ] System retrieves calendar events from Google
- [ ] System synchronizes events with planner
- [ ] System handles authentication failures
- [ ] System handles permission revocation
- [ ] System supports bi-directional sync

## Technical Notes
- Endpoint: \`POST /api/calendar/google/connect\`
- Use Google Calendar API v3
- Implement OAuth 2.0 flow
- Store refresh tokens securely

## Related Use Case
Synchronizing with external agendas (Google Calendar)" \
	"backend,api,integration,medium-priority"

create_issue \
	"[Backend] Generic Calendar Link Synchronization" \
	"**As a** user
**I want to** sync calendar via iCal/CalDAV link
**So that** I can import events from any calendar service

## Acceptance Criteria
- [ ] API endpoint accepts calendar link (iCal/CalDAV URL)
- [ ] System validates link format
- [ ] System retrieves calendar data
- [ ] System parses iCal format
- [ ] System synchronizes events with planner
- [ ] System handles invalid/expired links
- [ ] System handles sync errors gracefully

## Technical Notes
- Endpoint: \`POST /api/calendar/link\`
- Support iCal (.ics) format
- Implement periodic sync schedule

## Related Use Case
Synchronizing with external agendas via link" \
	"backend,api,integration,medium-priority"

# Study Mode / Focus Mode
create_issue \
	"[Backend] Study Mode State Management API" \
	"**As a** user
**I want to** control study mode state through the API
**So that** the system can enforce blocking rules

## Acceptance Criteria
- [ ] API endpoint to activate study mode
- [ ] API endpoint to check study mode status
- [ ] System prevents early deactivation
- [ ] System stores study mode sessions
- [ ] System tracks study mode duration
- [ ] API endpoint returns active blacklist during study mode

## Technical Notes
- Endpoints: \`POST /api/study-mode/start\`, \`GET /api/study-mode/status\`, \`POST /api/study-mode/end\`
- Store session data for analytics
- Return scheduled end time

## Related Use Case
Enter focus mode" \
	"backend,api,study-mode,high-priority"

# ==========================================
# CLIENT-SIDE USER STORIES
# ==========================================

echo -e "${BLUE}========== CLIENT-SIDE FEATURES ==========${NC}\n"

# Todo Display and Management
create_issue \
	"[Frontend] Display Todos in Calendar View" \
	"**As a** user
**I want to** see my todos in a calendar format
**So that** I can visualize my schedule

## Acceptance Criteria
- [ ] UI displays todos in calendar layout
- [ ] Todos are organized by due date
- [ ] UI shows todo priority with visual indicators
- [ ] UI supports different view modes (day, week, month)
- [ ] UI updates when todos are modified
- [ ] UI shows loading state while fetching data
- [ ] UI handles empty state when no todos exist

## Technical Notes
- Use calendar component library (FullCalendar, react-big-calendar, etc.)
- Fetch todos from GET /api/todos endpoint
- Implement responsive design

## Related Use Case
Retrieve Todos, Show todos" \
	"frontend,ui,todo-management,high-priority"

create_issue \
	"[Frontend] Create Todo Form" \
	"**As a** user
**I want to** create todos through the UI
**So that** I can add tasks easily

## Acceptance Criteria
- [ ] UI displays todo creation form
- [ ] Form includes fields: name, description, due date, priority, tags
- [ ] Form validates required fields (name, due date)
- [ ] Form shows error messages for validation failures
- [ ] Form supports automatic planning option
- [ ] Form handles recurring todo setup
- [ ] UI shows success message after creation
- [ ] Form closes and resets after submission

## Technical Notes
- Call POST /api/todos endpoint
- Implement form validation
- Use date picker component
- Show loading spinner during submission

## Related Use Case
Create a Todo" \
	"frontend,ui,todo-management,high-priority"

create_issue \
	"[Frontend] Edit Todo Interface" \
	"**As a** user
**I want to** edit todos through the UI
**So that** I can update task details

## Acceptance Criteria
- [ ] UI displays edit form when todo is selected
- [ ] Form pre-fills with existing todo data
- [ ] Form validates all fields
- [ ] UI shows conflict warnings if date changed
- [ ] UI confirms type changes (manual ↔ automatic)
- [ ] UI displays save button and cancel button
- [ ] UI updates todo list after successful edit

## Technical Notes
- Call PUT /api/todos/:id endpoint
- Handle optimistic updates
- Show confirmation dialog for type changes

## Related Use Case
Editing a Todo" \
	"frontend,ui,todo-management,medium-priority"

create_issue \
	"[Frontend] Delete Todo Confirmation" \
	"**As a** user
**I want to** delete todos with confirmation
**So that** I don't accidentally remove tasks

## Acceptance Criteria
- [ ] UI displays delete button/option for each todo
- [ ] UI shows confirmation dialog before deletion
- [ ] Dialog allows cancellation
- [ ] UI supports bulk deletion with confirmation
- [ ] UI updates todo list after deletion
- [ ] UI shows success message
- [ ] UI handles deletion errors

## Technical Notes
- Call DELETE /api/todos/:id endpoint
- Implement confirmation modal
- Support multiple selection for bulk delete

## Related Use Case
Deleting of Todos" \
	"frontend,ui,todo-management,medium-priority"

create_issue \
	"[Frontend] Todo Filtering System" \
	"**As a** user
**I want to** filter todos by various criteria
**So that** I can focus on specific tasks

## Acceptance Criteria
- [ ] UI displays filter controls
- [ ] Filters include: category, priority, date range, status
- [ ] UI applies filters to todo list
- [ ] UI remembers previous filter selections
- [ ] UI provides clear all filters button
- [ ] UI shows count of filtered results
- [ ] Filters work in combination

## Technical Notes
- Update GET /api/todos call with query parameters
- Store filter state in local storage
- Implement filter dropdown/sidebar

## Related Use Case
Filtering Todo" \
	"frontend,ui,todo-management,medium-priority"

# Account Management UI
create_issue \
	"[Frontend] User Registration Form" \
	"**As a** new user
**I want to** create an account through the UI
**So that** I can start using the application

## Acceptance Criteria
- [ ] UI displays registration form
- [ ] Form includes: username, email, password, confirm password
- [ ] Form validates password complexity in real-time
- [ ] Form checks username availability
- [ ] Form highlights required fields when empty
- [ ] Form shows validation errors
- [ ] UI automatically logs user in after registration
- [ ] UI redirects to dashboard after successful registration

## Technical Notes
- Call POST /api/auth/register endpoint
- Implement client-side validation
- Show password strength indicator

## Related Use Case
Creating an account" \
	"frontend,ui,authentication,high-priority"

create_issue \
	"[Frontend] User Login Form" \
	"**As a** registered user
**I want to** log in through the UI
**So that** I can access my account

## Acceptance Criteria
- [ ] UI displays login form
- [ ] Form includes username/email and password fields
- [ ] Form shows validation errors
- [ ] Form includes \"Forgot Password\" link
- [ ] UI stores authentication token after successful login
- [ ] UI redirects to dashboard after login
- [ ] Form displays error for invalid credentials

## Technical Notes
- Call POST /api/auth/login endpoint
- Store JWT token in secure storage
- Implement remember me functionality

## Related Use Case
User logs in" \
	"frontend,ui,authentication,high-priority"

create_issue \
	"[Frontend] Password Recovery Flow" \
	"**As a** user who forgot their password
**I want to** recover my password through the UI
**So that** I can regain access

## Acceptance Criteria
- [ ] UI displays \"Forgot Password\" form
- [ ] Form requests email address
- [ ] UI displays confirmation message
- [ ] UI shows code input form
- [ ] UI validates recovery code
- [ ] UI displays new password form
- [ ] UI confirms password reset success
- [ ] UI handles expired/invalid codes

## Technical Notes
- Call POST /api/auth/forgot-password and POST /api/auth/reset-password endpoints
- Implement 10-minute timer display
- Show password strength indicator

## Related Use Case
Password recovery" \
	"frontend,ui,authentication,medium-priority"

create_issue \
	"[Frontend] Account Settings Page" \
	"**As a** user
**I want to** view and edit my account settings
**So that** I can manage my profile

## Acceptance Criteria
- [ ] UI displays current account information
- [ ] UI provides edit button to enable editing mode
- [ ] Form validates required fields (email, username)
- [ ] Form highlights invalid fields
- [ ] UI displays save and cancel buttons
- [ ] UI shows success message after save
- [ ] UI reverts changes on cancel
- [ ] UI prevents saving with validation errors

## Technical Notes
- Call PUT /api/account endpoint
- Implement inline editing or modal
- Validate email and username uniqueness

## Related Use Case
Editing Account" \
	"frontend,ui,user-management,medium-priority"

create_issue \
	"[Frontend] Delete Account Confirmation" \
	"**As a** user
**I want to** delete my account through the UI
**So that** I can remove all my data

## Acceptance Criteria
- [ ] UI displays delete account option in settings
- [ ] UI shows warning about permanent deletion
- [ ] UI requires confirmation dialog
- [ ] Dialog explains data loss
- [ ] Dialog requires explicit confirmation (checkbox/button)
- [ ] UI logs user out after deletion
- [ ] UI handles cancellation

## Technical Notes
- Call DELETE /api/account endpoint
- Implement multi-step confirmation
- Show destructive action styling (red)

## Related Use Case
Deleting an account" \
	"frontend,ui,user-management,low-priority"

# Blacklist/Whitelist Management UI
create_issue \
	"[Frontend] Blacklist Management Interface" \
	"**As a** user
**I want to** manage my blacklist through the UI
**So that** I can control which sites to block

## Acceptance Criteria
- [ ] UI displays list of blacklisted URLs with categories
- [ ] UI provides add new entry button
- [ ] UI shows edit option for each entry
- [ ] UI shows delete option for each entry
- [ ] UI validates URL format
- [ ] UI prevents duplicate entries
- [ ] UI organizes entries by category
- [ ] UI prevents modifications during study mode

## Technical Notes
- Call GET /api/blacklist, POST /api/blacklist, DELETE /api/blacklist endpoints
- Implement URL validation
- Use confirmation dialogs for destructive actions

## Related Use Case
Creating a Blacklist Link, Editing a blacklist link, Deleting a blacklist link" \
	"frontend,ui,blacklist,medium-priority"

create_issue \
	"[Frontend] Automatic Blacklist Popup" \
	"**As a** user
**I want to** see a popup when visiting non-blacklisted sites
**So that** I can quickly add them to my blacklist

## Acceptance Criteria
- [ ] Browser extension detects non-blacklisted sites
- [ ] Popup appears with add to blacklist option
- [ ] Popup allows category selection
- [ ] Popup can be dismissed
- [ ] Popup doesn't appear if site already blacklisted
- [ ] Popup saves preference to not show again for specific site

## Technical Notes
- Implement as browser extension feature
- Call POST /api/blacklist endpoint
- Store user preferences locally

## Related Use Case
Generating a Blacklist Link" \
	"frontend,ui,blacklist,browser-extension,medium-priority"

create_issue \
	"[Frontend] Website Blocking and Redirection" \
	"**As a** user in study mode
**I want to** be blocked from accessing blacklisted sites
**So that** I can stay focused on my work

## Acceptance Criteria
- [ ] Browser extension intercepts blacklisted URLs
- [ ] Extension redirects to focus page
- [ ] Focus page displays motivational message
- [ ] Focus page shows blocked URL
- [ ] Focus page links to current tasks
- [ ] Whitelist entries override blacklist
- [ ] Custom redirect URLs are supported
- [ ] Blocking only applies during study mode

## Technical Notes
- Implement as browser extension
- Use webRequest API for interception
- Check study mode status via GET /api/study-mode/status

## Related Use Case
Block/Redirect When Accessing a Blacklisted Website" \
	"frontend,browser-extension,blocking,high-priority"

# Study Mode UI
create_issue \
	"[Frontend] Study Mode Interface" \
	"**As a** user
**I want to** activate study mode through the UI
**So that** I can enable website blocking

## Acceptance Criteria
- [ ] UI displays study mode toggle/button
- [ ] UI shows study mode status (active/inactive)
- [ ] UI displays scheduled end time when active
- [ ] UI prevents early deactivation
- [ ] UI shows countdown timer
- [ ] UI activates blacklist when enabled
- [ ] UI displays motivational messages
- [ ] UI shows which sites are currently blocked

## Technical Notes
- Call POST /api/study-mode/start and GET /api/study-mode/status endpoints
- Implement timer component
- Sync state with browser extension

## Related Use Case
Enter focus mode" \
	"frontend,ui,study-mode,high-priority"

# External Calendar Sync UI
create_issue \
	"[Frontend] Google Calendar Connection Interface" \
	"**As a** user
**I want to** connect my Google Calendar through the UI
**So that** my external events sync with the planner

## Acceptance Criteria
- [ ] UI displays calendar sync section in settings
- [ ] UI provides \"Connect Google Calendar\" button
- [ ] UI initiates OAuth flow in popup
- [ ] UI displays connection status
- [ ] UI shows synced calendar name
- [ ] UI provides disconnect option
- [ ] UI handles authentication failures
- [ ] UI displays last sync time

## Technical Notes
- Call POST /api/calendar/google/connect endpoint
- Implement OAuth popup flow
- Show loading states during authentication

## Related Use Case
Synchronizing with external agendas (Google Calendar)" \
	"frontend,ui,integration,medium-priority"

create_issue \
	"[Frontend] Calendar Link Sync Interface" \
	"**As a** user
**I want to** sync calendar via link through the UI
**So that** I can import events from any calendar service

## Acceptance Criteria
- [ ] UI displays calendar link input field
- [ ] UI validates link format
- [ ] UI initiates sync process
- [ ] UI shows sync status (in progress, success, failed)
- [ ] UI displays error messages for invalid links
- [ ] UI shows list of synced calendars
- [ ] UI provides remove calendar option

## Technical Notes
- Call POST /api/calendar/link endpoint
- Validate iCal URL format
- Show sync progress indicator

## Related Use Case
Synchronizing with external agendas via link" \
	"frontend,ui,integration,medium-priority"

# ==========================================
# ALGORITHM & AUTOMATION
# ==========================================

echo -e "${BLUE}========== ALGORITHM & AUTOMATION ==========${NC}\n"

create_issue \
	"[Algorithm] Automatic Task Planning System" \
	"**As a** user who chooses automatic planning
**I want to** have my tasks automatically scheduled
**So that** I don't have to manually plan everything

## Acceptance Criteria
- [ ] Algorithm considers task due date and duration
- [ ] Algorithm checks for conflicts with existing events
- [ ] Algorithm respects user's available time slots
- [ ] Algorithm distributes tasks evenly
- [ ] Algorithm generates subtasks for large tasks
- [ ] Algorithm handles recurring tasks
- [ ] Algorithm can reschedule flexible tasks
- [ ] Algorithm optimizes for user preferences

## Technical Notes
- Research scheduling algorithms (greedy, constraint satisfaction)
- Consider task priority in scheduling
- Implement as background service
- Store scheduling preferences per user

## Related Use Case
Create a Todo (automatic planning option)" \
	"backend,algorithm,automation,high-priority"

create_issue \
	"[Algorithm] Conflict Detection and Resolution" \
	"**As a** developer
**I want to** detect scheduling conflicts
**So that** users are notified when tasks overlap

## Acceptance Criteria
- [ ] System detects overlapping events
- [ ] System notifies user of conflicts
- [ ] System suggests alternative times
- [ ] System allows manual resolution
- [ ] System reschedules flexible tasks automatically
- [ ] System respects fixed time commitments

## Technical Notes
- Implement interval overlap detection
- Use priority-based conflict resolution
- Provide conflict resolution UI

## Related Use Case
Create a Todo (conflict notification), Editing a Todo (conflict checking)" \
	"backend,algorithm,medium-priority"

#
