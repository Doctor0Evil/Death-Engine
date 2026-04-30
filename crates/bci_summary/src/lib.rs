use serde::{Deserialize, Serialize};

#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
pub enum StressBand {
    Low,
    Medium,
    High,
    Extreme,
}

#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
pub enum AttentionBand {
    Distracted,
    Neutral,
    Focused,
    HyperFocused,
}

#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
pub enum SignalQuality {
    Good,
    Degraded,
    Unavailable,
}

#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
pub struct BciSummary {
    pub schemaVersion: &'static str,
    pub windowId: String,
    pub sessionId: String,
    pub timestamp: f64,
    pub stressScore: f32,
    pub stressBand: StressBand,
    pub attentionBand: AttentionBand,
    pub visualOverloadIndex: f32,
    pub startleSpike: bool,
    pub signalQuality: SignalQuality,
}

#[derive(Debug, Deserialize)]
pub struct MetricsEnvelope {
    pub schemaVersion: String,
    pub windowId: String,
    pub sessionId: String,
    pub timestamp: f64,
    pub metrics: Metrics,
    #[serde(default)]
    pub safety: Option<MetricsSafety>,
}

#[derive(Debug, Deserialize)]
pub struct Metrics {
    pub uecBand: f32,
    pub emdBand: f32,
    pub stciBand: f32,
    pub cdlBand: f32,
    pub arrBand: f32,
}

#[derive(Debug, Deserialize)]
pub struct MetricsSafety {
    pub detEstimate: Option<f32>,
    pub overload: Option<bool>,
    pub underengaged: Option<bool>,
}

pub fn summarize_from_metrics(
    env: &MetricsEnvelope,
    attention_raw: Option<f32>,
    startle_spike: bool,
    signal_quality: SignalQuality,
) -> BciSummary {
    let u = env.metrics.uecBand.clamp(0.0, 1.0);
    let e = env.metrics.emdBand.clamp(0.0, 1.0);
    let c = env.metrics.cdlBand.clamp(0.0, 1.0);

    let stress = ((u + e + c) / 3.0).clamp(0.0, 1.0);

    let stress_band = if stress < 0.25 {
        StressBand::Low
    } else if stress < 0.5 {
        StressBand::Medium
    } else if stress < 0.75 {
        StressBand::High
    } else {
        StressBand::Extreme
    };

    let attention_score = attention_raw.unwrap_or(0.5).clamp(0.0, 1.0);
    let attention_band = if attention_score < 0.25 {
        AttentionBand::Distracted
    } else if attention_score < 0.5 {
        AttentionBand::Neutral
    } else if attention_score < 0.75 {
        AttentionBand::Focused
    } else {
        AttentionBand::HyperFocused
    };

    let overload_flag = env
        .safety
        .as_ref()
        .and_then(|s| s.overload)
        .unwrap_or(false);
    let visual_overload_index = if overload_flag { 1.0 } else { 0.0 };

    BciSummary {
        schemaVersion: "1.0.0",
        windowId: env.windowId.clone(),
        sessionId: env.sessionId.clone(),
        timestamp: env.timestamp,
        stressScore: stress,
        stressBand: stress_band,
        attentionBand: attention_band,
        visualOverloadIndex: visual_overload_index,
        startleSpike: startle_spike,
        signalQuality: signal_quality,
    }
}
