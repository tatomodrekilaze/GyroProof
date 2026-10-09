# The map behind the ledger

This note fixes the sign convention and derives the two angles compared by the Julia script.

## Magnetic motion

Take a uniform magnetic field in the positive `z` direction and write `omega = qB/m`, including the sign of the charge. The planar Lorentz equation is

```text
dv_x/dt =  omega v_y
dv_y/dt = -omega v_x
```

For initial velocity `(1, 0)`, the exact velocity after elapsed time `T` is

```text
v_exact(T) = (cos(omega T), -sin(omega T))
```

so its signed phase is `-omega T`. The Julia script follows velocity only; it does not discretize the particle's position.

## Boris velocity update

For one step of length `dt`, set `t = omega * dt / 2`. The magnetic-only Boris update is

```text
v'_x = ((1 - t^2) v_x + 2t v_y) / (1 + t^2)
v'_y = ((1 - t^2) v_y - 2t v_x) / (1 + t^2)
```

The double-angle identities give

```text
cos(2 atan(t)) = (1 - t^2) / (1 + t^2)
sin(2 atan(t)) = 2t / (1 + t^2)
```

Therefore this map is a rotation by `-2 atan(t)`. The Lean file works directly with the rational expressions and proves that `v'_x^2 + v'_y^2 = v_x^2 + v_y^2`. Its second theorem proves that applying the same map with `-t` undoes it.

## Phase discrepancy

After `N` equal steps, the numerical and exact phases are

```text
phase_numerical = -2N atan(omega * dt / 2)
phase_exact     = -N omega dt
phase_error     = N [omega dt - 2 atan(omega * dt / 2)]
```

This is a difference between the discrete and continuous rotation angles. For small `z = omega * dt`, the per-step discrepancy begins with `z^3 / 12`, so at a fixed final time the accumulated phase error is second order in `dt`. The statement is an asymptotic description for small steps, not an error bound for every parameter choice.

For the checked-in reference run (`omega = 1`, `dt = 0.1`, `N = 100`), the Julia program reports final numerical phase `-9.99167914439` rad and signed error `0.00832085561145` rad. The initial and final speed both print as `1`; the CSV retains more digits for inspection.
