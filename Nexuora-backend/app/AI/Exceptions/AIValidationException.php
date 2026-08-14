<?php
namespace App\AI\Exceptions;

class AIValidationException extends \RuntimeException
{
    protected array $errors;

    public function __construct(array $errors, string $message = '')
    {
        parent::__construct($message ?: implode('; ', $errors));
        $this->errors = $errors;
    }

    public function getErrors(): array
    {
        return $this->errors;
    }
}
