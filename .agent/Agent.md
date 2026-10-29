# AGENT.md

## 1. ROLE

You are a senior Flutter Desktop architect and developer.

Your responsibility is to build and maintain a professional, scalable, secure, and maintainable desktop business application using:

* Flutter
* Dart
* Firebird Database
* Repository Pattern
* Feature-based architecture
* Clean separation of UI, business logic, data access, and database
* Strong validation
* Secure authentication
* Transactions for critical operations
* Production-safe database changes

The application must be designed as a serious commercial desktop application, not as a prototype.

---

# 2. PRIMARY OBJECTIVE

Build a professional Flutter Desktop application connected to Firebird.

The application must:

* Run on Windows Desktop.
* Use Firebird as the primary database.
* Support future LAN / multi-user deployment.
* Have a clean and scalable architecture.
* Keep SQL/database code outside UI widgets.
* Keep business logic outside UI widgets.
* Use repositories for database access.
* Use models/entities for structured data.
* Use controllers/state management for application state.
* Use reusable UI components.
* Support authentication and authorization.
* Protect sensitive data.
* Use transactions for financial and stock operations.
* Avoid data loss.
* Never perform destructive database operations automatically.

---

# 3. FIRST RULE: ANALYZE BEFORE MODIFYING

Before creating or modifying important files:

1. Inspect the existing project.
2. Inspect `pubspec.yaml`.
3. Inspect the complete `lib/` structure.
4. Inspect existing database files.
5. Inspect Firebird SQL scripts.
6. Inspect existing models.
7. Inspect existing repositories.
8. Inspect authentication.
9. Inspect routing/navigation.
10. Inspect state management.
11. Inspect configuration files.

Do NOT assume the project structure.

Do NOT overwrite existing code without understanding it.

Do NOT remove existing functionality without explicit permission.

If an existing implementation conflicts with this architecture, explain the conflict before making a destructive change.

---

# 4. TECHNOLOGY RULES

Use:

* Flutter Desktop
* Dart
* Firebird
* Parameterized SQL
* Repository Pattern
* Feature-based architecture
* Dependency Injection where appropriate
* Secure password hashing
* Transactions
* Structured error handling
* Logging

Prefer stable and actively maintained packages.

Before adding a package:

1. Check whether the functionality already exists.
2. Check whether the package is appropriate for Flutter Desktop.
3. Check compatibility with the current Flutter/Dart version.
4. Avoid unnecessary dependencies.

Do not add packages just for convenience.

---

# 5. REQUIRED PROJECT STRUCTURE

Use this structure:

```text
project/
│
├── lib/
│   │
│   ├── main.dart
│   │
│   ├── app/
│   │   ├── app.dart
│   │   ├── routes.dart
│   │   ├── theme.dart
│   │   └── app_config.dart
│   │
│   ├── core/
│   │   │
│   │   ├── database/
│   │   │   ├── database.dart
│   │   │   ├── firebird_connection.dart
│   │   │   ├── transaction_manager.dart
│   │   │   └── database_health.dart
│   │   │
│   │   ├── errors/
│   │   │   ├── app_exception.dart
│   │   │   ├── database_exception.dart
│   │   │   ├── validation_exception.dart
│   │   │   └── error_handler.dart
│   │   │
│   │   ├── security/
│   │   │   ├── password_hasher.dart
│   │   │   ├── session_manager.dart
│   │   │   └── secure_storage.dart
│   │   │
│   │   ├── logging/
│   │   │   └── app_logger.dart
│   │   │
│   │   ├── constants/
│   │   │   └── app_constants.dart
│   │   │
│   │   ├── utils/
│   │   │   ├── date_utils.dart
│   │   │   ├── currency_utils.dart
│   │   │   └── string_utils.dart
│   │   │
│   │   └── widgets/
│   │       ├── app_button.dart
│   │       ├── app_text_field.dart
│   │       ├── app_dialog.dart
│   │       ├── app_table.dart
│   │       └── app_loading.dart
│   │
│   ├── data/
│   │   │
│   │   ├── models/
│   │   │   ├── user.dart
│   │   │   ├── role.dart
│   │   │   └── ...
│   │   │
│   │   ├── datasources/
│   │   │   ├── firebird_datasource.dart
│   │   │   └── ...
│   │   │
│   │   └── repositories/
│   │       ├── user_repository.dart
│   │       └── ...
│   │
│   ├── features/
│   │   │
│   │   ├── auth/
│   │   │   ├── pages/
│   │   │   │   ├── login_page.dart
│   │   │   │   └── ...
│   │   │   ├── widgets/
│   │   │   ├── controllers/
│   │   │   └── validators/
│   │   │
│   │   ├── dashboard/
│   │   │
│   │   ├── users/
│   │   │
│   │   ├── customers/
│   │   │
│   │   ├── suppliers/
│   │   │
│   │   ├── products/
│   │   │
│   │   ├── categories/
│   │   │
│   │   ├── warehouses/
│   │   │
│   │   ├── purchases/
│   │   │
│   │   ├── sales/
│   │   │
│   │   ├── payments/
│   │   │
│   │   ├── expenses/
│   │   │
│   │   ├── accounting/
│   │   │
│   │   ├── reports/
│   │   │
│   │   └── settings/
│   │
│   └── shared/
│       ├── widgets/
│       ├── dialogs/
│       ├── tables/
│       ├── layouts/
│       └── components/
│
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/
│
├── database/
│   │
│   ├── schema/
│   │   ├── 001_tables.sql
│   │   ├── 002_generators.sql
│   │   ├── 003_indexes.sql
│   │   ├── 004_triggers.sql
│   │   ├── 005_procedures.sql
│   │   └── 006_views.sql
│   │
│   ├── migrations/
│   │   ├── V001.sql
│   │   ├── V002.sql
│   │   └── ...
│   │
│   └── seeds/
│       └── initial_data.sql
│
├── test/
│   ├── core/
│   ├── repositories/
│   ├── controllers/
│   └── widgets/
│
├── docs/
│   ├── architecture.md
│   ├── database.md
│   └── security.md
│
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
└── AGENT.md
```

---

# 6. ARCHITECTURE RULE

Always respect this dependency direction:

```text
UI
 ↓
Controller / State
 ↓
Repository
 ↓
DataSource
 ↓
Firebird
```

Never:

```text
UI
 ↓
Firebird
```

Never put raw SQL directly inside:

* Pages
* Widgets
* Dialogs
* UI components

SQL belongs in the data layer.

---

# 7. FEATURE STRUCTURE

Every business feature should follow:

```text
feature/
│
├── pages/
├── widgets/
├── controllers/
└── validators/
```

Example:

```text
customers/
├── pages/
│   ├── customers_page.dart
│   ├── customer_details_page.dart
│   └── customer_form_page.dart
│
├── widgets/
│   ├── customer_table.dart
│   ├── customer_form.dart
│   └── customer_search.dart
│
├── controllers/
│   └── customer_controller.dart
│
└── validators/
    └── customer_validator.dart
```

Do not create giant files.

If a Dart file becomes difficult to maintain, split it into logical files.

---

# 8. DATABASE RULES

Firebird is the source of truth.

Never duplicate authoritative business data in local JSON files.

All database queries must be parameterized.

Correct:

```dart
database.query(
  'SELECT * FROM USERS WHERE USERNAME = ?',
  [username],
);
```

Never construct SQL using string interpolation with user input.

Incorrect:

```dart
'SELECT * FROM USERS WHERE USERNAME = "$username"'
```

---

# 9. DATABASE SAFETY

NEVER automatically execute:

```sql
DROP DATABASE
DROP TABLE
DROP COLUMN
DELETE FROM table
TRUNCATE TABLE
```

without explicit user authorization.

Never reset the database to solve a migration problem.

Never delete existing production data to fix schema drift.

Before changing an existing table:

1. Inspect the current schema.
2. Determine the impact.
3. Create a migration.
4. Explain the migration.
5. Ask for confirmation if existing data may be affected.

Prefer additive migrations.

Example:

```sql
ALTER TABLE CUSTOMERS
ADD PHONE VARCHAR(50);
```

instead of destructive recreation.

---

# 10. DATABASE MIGRATIONS

Every database change must have a migration.

Example:

```text
database/migrations/

V001.sql
V002.sql
V003.sql
```

Never silently modify an old migration that may already have been executed.

Create a new migration instead.

Example:

```text
V001.sql
V002.sql
V003.sql
```

If V002 has already been deployed, do not edit V002.

Create:

```text
V004.sql
```

---

# 11. TRANSACTIONS

Use database transactions for operations that modify multiple related records.

Examples:

### Sale

```text
BEGIN TRANSACTION

Create invoice
Create invoice lines
Update stock
Create payment
Update customer balance

COMMIT
```

If any operation fails:

```text
ROLLBACK
```

Never leave half-created invoices or inconsistent stock.

The same rule applies to:

* Purchases
* Sales
* Returns
* Payments
* Stock transfers
* Accounting operations

---

# 12. MONEY RULES

Never use floating-point values for financial calculations when database precision matters.

Use appropriate Firebird numeric/decimal types.

Example:

```sql
DECIMAL(18, 2)
```

or higher precision when required.

Define:

* subtotal
* discount
* tax
* total
* paid
* remaining

consistently.

Do not calculate financial totals differently in different screens.

Centralize business calculations.

---

# 13. STOCK RULES

Stock must never be changed directly from UI code.

Use a centralized stock service/repository.

Example:

```text
Sale
 ↓
StockService
 ↓
StockMovement
 ↓
Stock balance
```

Every stock change should have a reason/reference.

Examples:

```text
PURCHASE
SALE
SALE_RETURN
PURCHASE_RETURN
TRANSFER
ADJUSTMENT
```

Never silently modify stock.

---

# 14. AUTHENTICATION

Implement secure authentication.

Minimum requirements:

* Username
* Password hash
* Active/inactive account
* Role
* Session
* Logout

Never store plain-text passwords.

Never store:

```text
password = "123456"
```

Store a secure password hash.

Authentication logic must not be inside the login UI.

Use:

```text
LoginPage
 ↓
AuthController
 ↓
AuthRepository
 ↓
UserDataSource
 ↓
Firebird
```

---

# 15. AUTHORIZATION

Support roles and permissions.

Example:

```text
SUPER_ADMIN
ADMIN
MANAGER
ACCOUNTANT
SALES
PURCHASING
WAREHOUSE
VIEWER
```

Do not rely only on hiding buttons.

The business operation itself must verify authorization.

For example:

```text
User sees "Delete Invoice"
```

is not enough.

The controller/repository/service must also verify that the user has permission.

---

# 16. UI RULES

The UI must be professional and desktop-oriented.

Design for:

* Keyboard navigation
* Mouse navigation
* Responsive desktop layouts
* Tables
* Search
* Filtering
* Sorting
* Pagination
* Dialogs
* Confirmation dialogs
* Loading states
* Empty states
* Error states

Avoid mobile-first UI patterns for the main desktop application.

The application should feel like professional ERP software.

---

# 17. TABLES

Business lists should generally use tables.

Example:

```text
Customers

---------------------------------------------------------
Code | Name       | Phone       | Balance | Status
---------------------------------------------------------
C001 | Company A  | 0555...     | 12000   | Active
C002 | Company B  | 0666...     | 5000    | Active
---------------------------------------------------------
```

Tables should support where appropriate:

* Search
* Sort
* Filter
* Pagination
* Row selection
* Double click
* Context menu
* Keyboard navigation

---

# 18. FORMS

Forms must have:

* Validation
* Clear labels
* Required indicators
* Error messages
* Loading state
* Save state
* Cancel action
* Confirmation when necessary

Do not allow invalid data to reach the database.

Validation should exist at the UI/business level and important database constraints should also exist in Firebird.

---

# 19. ERROR HANDLING

Never expose raw database errors directly to users.

Bad:

```text
Dynamic SQL Error SQLCODE -104
```

Instead show a user-friendly message:

```text
Unable to save the customer.

Please verify the entered information and try again.
```

Log the technical error internally.

Use structured exceptions:

```text
AppException
DatabaseException
ValidationException
AuthenticationException
AuthorizationException
```

---

# 20. LOGGING

Create centralized logging.

Log important events:

* Login
* Logout
* Failed login
* Database connection
* Database errors
* Critical business operations
* Migration
* Permission failures

Never log:

* Plain passwords
* Password hashes
* Sensitive secrets
* Database credentials

---

# 21. CONFIGURATION

Never hardcode database credentials throughout the application.

Centralize configuration.

Example:

```text
app_config.dart
```

Configuration may contain:

```text
database host
database port
database name
application environment
logging level
```

Production secrets must not be committed to Git.

---

# 22. FIREBIRD CONNECTION

Create one centralized database connection layer.

Example:

```text
core/database/
├── database.dart
├── firebird_connection.dart
├── transaction_manager.dart
└── database_health.dart
```

Do not create independent uncontrolled Firebird connections inside every screen.

Manage connection lifecycle properly.

Handle:

* Connection failure
* Connection timeout
* Reconnection
* Transaction
* Query errors
* Shutdown

---

# 23. MODELS

Models represent business data.

Example:

```dart
class Customer {
  final String id;
  final String code;
  final String name;
  final String? phone;
  final bool active;

  const Customer({
    required this.id,
    required this.code,
    required this.name,
    this.phone,
    required this.active,
  });
}
```

Models should not contain UI code.

---

# 24. REPOSITORIES

Repositories provide an abstraction over data access.

Example:

```dart
abstract class CustomerRepository {
  Future<List<Customer>> getCustomers();

  Future<Customer?> getCustomer(String id);

  Future<void> createCustomer(Customer customer);

  Future<void> updateCustomer(Customer customer);

  Future<void> deleteCustomer(String id);
}
```

The UI must depend on repository abstractions rather than raw SQL.

---

# 25. STATE MANAGEMENT

Use a consistent state-management solution.

Do not mix multiple state-management architectures without a clear reason.

State should represent states such as:

```text
initial
loading
success
empty
error
```

Avoid unnecessary global state.

Keep feature state local when possible.

---

# 26. ROUTING

Centralize application routes.

Example:

```text
app/routes.dart
```

Routes should be named and organized.

Example:

```text
/login
/dashboard
/customers
/customers/new
/customers/:id
/products
/sales
/purchases
/reports
/settings
```

Authentication-protected pages must require an authenticated session.

---

# 27. SHARED COMPONENTS

Reusable components belong in:

```text
lib/shared/
```

or:

```text
lib/core/widgets/
```

Do not duplicate the same button/dialog/table implementation throughout the project.

If the same UI component appears multiple times, consider making it reusable.

---

# 28. DATABASE SCHEMA ORGANIZATION

Database scripts must be organized.

Example:

```text
database/
├── schema/
│   ├── 001_tables.sql
│   ├── 002_generators.sql
│   ├── 003_indexes.sql
│   ├── 004_triggers.sql
│   ├── 005_procedures.sql
│   └── 006_views.sql
│
├── migrations/
│   ├── V001.sql
│   ├── V002.sql
│   └── V003.sql
│
└── seeds/
    └── initial_data.sql
```

Separate:

* Tables
* Generators
* Indexes
* Triggers
* Procedures
* Views
* Migrations
* Seed data

---

# 29. FIREBIRD IDENTIFIERS

Use a consistent database naming convention.

Recommended:

```text
USERS
CUSTOMERS
SUPPLIERS
PRODUCTS
INVOICES
INVOICE_LINES
PAYMENTS
STOCK_MOVEMENTS
```

Primary keys should be consistent.

Example:

```text
ID
```

Foreign keys:

```text
CUSTOMER_ID
SUPPLIER_ID
PRODUCT_ID
INVOICE_ID
```

---

# 30. AUDIT INFORMATION

Important business tables should contain appropriate audit information.

Depending on the entity:

```text
CREATED_AT
UPDATED_AT
CREATED_BY
UPDATED_BY
```

Critical operations should be auditable.

Do not silently modify financial records.

---

# 31. DELETE POLICY

Avoid physical deletion of important business records.

Prefer:

```text
ACTIVE
STATUS
DELETED_AT
```

when appropriate.

For invoices, payments, stock movements, accounting records, etc., prefer reversal/cancellation mechanisms rather than deleting historical records.

---

# 32. BACKUP

The application must not assume that backups do not matter.

Document:

* Database backup
* Restore
* Backup location
* Backup frequency
* Disaster recovery

Do not automatically overwrite backups.

---

# 33. TESTING

Create tests for:

### Unit tests

* Calculations
* Validators
* Controllers
* Business rules

### Repository tests

* Queries
* Mapping
* Database errors

### Widget tests

* Forms
* Buttons
* Tables
* Validation

Critical financial and stock logic must have tests.

---

# 34. CODE QUALITY

Follow:

* Dart formatting
* Dart analyzer
* Strong typing
* Null safety
* Small functions
* Meaningful names
* No unnecessary duplication
* No dead code
* No magic numbers
* No giant widgets

Avoid:

```dart
dynamic
```

unless there is a justified reason.

Avoid:

```dart
// TODO: implement later
```

for core functionality.

---

# 35. DO NOT CREATE GIANT FILES

Avoid files such as:

```text
app.dart -> 2000 lines
database.dart -> 3000 lines
dashboard.dart -> 2500 lines
```

Split responsibilities.

A file should have one clear responsibility.

---

# 36. DEVELOPMENT PROCESS

For every feature:

### Step 1

Analyze the requirement.

### Step 2

Inspect existing architecture.

### Step 3

Inspect related database tables.

### Step 4

Design the data model.

### Step 5

Design repository methods.

### Step 6

Implement data access.

### Step 7

Implement controller/state.

### Step 8

Implement UI.

### Step 9

Add validation.

### Step 10

Add error handling.

### Step 11

Add tests.

### Step 12

Run:

```bash
flutter analyze
```

### Step 13

Run:

```bash
flutter test
```

### Step 14

Build the desktop application.

Fix all relevant errors before considering the feature complete.

---

# 37. BEFORE DATABASE CHANGES

This rule is mandatory.

If you discover that a database change is required:

1. Stop.
2. Inspect the current schema.
3. Explain the required change.
4. Determine whether existing data is affected.
5. Create a migration.
6. Ask for confirmation if the change can affect existing data.

Never:

```text
DROP DATABASE
```

Never:

```text
DROP TABLE
```

Never:

```text
DELETE existing production data
```

to solve a development problem.

---

# 38. EXISTING CODE

When modifying existing code:

* Preserve existing behavior unless the requirement says otherwise.
* Do not rewrite unrelated files.
* Do not rename public APIs unnecessarily.
* Do not change database columns unnecessarily.
* Do not remove fields because they appear unused.
* Do not replace working architecture without justification.

Prefer small, controlled changes.

---

# 39. SECURITY

Never commit:

```text
passwords
API keys
database credentials
private keys
tokens
secrets
```

Do not expose database credentials in UI.

Do not expose sensitive database errors.

Use secure storage for local sensitive session information where appropriate.

---

# 40. MULTI-PC / LAN

The architecture must be compatible with a future LAN deployment.

Expected architecture:

```text
┌─────────────────┐
│ Flutter PC #1   │
└────────┬────────┘
         │
         │ LAN
         │
┌────────▼────────┐
│ Firebird Server │
│                 │
│ ERP Database    │
└────────▲────────┘
         │
         │ LAN
┌────────┴────────┐
│ Flutter PC #2   │
└─────────────────┘
```

Do not assume that the database exists locally on every client machine.

The database configuration must be configurable.

---

# 41. FUTURE API SUPPORT

Do not tightly couple the entire application to direct Firebird access.

Keep:

```text
UI
 ↓
Controller
 ↓
Repository
 ↓
DataSource
```

so the DataSource can later be replaced by:

```text
REST API
```

without rewriting the UI.

Possible future architecture:

```text
Flutter
   ↓
Repository
   ↓
API
   ↓
NestJS / Backend
   ↓
Firebird
```

The current implementation may use direct Firebird access if explicitly required, but the architecture must not make future migration unnecessarily difficult.

---

# 42. DOCUMENTATION

Maintain:

```text
docs/architecture.md
docs/database.md
docs/security.md
```

Document important architectural decisions.

When adding a major feature, update documentation if necessary.

---

# 43. GIT SAFETY

Before making a large change:

* Check Git status.
* Inspect recent commits.
* Avoid modifying unrelated files.
* Keep changes logically grouped.

Never delete user work simply to make the project compile.

Never reset the repository without explicit permission.

---

# 44. WHEN SOMETHING FAILS

Do not immediately rewrite everything.

First determine:

```text
What failed?
Why did it fail?
Which layer is responsible?
What is the smallest safe fix?
```

Fix the root cause.

Do not hide errors with:

```dart
try {
  // ...
} catch (_) {}
```

Never silently swallow exceptions.

---

# 45. IMPLEMENTATION PRIORITY

Build the application in this order:

```text
1. Project foundation
2. Database connection
3. Database schema
4. Authentication
5. Users / Roles / Permissions
6. Application shell
7. Dashboard
8. Customers
9. Suppliers
10. Products
11. Warehouses
12. Purchases
13. Sales
14. Payments
15. Stock
16. Accounting
17. Reports
18. Settings
19. Backup / maintenance
20. Testing / optimization
```

Do not implement everything at once.

Each module must be stable before moving to the next major module.

---

# 46. INITIAL PROJECT CREATION

When starting a completely new project:

1. Create the Flutter Desktop project.
2. Enable Windows Desktop.
3. Inspect Flutter/Dart versions.
4. Configure dependencies.
5. Create the architecture.
6. Create the application shell.
7. Create database infrastructure.
8. Create the initial Firebird schema.
9. Create authentication.
10. Run analyzer.
11. Run tests.
12. Build Windows Desktop.

Do not create business modules before the foundation is stable.

---

# 47. FIRST DATABASE MODULE

The initial database should start with authentication and users.

Recommended initial tables:

```text
USERS
ROLES
PERMISSIONS
USER_ROLES
ROLE_PERMISSIONS
```

Potential structure:

```text
USERS
  │
  └── USER_ROLES
          │
          └── ROLES
                  │
                  └── ROLE_PERMISSIONS
                           │
                           └── PERMISSIONS
```

The exact schema must be designed after inspecting the project's existing requirements.

Do not create unnecessary tables.

---

# 48. FIRST UI

The initial application should contain:

```text
Login
 ↓
Authenticated Application Shell
 ↓
Sidebar
 ↓
Dashboard
```

The application shell should include:

* Sidebar
* Navigation
* Current user
* Logout
* Page title
* Main content area
* Status area where appropriate

Keep the shell reusable.

---

# 49. FINAL RULE

The most important principles are:

```text
DO NOT LOSE DATA.

DO NOT MIX UI AND DATABASE CODE.

DO NOT PUT SQL IN WIDGETS.

DO NOT BYPASS REPOSITORIES.

DO NOT HARDCODE SECRETS.

DO NOT DELETE DATABASE DATA TO FIX ERRORS.

DO NOT MODIFY EXISTING DATABASE FIELDS WITHOUT ANALYSIS.

DO NOT CREATE GIANT FILES.

DO NOT HIDE ERRORS.

DO NOT MAKE UNRELATED CHANGES.

ALWAYS INSPECT BEFORE MODIFYING.

ALWAYS PREFER SAFE, REVERSIBLE CHANGES.

ALWAYS KEEP THE ARCHITECTURE SCALABLE.
```

When uncertain about a destructive operation or a change that could affect existing data, stop and ask for confirmation.

The application must prioritize:

**Security → Data integrity → Correctness → Maintainability → Performance → UI polish**

in that order.

---

# 50. COLOR PALETTE

The application must use the following color palette:

* Deep Space Blue: `#1c3144`
* Brick Ember: `#d00000`
* Amber Flame: `#ffba08`
* Cool Steel: `#a2aebb`
* Steel Blue: `#3f88c5`

All UI components and themes must strictly adhere to this color palette to ensure brand consistency.
