```
Death-Engine/
├── config/
│   ├── bci/
│   │   ├── octa/
│   │   │   └── octa-region-geometry-v1.json
│   │   ├── hex/
│   │   │   └── hex-array-mapping-v1.json
│   │   ├── hyperdocker/
│   │   │   ├── quadrant-hyperdocker-v1.json
│   │   │   └── hyperdocker-blending-policy-v1.json
│   │   ├── quantum/
│   │   │   └── quantum-telemetry-profile-v1.json
│   │   ├── custom/
│   │   │   ├── custom-mapping-envelope-v1.json
│   │   │   └── per-platform-mapping-registry-v1.json
│   │   ├── safety/
│   │   │   └── safety-profile-registry-v1.json
│   │   └── curves/
│   │       └── curve-family-catalog-v1.json
│   ├── audio/
│   │   ├── audio-balance-3d-v1.json
│   │   └── audio-rtpc-index-v1.json
│   ├── haptics/
│   │   └── haptic-routing-table-v1.json
│   ├── debug/
│   │   ├── bci-debug-overlay-config-v1.json
│   │   └── bci-geometry-debugger-config-v1.json
│   ├── hex/
│   │   └── invariant-hex-projection-v1.json
│   └── death-engine-bci-config-toml-template.toml
├── crates/
│   ├── bci_kernel/
│   │   └── src/
│   │       ├── octa.rs
│   │       └── hyperdocker.rs
│   ├── bci_hex_array/
│   │   └── src/lib.rs
│   ├── qct_simulator/
│   │   └── src/lib.rs
│   └── custom_mapping_validator/
│       └── src/lib.rs
├── examples/
│   └── bci/
│       ├── octa_bindings_lab_v1.json
│       └── qct_binding_lab_v1.json
├── scripts/
│   └── audio/
│       └── bci_audio_balancer.lua
├── schemas/
│   ├── bci/
│   │   ├── bci-summary-full-v1.json
│   │   └── hex-array-reactive-envelope-v1.json
│   └── telemetry/
│       └── telemetry-output-format-v1.json
└── docs/
    ├── bci/
    │   ├── octa-regions-spec-v1.md
    │   ├── hex-array-spec-v1.md
    │   ├── quadrant-hyperdocker-spec-v1.md
    │   ├── quantum-telemetry-gaming-spec-v1.md
    │   ├── custom-mapping-guide-v1.md
    │   ├── platform-abstraction-layer-spec-v1.md
    │   └── bci-geometry-authoring-contract-v1.md
    └── audio/
        ├── 3d-audio-balance-spec-v1.md
        └── bci-hex-audio-spatialization-spec-v1.md
        ```
