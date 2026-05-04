#include "bci_rotting_visuals_adapter.hpp"
#include <algorithm>
#include <cmath>

namespace bci::rotting {

RottingVisualsAdapter::RottingVisualsAdapter(ParameterCommitFn commit_fn)
    : commit_fn_(std::move(commit_fn)) {}

void RottingVisualsAdapter::apply_frame(const RottingVisualParams& new_params, float delta_time) {
    if (!new_params.is_valid) return;

    const float alpha = 1.0f - std::exp(-8.0f * delta_time); // ~125ms smoothing

    std::lock_guard<std::mutex> lock(param_mutex_);
    active_params_.mask_radius   = smooth(active_params_.mask_radius,   new_params.mask_radius,   alpha, delta_time);
    active_params_.mask_feather  = smooth(active_params_.mask_feather,  new_params.mask_feather,  alpha, delta_time);
    active_params_.decay_grain   = smooth(active_params_.decay_grain,   new_params.decay_grain,   alpha, delta_time);
    active_params_.color_desat   = smooth(active_params_.color_desat,   new_params.color_desat,   alpha, delta_time);
    active_params_.vein_overlay  = smooth(active_params_.vein_overlay,  new_params.vein_overlay,  alpha, delta_time);
    active_params_.motion_smear  = smooth(active_params_.motion_smear,  new_params.motion_smear,  alpha, delta_time);
    active_params_.is_valid      = true;

    pending_commit_.store(true, std::memory_order_release);
}

RottingVisualParams RottingVisualsAdapter::get_current_params() const {
    std::lock_guard<std::mutex> lock(param_mutex_);
    return active_params_;
}

void RottingVisualsAdapter::reset_to_safe() {
    std::lock_guard<std::mutex> lock(param_mutex_);
    active_params_ = RottingVisualParams{};
    pending_commit_.store(false, std::memory_order_release);
}

float RottingVisualsAdapter::smooth(float current, float target, float alpha, float dt) {
    constexpr float EPS = 1e-5f;
    float delta = target - current;
    if (std::abs(delta) < EPS) return current;
    return current + delta * alpha;
}

} // namespace bci::rotting
