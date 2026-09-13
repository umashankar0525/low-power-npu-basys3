"""Phase 6 INT8 quantization helpers for the Basys 3 NPU project.

This module implements the numerical contract derived in docs/learning and
selected in docs/design for symmetric per-tensor INT8 quantization.

No FPGA behavior is used to generate expected results; this file is intended to
serve as an independent software-side reference for later verification.
"""

from __future__ import annotations

import math
from typing import Iterable, List, Sequence, Tuple

QMIN = -127
QMAX = 127
COEFF_BITS = 24
COEFF_MAX = (1 << COEFF_BITS) - 1
MAX_FRAC_BITS = 42


def round_away_from_zero(value: float) -> int:
    """Round to nearest integer, resolving exact ties away from zero."""
    if value >= 0.0:
        return math.floor(value + 0.5)
    return math.ceil(value - 0.5)


def derive_symmetric_scale(values: Iterable[float]) -> float:
    """Return S = max(abs(x)) / 127 for a non-empty tensor.

    For an all-zero tensor, return 1.0 so later equations remain defined while
    all quantized values remain zero.
    """
    data = [float(v) for v in values]
    if not data:
        raise ValueError("cannot derive a scale from an empty tensor")

    max_abs = max(abs(v) for v in data)
    if max_abs == 0.0:
        return 1.0
    return max_abs / QMAX


def quantize_symmetric(values: Iterable[float], scale: float) -> List[int]:
    """Quantize FP32-like values into the symmetric signed INT8 range."""
    if scale <= 0.0:
        raise ValueError("scale must be positive")

    quantized: List[int] = []
    for value in values:
        q = round_away_from_zero(float(value) / scale)
        q = max(QMIN, min(QMAX, q))
        quantized.append(q)
    return quantized


def dequantize_symmetric(values: Iterable[int], scale: float) -> List[float]:
    """Map integer codes back to their approximate real values."""
    if scale <= 0.0:
        raise ValueError("scale must be positive")
    return [int(v) * scale for v in values]


def derive_relu_output_scale(outputs: Iterable[float]) -> float:
    """Derive one fixed output scale from representative post-ReLU values."""
    data = [max(0.0, float(v)) for v in outputs]
    if not data:
        raise ValueError("cannot derive an output scale from an empty set")

    max_out = max(data)
    if max_out == 0.0:
        return 1.0
    return max_out / QMAX


def derive_requantization_params(
    s_a: float,
    s_w: float,
    s_out: float,
    coeff_bits: int = COEFF_BITS,
    max_frac_bits: int = MAX_FRAC_BITS,
) -> Tuple[float, int, int]:
    """Return (M, M_int, F) for M ~= M_int / 2**F.

    The largest usable F is selected such that M_int fits in the chosen unsigned
    coefficient width. F is also capped by the Phase 6 arithmetic bound.
    """
    if s_a <= 0.0 or s_w <= 0.0 or s_out <= 0.0:
        raise ValueError("all scales must be positive")
    if coeff_bits <= 0:
        raise ValueError("coefficient width must be positive")
    if max_frac_bits < 0:
        raise ValueError("max_frac_bits must be non-negative")

    multiplier = (s_a * s_w) / s_out
    coeff_max = (1 << coeff_bits) - 1

    selected_f = None
    selected_coeff = None

    for frac_bits in range(max_frac_bits + 1):
        coefficient = math.floor(multiplier * (1 << frac_bits) + 0.5)
        if coefficient <= coeff_max:
            selected_f = frac_bits
            selected_coeff = coefficient
        else:
            break

    if selected_f is None or selected_coeff is None:
        raise ValueError(
            "requantization multiplier does not fit the coefficient width even at F=0"
        )

    return multiplier, selected_coeff, selected_f


def int_convolution_3x3(
    activations_q: Sequence[int], weights_q: Sequence[int]
) -> int:
    """Compute the independent 3x3 INT8 integer dot product."""
    if len(activations_q) != 9 or len(weights_q) != 9:
        raise ValueError("3x3 convolution requires exactly 9 activations and 9 weights")

    for value in activations_q:
        if value < QMIN or value > QMAX:
            raise ValueError("activation is outside the generated INT8 contract")
    for value in weights_q:
        if value < QMIN or value > QMAX:
            raise ValueError("weight is outside the generated INT8 contract")

    return sum(int(a) * int(w) for a, w in zip(activations_q, weights_q))


def requantize_relu(accumulator: int, m_int: int, frac_bits: int) -> int:
    """Reference behavior for ReLU + fixed-point requantization + saturation."""
    if m_int < 0 or m_int > COEFF_MAX:
        raise ValueError("m_int must fit the 24-bit unsigned coefficient contract")
    if frac_bits < 0 or frac_bits > MAX_FRAC_BITS:
        raise ValueError("frac_bits must be in the range 0..42")

    if accumulator <= 0:
        return 0

    product = int(accumulator) * int(m_int)

    if frac_bits == 0:
        q_pre = product
    else:
        q_pre = (product + (1 << (frac_bits - 1))) >> frac_bits

    return min(q_pre, QMAX)


def pack_four_int8(values: Sequence[int]) -> int:
    """Pack four signed INT8 codes into one 32-bit word, lane 0 in bits 7:0."""
    if len(values) != 4:
        raise ValueError("exactly four lanes are required")

    word = 0
    for lane, value in enumerate(values):
        if value < -128 or value > 127:
            raise ValueError("packed value does not fit signed INT8")
        word |= (int(value) & 0xFF) << (8 * lane)
    return word


def pack_3x3_to_words(values: Sequence[int]) -> List[int]:
    """Pack nine INT8 values as 4 + 4 + 1 with three zero-padded final lanes."""
    if len(values) != 9:
        raise ValueError("exactly nine INT8 values are required")

    return [
        pack_four_int8(values[0:4]),
        pack_four_int8(values[4:8]),
        pack_four_int8([values[8], 0, 0, 0]),
    ]


def format_mem_words(words: Iterable[int]) -> List[str]:
    """Format 32-bit words as eight hexadecimal digits for memory files."""
    formatted = []
    for word in words:
        if word < 0 or word > 0xFFFFFFFF:
            raise ValueError("memory word must fit 32 unsigned bits")
        formatted.append(f"{word:08X}")
    return formatted
