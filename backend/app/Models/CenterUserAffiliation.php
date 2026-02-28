<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * 보호사(users) - 센터(centers) N:M 소속.
 * Unique(center_id, user_id).
 */
class CenterUserAffiliation extends Model
{
    protected $table = 'center_user_affiliation';

    protected $fillable = [
        'center_id',
        'user_id',
    ];

    public function center(): BelongsTo
    {
        return $this->belongsTo(Center::class, 'center_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id', 'user_id');
    }
}
