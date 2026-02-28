<?php

namespace App\Http\Controllers\Api;

use App\Models\Client;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * 이용자(장애인) 목록 API.
 * GET /api/admin/clients?search=&page=1&per_page=10
 * - current_center_id 기준 격리.
 * - search: 이름, 연락처 부분 일치.
 * - 주민번호 뒷자리 마스킹(***XXXX), 바우처 잔액 노출.
 */
class AdminClientsIndexController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $centerId = app('current_center_id');
        if ($centerId === null) {
            return response()->json([
                'app' => 'Personal Care',
                'code' => 'ERR_AUTH_003',
                'message' => __('auth_center_id_required'),
                'hint' => 'current_center_id not set.',
            ], 500);
        }

        $query = Client::query()->orderBy('name');

        $search = $request->input('search');
        $searchField = $request->input('search_field');
        if ($search !== null && $search !== '') {
            $term = '%' . trim($search) . '%';
            $digitsOnly = preg_replace('/\D/', '', $search);
            if ($searchField === 'phone') {
                $query->where('phone', 'like', $term);
            } elseif ($searchField === 'resident_no' && (strlen($digitsOnly) === 7 || strlen($digitsOnly) === 13)) {
                $suffix = strlen($digitsOnly) === 13 ? substr($digitsOnly, -7) : $digitsOnly;
                $hash = hash('sha256', $suffix);
                $query->where('resident_no_suffix_hash', $hash);
            } else {
                $query->where('name', 'like', $term);
            }
        }

        $perPage = (int) $request->input('per_page', 10);
        $perPage = $perPage >= 1 && $perPage <= 100 ? $perPage : 10;
        $paginator = $query->with('emergencyContacts')->paginate($perPage);

        $list = $paginator->getCollection()->map(function (Client $client) {
            return [
                'id' => $client->id,
                'name' => $client->name,
                'phone' => $client->phone,
                'resident_no_display_masked' => $this->formatResidentDisplayMasked($client->resident_no_prefix, $client->resident_no_suffix_hidden),
                'gender' => $client->gender,
                'voucher_balance' => (int) $client->voucher_balance,
                'status' => $client->status,
                'emergency_contacts' => $client->emergencyContacts->sortBy('sort_order')->values()->map(fn ($c) => [
                    'name' => $c->name,
                    'phone' => $c->phone,
                    'relation' => $c->relation ?? '',
                ])->all(),
            ];
        })->values()->all();

        return response()->json([
            'clients' => $list,
            'total' => $paginator->total(),
            'current_page' => $paginator->currentPage(),
            'per_page' => $paginator->perPage(),
            'last_page' => $paginator->lastPage(),
        ]);
    }

    /**
     * 주민번호 표시: 앞6자리 + '-' + 뒷자리 첫 글자 + '******' (예: 721115-1******).
     * prefix 없으면 앞 6자리는 '******'.
     */
    private function formatResidentDisplayMasked(?string $prefix, ?string $suffixDecrypted): string
    {
        $prefixPart = ($prefix !== null && strlen($prefix) >= 6) ? substr($prefix, 0, 6) : '******';
        if ($suffixDecrypted === null || $suffixDecrypted === '') {
            return $prefixPart . '-******';
        }
        $first = substr($suffixDecrypted, 0, 1);
        return $prefixPart . '-' . $first . '******';
    }
}
