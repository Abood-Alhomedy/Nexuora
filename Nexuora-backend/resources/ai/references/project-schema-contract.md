# Project Schema Contract

ProjectSchemaService returns a runtime project description.

Example structure:

{
    "project": {
        "id": 123,
        "name": "...",
        "user_id": 10
    },

    "screens": [
        {
            "id": 1,
            "name": "...",
            "data": {}
        }
    ],

    "meta": {
        "screens_count": 1
    }
}

IMPORTANT:

This structure describes the response contract of the schema retrieval
service.

It does NOT define the actual application schema.

The content of:

screens[].data

is dynamic and must be interpreted at runtime.

The AI must never assume a fixed structure for screens[].data.