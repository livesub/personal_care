<?php

namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\User>
 */
class UserFactory extends Factory
{
    /**
     * The current password being used by the factory.
     */
    protected static ?string $password;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $num = fake()->unique()->numberBetween(10000000, 99999999);
        return [
            'login_id' => '010' . $num,
            'password' => static::$password ??= Hash::make('password'),
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'resident_no_suffix_hidden' => (string) fake()->numberBetween(1000000, 9999999),
            'status' => 'active',
            'is_first_login' => false,
        ];
    }
}
