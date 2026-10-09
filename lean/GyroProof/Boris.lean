import Mathlib

/-!
The magnetic-only Boris velocity update is a rational rotation in two
dimensions. The signed parameter `t` is `omega * dt / 2`. This file proves
properties of that exact map over the real numbers; it says nothing about
rounding error in a floating-point implementation.
-/

def borisX (t x y : ℝ) : ℝ :=
  ((1 - t ^ 2) * x + 2 * t * y) / (1 + t ^ 2)

def borisY (t x y : ℝ) : ℝ :=
  ((1 - t ^ 2) * y - 2 * t * x) / (1 + t ^ 2)

theorem boris_preserves_squared_speed (t x y : ℝ) :
    borisX t x y ^ 2 + borisY t x y ^ 2 = x ^ 2 + y ^ 2 := by
  have denominator_ne_zero : 1 + t ^ 2 ≠ 0 := by positivity
  unfold borisX borisY
  field_simp [denominator_ne_zero]
  ring

theorem boris_reverses_with_signed_step (t x y : ℝ) :
    borisX (-t) (borisX t x y) (borisY t x y) = x ∧
    borisY (-t) (borisX t x y) (borisY t x y) = y := by
  have denominator_ne_zero : 1 + t ^ 2 ≠ 0 := by positivity
  have reversed_denominator_ne_zero : 1 + (-t) ^ 2 ≠ 0 := by positivity
  constructor
  · unfold borisX borisY
    field_simp [denominator_ne_zero, reversed_denominator_ne_zero]
    ring
  · unfold borisX borisY
    field_simp [denominator_ne_zero, reversed_denominator_ne_zero]
    ring
