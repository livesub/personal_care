<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * 이용자(Client) 등록 API 검증.
 * POST /api/admin/clients
 * - resident_no_suffix: 주민번호 뒷자리 7자리 (숫자만). 중복은 Controller에서 hash로 검사.
 * - contacts: 비상연락망 배열. 각 항목 name, phone 필수.
 */
class StoreClientRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:50'],
            'resident_no_prefix' => ['nullable', 'string', 'regex:/^[0-9]{6}$/'],
            'resident_no_suffix' => ['required', 'string', 'regex:/^[0-9]{7}$/'],
            'phone' => ['nullable', 'string', 'max:255'],
            'disability_type' => ['nullable', 'string', 'max:50'],
            'voucher_balance' => ['nullable', 'numeric', 'min:0'],
            'status' => ['nullable', 'string', 'in:active,inactive'],
            'contacts' => ['nullable', 'array'],
            'contacts.*.name' => ['required', 'string', 'max:50'],
            'contacts.*.phone' => ['required', 'string', 'max:255'],
            'contacts.*.relation' => ['nullable', 'string', 'max:30'],
            'contacts.*.priority_order' => ['nullable', 'integer', 'min:0'],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required' => __('admin_client_name_required'),
            'name.max' => __('admin_client_name_max'),
            'resident_no_suffix.required' => __('admin_client_resident_suffix_required'),
            'resident_no_suffix.regex' => __('admin_client_resident_suffix_regex'),
            'phone.max' => __('admin_client_phone_max'),
            'disability_type.max' => __('admin_client_disability_type_max'),
            'voucher_balance.numeric' => __('admin_client_voucher_numeric'),
            'voucher_balance.min' => __('admin_client_voucher_min'),
            'status.in' => __('admin_client_status_in'),
            'contacts.*.name.required' => __('admin_client_contact_name_required'),
            'contacts.*.name.max' => __('admin_client_contact_name_max'),
            'contacts.*.phone.required' => __('admin_client_contact_phone_required'),
            'contacts.*.phone.max' => __('admin_client_contact_phone_max'),
            'contacts.*.relation.max' => __('admin_client_contact_relation_max'),
        ];
    }

    public function attributes(): array
    {
        return [
            'name' => __('admin_client_name_label'),
            'resident_no_suffix' => __('admin_client_resident_suffix_label'),
            'phone' => __('admin_client_phone_label'),
            'contacts' => __('admin_client_contacts_label'),
        ];
    }
}
