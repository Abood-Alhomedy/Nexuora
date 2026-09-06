# AI Generation Output Contract

The AI must return JSON.

Required top-level structure:

{
    "status": "success|needs_clarification|error",
    "project_id": 0,
    "analysis": {},
    "questions": [],
    "files": [],
    "validation": {}
}

## status

Possible values:

success

needs_clarification

error

## questions

Must contain dynamically generated questions.

No fixed question list is allowed.

## files

Each generated file must contain:

{
    "path": "...",
    "action": "create|update",
    "content": "..."
}

## validation

Must contain:

{
    "valid": true,
    "errors": []
}