<?php

namespace App\AI;

use App\Project;
use App\Screen;
use RuntimeException;

class ProjectSchemaService
{
    public function getProjectSchema(int $projectId): array
    {
        $project = Project::find($projectId);

        if (!$project) {
            throw new RuntimeException(
                'Project not found.'
            );
        }

        $screens = Screen::where(
            'project_id',
            $projectId
        )->get();

        return [
            'project' => [
                'id' => $project->id,
                'name' => $project->name,
                'user_id' => $project->user_id,
            ],

            'screens' => $screens->map(
                function ($screen) {

                    return [
                        'id' => $screen->id,
                        'name' => $screen->name,
                        'data' => $this->decodeData(
                            $screen->data
                        ),
                    ];
                }
            )->values()->toArray(),

            'meta' => [
                'screens_count' => $screens->count(),
            ],
        ];
    }

    protected function decodeData($data): mixed
    {
        if (is_array($data)) {
            return $data;
        }

        if (is_string($data)) {

            $decoded = json_decode(
                $data,
                true
            );

            if (
                json_last_error() === JSON_ERROR_NONE
            ) {
                return $decoded;
            }
        }

        return $data;
    }
}