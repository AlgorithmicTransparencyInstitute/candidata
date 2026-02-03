# Development Rules

Guidelines and preferences for working on the Candidata project. Read these before starting development work and update as new preferences are established.

---

## Code Style

- Follow Rails conventions and idioms
- Use Tailwind CSS for styling
- Keep controllers thin, models and services handle business logic

## Database

- PostgreSQL is the database
- Use proper foreign keys and indexes
- Prefer `find_or_create_by!` for idempotent imports

## Git & Workflow

- (Add commit conventions, branching strategy as established)

## Testing

- (Add testing preferences as established)

## Preferences

- (User preferences will be added here as they come up in conversation)

## Documentation

- **Help Section Maintenance**: When adding new features, always check and update the public-facing help section (`/help` routes and views) to document the feature for end users. This includes:
  - Data sources and their coverage
  - How data is structured and related
  - Any limitations or known gaps in the data
  - New functionality and how to use it

---

*Last updated: 2026-02-03*
