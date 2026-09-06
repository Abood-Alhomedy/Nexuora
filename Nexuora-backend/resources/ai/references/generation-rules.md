
---

# 6. `resources/ai/references/generation-rules.md`

```markdown
# Backend Generation Rules

## Rule 1

Never generate project-specific code before retrieving the project schema.

## Rule 2

Always use:

ProjectSchemaService::getProjectSchema($projectId)

as the source of project structure.

## Rule 3

Never hardcode project schema in the system prompt.

## Rule 4

Never use a fixed question list.

## Rule 5

Never assume CRUD.

## Rule 6

Never assume authentication.

## Rule 7

Never assume authorization.

## Rule 8

Never assume workflows.

## Rule 9

Never invent database entities.

## Rule 10

Never invent API endpoints.

## Rule 11

Never invent fields.

## Rule 12

Never invent relationships.

## Rule 13

Only generate code required by confirmed requirements.

## Rule 14

Existing Dart code must be preserved unless modification is required.

## Rule 15

All generated code must pass validation.