# Simple CPU (TinyRV32)

A fixed-program, 32-bit ALU demo for a single SKY130 Tiny Tapeout tile. It executes a subset of RISC-V ALU instructions and exposes results on the digital output pins. It is not a full RV32I core.

- [Architecture, pinout, and demo instructions](docs/info.md)
- [Verilog source and ROM](src/project.v)
- [GitHub Actions results](../../actions)

## Run the RTL test locally

Install Icarus Verilog and use a Python environment with the repository's pinned dependencies.

```sh
cd test
python -m pip install -r requirements.txt
make
```

The GDS workflow runs the SKY130 build, Tiny Tapeout precheck and gate-level simulation. Check all three on the same commit before using its layout for submission.
