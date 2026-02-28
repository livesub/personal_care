<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * 이용자(clients) 1:N 비상연락처.
 */
class ClientEmergencyContact extends Model
{
    protected $table = 'client_emergency_contacts';

    protected $fillable = [
        'client_id',
        'name',
        'phone',
        'relation',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'sort_order' => 'integer',
        ];
    }

    public function client(): BelongsTo
    {
        return $this->belongsTo(Client::class, 'client_id');
    }
}
