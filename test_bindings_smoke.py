# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Klyne Research

"""Smoke test for the Enigma dialect Python bindings.

Run with:
    source ~/.local/enigma-llvm/activate.sh
    export PYTHONPATH="$(pwd)/build/python/python_packages:$PYTHONPATH"
    python3 test_bindings_smoke.py
"""

from mlir import ir
from mlir.dialects import enigma


def test_dialect_registers():
    with ir.Context() as ctx, ir.Location.unknown():
        enigma.register_dialect(ctx)
        module = ir.Module.create()
        module.operation.verify()
        print("[PASS] dialect registered + empty module verifies")


def test_op_classes_exposed():
    names = [n for n in dir(enigma) if n.endswith("Op") and not n.startswith("_")]
    assert len(names) > 100, f"expected many op classes, got {len(names)}"
    assert "ThreadPositionInGridOp" in names
    assert "KernelOp" in names
    print(f"[PASS] {len(names)} op builder classes exposed")


def test_build_thread_position_op():
    """Build an enigma.thread_position_in_grid op and verify it."""
    with ir.Context() as ctx, ir.Location.unknown():
        enigma.register_dialect(ctx)
        module = ir.Module.create()

        with ir.InsertionPoint(module.body):
            i32 = ir.IntegerType.get_signless(32)
            # Enigma_Dimension is an I32EnumAttr with x=0, y=1, z=2.
            dim_x = ir.IntegerAttr.get(i32, 0)
            enigma.ThreadPositionInGridOp(dimension=dim_x)

        module.operation.verify()
        text = str(module)
        assert "enigma.thread_position_in_grid" in text, text
        print("[PASS] built + verified enigma.thread_position_in_grid op")
        print(text)


if __name__ == "__main__":
    test_dialect_registers()
    test_op_classes_exposed()
    test_build_thread_position_op()
    print("\nAll smoke tests passed.")
