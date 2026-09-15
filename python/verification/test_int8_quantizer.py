"""Directed verification for Phase 6 INT8 quantization helpers.

This script independently checks the documented software-side numerical contract
used by the Basys 3 NPU project. It intentionally prints the observed values so
review evidence contains more than a single PASS banner.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

QUANT_DIR = Path(__file__).resolve().parents[1] / "quantization"
sys.path.insert(0, str(QUANT_DIR))

from int8_quantizer import (  # noqa: E402
    derive_relu_output_scale,
    derive_requantization_params,
    derive_symmetric_scale,
    format_mem_words,
    int_convolution_3x3,
    pack_3x3_to_words,
    quantize_symmetric,
    requantize_relu,
)


failures = 0


def check_equal(name: str, observed, expected) -> None:
    global failures
    if observed == expected:
        print(f"PASS {name}: observed={observed!r} expected={expected!r}")
    else:
        failures += 1
        print(f"FAIL {name}: observed={observed!r} expected={expected!r}")


def check_close(name: str, observed: float, expected: float, tol: float = 1e-15) -> None:
    global failures
    if math.isclose(observed, expected, rel_tol=0.0, abs_tol=tol):
        print(f"PASS {name}: observed={observed:.17g} expected={expected:.17g}")
    else:
        failures += 1
        print(f"FAIL {name}: observed={observed:.17g} expected={expected:.17g}")


def main() -> int:
    print("------------------------------------------------------------")
    print("A. Symmetric scale derivation")
    print("------------------------------------------------------------")
    scale = derive_symmetric_scale([-0.5, 0.25, 0.0])
    check_close("symmetric scale max|x|=0.5", scale, 0.5 / 127.0)
    check_equal("all-zero symmetric scale", derive_symmetric_scale([0.0, 0.0, 0.0]), 1.0)

    relu_scale = derive_relu_output_scale([-2.0, 0.0, 0.5])
    check_close("ReLU output scale max=0.5", relu_scale, 0.5 / 127.0)
    check_equal("all-zero ReLU output scale", derive_relu_output_scale([-2.0, 0.0]), 1.0)

    print("------------------------------------------------------------")
    print("B. Ties-away-from-zero rounding and clipping")
    print("------------------------------------------------------------")
    ties = quantize_symmetric([0.25, -0.25, 0.75, -0.75], 0.5)
    check_equal("ties away from zero", ties, [1, -1, 2, -2])

    clipped = quantize_symmetric([64.0, -64.0], 0.5)
    check_equal("clip to generated INT8 range", clipped, [127, -127])

    print("------------------------------------------------------------")
    print("C. Maximum 3x3 integer convolution")
    print("------------------------------------------------------------")
    max_acc = int_convolution_3x3([127] * 9, [127] * 9)
    check_equal("9 * 127 * 127", max_acc, 145161)

    print("------------------------------------------------------------")
    print("D. Requantization parameter generation")
    print("------------------------------------------------------------")
    multiplier, m_int, frac_bits = derive_requantization_params(0.1, 1.0, 1.0)
    check_close("real multiplier M", multiplier, 0.1)
    check_equal("M_INT for M=0.1", m_int, 13421773)
    check_equal("FRAC_BITS for M=0.1", frac_bits, 27)

    f28_coeff = math.floor(0.1 * (1 << 28) + 0.5)
    check_equal("F=28 coefficient", f28_coeff, 26843546)
    check_equal("F=28 exceeds 24-bit unsigned coefficient", f28_coeff > 0xFFFFFF, True)

    print("------------------------------------------------------------")
    print("E. BRAM packing and byte order")
    print("------------------------------------------------------------")
    packed = pack_3x3_to_words([1, -1, 2, -2, 3, -3, 4, -4, 5])
    check_equal("packed word 0", packed[0], 0xFE02FF01)
    check_equal("packed word 1", packed[1], 0xFC04FD03)
    check_equal("packed word 2", packed[2], 0x00000005)
    check_equal("formatted memory words", format_mem_words(packed), ["FE02FF01", "FC04FD03", "00000005"])

    print("------------------------------------------------------------")
    print("F. requantize_relu reference behavior")
    print("------------------------------------------------------------")
    identity_cases = [
        (-1, 0),
        (0, 0),
        (1, 1),
        (126, 126),
        (127, 127),
        (128, 127),
        (145161, 127),
    ]
    for acc, expected in identity_cases:
        check_equal(f"identity acc={acc}", requantize_relu(acc, 1, 0), expected)

    half_cases = [(1, 1), (2, 1), (3, 2), (4, 2)]
    for acc, expected in half_cases:
        check_equal(f"half-scale acc={acc}", requantize_relu(acc, 1, 1), expected)

    three_quarter_cases = [(1, 1), (2, 2), (3, 2), (5, 4), (169, 127), (170, 127)]
    for acc, expected in three_quarter_cases:
        check_equal(f"three-quarter acc={acc}", requantize_relu(acc, 3, 2), expected)

    check_equal(
        "maximum-width reference",
        requantize_relu(145161, 0xFFFFFF, 42),
        1,
    )

    print("------------------------------------------------------------")
    if failures == 0:
        print("PY_INT8_QUANTIZER_PASS: all directed checks passed")
        return 0

    print(f"PY_INT8_QUANTIZER_FAIL: failures={failures}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
