<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Center;
use Illuminate\Http\JsonResponse;

/**
 * 센터 목록. 로그인 전 호출 가능(인증 미들웨어 없음).
 * JSON: id, name, code, center_code(동일 값).
 */
class CentersController extends Controller
{
    public function index(): JsonResponse
    {
        $centers = Center::orderBy('name')->get(['id', 'name', 'code']);
        $list = $centers->map(fn ($c) => [
            'id' => $c->id,
            'name' => $c->name,
            'code' => $c->code,
            'center_code' => $c->code,
        ])->values()->all();
        return response()->json($list);
    }
}
