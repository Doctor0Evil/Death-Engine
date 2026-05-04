#pragma once
#include <atomic>
#include <mutex>
#include <array>
#include <string>
#include <functional>

namespace bci::rotting {

// Thread-safe parameter container for post-process & audio routing
struct RottingVisualParams {
    float mask_radius = 0.0f;
    float mask_feather = 0.0f;
    float decay_grain = 0.0f;
    float color_desat = 0.0f;
    float vein_overlay = 0.0f;
    float motion_smear = 0.0f;
    bool  is_valid = false;
};

using ParameterCommitFn = std::function<void(const RottingVisualParams&)>;

class RottingVisualsAdapter {
public:
    explicit RottingVisualsAdapter(ParameterCommitFn commit_fn);
    ~RottingVisualsAdapter() = default;

    // Thread-safe ingestion of Rust FFI outputs
    void apply_frame(const RottingVisualParams& new_params, float delta_time);

    // Read current smoothed state for engine binding
    RottingVisualParams get_current_params() const;

    // Reset to safe baseline
    void reset_to_safe();

private:
    mutable std::mutex param_mutex_;
    RottingVisualParams active_params_;
    ParameterCommitFn commit_fn_;
    std::atomic<bool> pending_commit_{false};

    // Exponential smoothing to prevent frame-to-frame jitter
    static float smooth(float current, float target, float smoothing_factor, float dt);
};

} // namespace bci::rotting
