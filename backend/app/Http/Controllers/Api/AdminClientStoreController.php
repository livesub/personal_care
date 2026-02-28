<?php

namespace App\Http\Controllers\Api;

use App\Http\Requests\StoreClientRequest;
use App\Models\Client;
use App\Models\ClientEmergencyContact;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

/**
 * 이용자(Client) 등록 API.
 * POST /api/admin/clients
 * - 주민번호 뒷자리 첫 숫자 1,3 → M, 2,4 → F 성별 자동 파싱.
 * - resident_no_suffix_hash로 동일 센터 내 중복 가입 차단.
 * - 비상연락망 contacts[] 일괄 저장.
 */
class AdminClientStoreController extends Controller
{
    public function __invoke(StoreClientRequest $request): JsonResponse
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

        $residentSuffix = $request->input('resident_no_suffix');
        $hash = hash('sha256', $residentSuffix);

        if (Client::withoutGlobalScope('center')->where('center_id', $centerId)->where('resident_no_suffix_hash', $hash)->exists()) {
            return response()->json([
                'message' => __('admin_client_duplicate_resident'),
                'errors' => [
                    'resident_no_suffix' => [__('admin_client_duplicate_resident')],
                ],
            ], 422);
        }

        $gender = $this->parseGenderFromSuffix($residentSuffix);

        try {
            $client = DB::transaction(function () use ($request, $centerId, $residentSuffix, $gender) {
                $client = new Client;
                $client->center_id = $centerId;
                $client->name = $request->input('name');
                $client->phone = $request->input('phone');
                $client->resident_no_prefix = $request->input('resident_no_prefix');
                $client->resident_no_suffix_hidden = $residentSuffix;
                $client->gender = $gender;
                $client->disability_type = $request->input('disability_type');
                $client->voucher_balance = (int) ($request->input('voucher_balance') ?? 0);
                $client->status = $request->input('status') ?? 'active';
                $client->save();

                $contacts = $request->input('contacts', []);
                foreach ($contacts as $i => $row) {
                    ClientEmergencyContact::create([
                        'client_id' => $client->id,
                        'name' => $row['name'] ?? '',
                        'phone' => $row['phone'] ?? '',
                        'relation' => $row['relation'] ?? null,
                        'sort_order' => isset($row['priority_order']) ? (int) $row['priority_order'] : $i,
                    ]);
                }

                return $client->load('emergencyContacts');
            });
        } catch (\Throwable $e) {
            return response()->json([
                'message' => __('auth_server_error'),
                'errors' => [
                    'server' => [config('app.debug') ? $e->getMessage() : __('auth_server_error')],
                ],
            ], 500);
        }

        return response()->json([
            'message' => __('admin_client_created'),
            'client' => $this->clientToArray($client),
        ], 201);
    }

    /** 주민번호 뒷자리 첫 숫자: 1,3 → M, 2,4 → F, 그 외 null */
    private function parseGenderFromSuffix(string $suffix): ?string
    {
        $first = substr($suffix, 0, 1);
        if (in_array($first, ['1', '3'], true)) {
            return 'M';
        }
        if (in_array($first, ['2', '4'], true)) {
            return 'F';
        }

        return null;
    }

    private function clientToArray(Client $client): array
    {
        return [
            'id' => $client->id,
            'center_id' => $client->center_id,
            'name' => $client->name,
            'phone' => $client->phone,
            'resident_no_suffix_hidden' => $client->resident_no_suffix_hidden,
            'gender' => $client->gender,
            'disability_type' => $client->disability_type,
            'voucher_balance' => (int) $client->voucher_balance,
            'status' => $client->status,
            'created_at' => $client->created_at?->format('Y-m-d H:i:s'),
            'emergency_contacts' => $client->emergencyContacts->map(fn ($c) => [
                'id' => $c->id,
                'name' => $c->name,
                'phone' => $c->phone,
                'relation' => $c->relation,
                'priority_order' => $c->sort_order,
            ])->values()->all(),
        ];
    }
}
