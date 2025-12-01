death-engine/
├─ README.md
├─ docs/
│  ├─ architecture/
│  ├─ aln/
│  ├─ bci/
│  └─ horror-design/
├─ engine/               # Core runtime
│  ├─ core/              # ECS, events, serialization
│  ├─ rendering/         # DX12/Vulkan backends, post-FX
│  ├─ audio/             # Spatial/binaural audio, DSP
│  ├─ physics/           # Integration, destructibles, ragdoll
│  └─ scripting/         # Runtime scripting bridge
├─ gameplay/             # Horror and hub logic
│  ├─ horror_director/   # Global fear orchestrator
│  ├─ ai/                # Behaviors, nav
│  ├─ hub_system/        # Hexen-style hubs, puzzles
│  ├─ inventory_classes/ # Augmented-user “classes”
│  └─ interaction/
├─ aln_chain/            # ALN + blockchain layer
│  ├─ schemas/
│  ├─ validators/
│  ├─ tx_builders/
│  └─ compliance/
├─ bci/                  # BCI & bio-signal stack
│  ├─ drivers/
│  ├─ acquisition/
│  ├─ preprocessing/
│  ├─ feature_extraction/
│  └─ mapping/
├─ tools/                # Editors and CLIs
│  ├─ editor/            # World/editor UI
│  ├─ hub_editor/
│  ├─ aln_inspector/     # ALN manifest inspector
│  └─ bci_calibration/
├─ deploy/               # DevOps, infra
│  ├─ docker/
│  ├─ k8s/
│  ├─ azure/
│  │  └─ edge_mini_r/    # Azure Stack Edge Mini R
│  └─ ci_cd/
├─ samples/
│  ├─ demo_hub/
│  └─ demo_bci/
└─ .github/
   └─ workflows/
