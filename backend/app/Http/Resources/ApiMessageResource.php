<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * API 단순 메시지 응답 (.cursorrules: API 표준 JsonResource 통일).
 * 성공 시 { "message": "..." } 형식 반환.
 */
class ApiMessageResource extends JsonResource
{
    public function __construct(
        private readonly string $message
    ) {
        parent::__construct(['message' => $message]);
    }

    public function toArray(Request $request): array
    {
        return [
            'message' => $this->message,
        ];
    }
}
