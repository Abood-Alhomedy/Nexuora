<?php

/**
 * Validate generated Laravel backend.
 *
 * Usage:
 *
 * php validate_backend.php /path/to/backend
 */

$result = [
    'valid' => true,
    'errors' => [],
];

if ($argc < 2) {

    echo json_encode([
        'valid' => false,
        'errors' => [
            'Usage: php validate_backend.php <backend_path>'
        ],
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);

    exit(1);
}

$backendPath = realpath($argv[1]);

if (!$backendPath || !is_dir($backendPath)) {

    echo json_encode([
        'valid' => false,
        'errors' => [
            'Backend directory not found.'
        ],
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);

    exit(1);
}


/*
|--------------------------------------------------------------------------
| Required Laravel directories
|--------------------------------------------------------------------------
*/

$requiredDirectories = [
    'app',
    'app/Http',
    'app/Http/Controllers',
    'app/Models',
    'routes',
    'config',
];

foreach ($requiredDirectories as $directory) {

    $path = $backendPath . DIRECTORY_SEPARATOR . $directory;

    if (!is_dir($path)) {

        $result['valid'] = false;

        $result['errors'][] =
            "Missing required directory: {$directory}";
    }
}


/*
|--------------------------------------------------------------------------
| Required Laravel files
|--------------------------------------------------------------------------
*/

$requiredFiles = [
    'artisan',
    'composer.json',
    'routes/api.php',
];

foreach ($requiredFiles as $file) {

    $path = $backendPath . DIRECTORY_SEPARATOR . $file;

    if (!is_file($path)) {

        $result['valid'] = false;

        $result['errors'][] =
            "Missing required file: {$file}";
    }
}


/*
|--------------------------------------------------------------------------
| PHP syntax validation
|--------------------------------------------------------------------------
*/

$phpFiles = [];

$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator(
        $backendPath,
        FilesystemIterator::SKIP_DOTS
    )
);

foreach ($iterator as $file) {

    if (!$file->isFile()) {
        continue;
    }

    $path = $file->getPathname();

    if (
        str_ends_with($path, '.php')
    ) {
        $phpFiles[] = $path;
    }
}

foreach ($phpFiles as $file) {

    $output = [];
    $exitCode = 0;

    exec(
        'php -l ' . escapeshellarg($file),
        $output,
        $exitCode
    );

    if ($exitCode !== 0) {

        $result['valid'] = false;

        $result['errors'][] =
            'PHP syntax error: ' .
            str_replace(
                $backendPath . DIRECTORY_SEPARATOR,
                '',
                $file
            );
    }
}


/*
|--------------------------------------------------------------------------
| Composer validation
|--------------------------------------------------------------------------
*/

$composerPath =
    $backendPath . DIRECTORY_SEPARATOR . 'composer.json';

if (is_file($composerPath)) {

    $composer = json_decode(
        file_get_contents($composerPath),
        true
    );

    if (
        json_last_error() !== JSON_ERROR_NONE
    ) {

        $result['valid'] = false;

        $result['errors'][] =
            'Invalid composer.json: ' .
            json_last_error_msg();
    }
}


/*
|--------------------------------------------------------------------------
| Laravel bootstrap check
|--------------------------------------------------------------------------
*/

$artisanPath =
    $backendPath . DIRECTORY_SEPARATOR . 'artisan';

if (is_file($artisanPath)) {

    $output = [];
    $exitCode = 0;

    exec(
        'cd ' .
        escapeshellarg($backendPath) .
        ' && php artisan --version 2>&1',
        $output,
        $exitCode
    );

    if ($exitCode !== 0) {

        $result['valid'] = false;

        $result['errors'][] =
            'Laravel artisan validation failed.';
    }
}


/*
|--------------------------------------------------------------------------
| Final result
|--------------------------------------------------------------------------
*/

echo json_encode(
    $result,
    JSON_UNESCAPED_UNICODE |
    JSON_PRETTY_PRINT
);

exit(
    $result['valid'] ? 0 : 1
);