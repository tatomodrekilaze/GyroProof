import Lake
open Lake DSL

package «gyro-proof» where

require mathlib from git
  "https://github.com/leanprover-community/mathlib4" @ "v4.19.0"

lean_lib GyroProof where
  srcDir := "lean"
