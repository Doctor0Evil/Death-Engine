// crates/hpc_player_envelope_fps/src/lib.rs

use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Bounds {
    pub min: f32,
    pub max: f32,
}

#[derive(Debug, Deserialize)]
pub struct StateBounds {
    pub v: Bounds,
    pub stamina: Bounds,
    pub sanity: Bounds,
    pub R: Bounds,
    pub O: Bounds,
    pub battery: Bounds,
}

#[derive(Debug, Deserialize)]
pub struct VelocityCfg {
    pub vMax: f32,
    pub kappa: f32,
    pub alphaSprint: f32,
}

#[derive(Debug, Deserialize)]
pub struct StaminaCfg {
    pub lambdaRest: f32,
    pub lambdaDrain: f32,
    pub betaEnv: f32,
}

#[derive(Debug, Deserialize)]
pub struct SanityCfg {
    pub lambdaDecay: f32,
    pub lambdaRecover: f32,
    pub wCIC: f32,
    pub wDET: f32,
    pub wLSG: f32,
    pub wHVF: f32,
    pub wUEC: f32,
    pub wEMD: f32,
    pub wCDL: f32,
    pub wARR: f32,
    pub gammaArousal: f32,
    pub gammaOverload: f32,
    pub deadlanternMask: f32,
}

#[derive(Debug, Deserialize)]
pub struct HorrorExposureCfg {
    pub lambda: f32,
    pub thetaCIC: f32,
    pub thetaAOS: f32,
    pub thetaLSG: f32,
    pub thetaHVF: f32,
}

#[derive(Debug, Deserialize)]
pub struct OpacityCfg {
    pub lambda: f32,
    pub thetaAOS: f32,
    pub thetaSTCI: f32,
    pub thetaOverload: f32,
}

#[derive(Debug, Deserialize)]
pub struct BatteryCfg {
    pub lambdaDrain: f32,
    pub lambdaRecover: f32,
    pub phiCIC: f32,
}

#[derive(Debug, Deserialize)]
pub struct NoiseBounds {
    pub v: f32,
    pub stamina: f32,
    pub sanity: f32,
    pub R: f32,
    pub O: f32,
    pub battery: f32,
}

#[derive(Debug, Deserialize)]
pub struct PlayerEnvelopeCfg {
    pub schema: String,
    pub version: String,
    pub safetyTier: String,
    pub tickSeconds: f32,
    pub stateBounds: StateBounds,
    pub velocity: VelocityCfg,
    pub stamina: StaminaCfg,
    pub sanity: SanityCfg,
    pub horrorExposure: HorrorExposureCfg,
    pub opacity: OpacityCfg,
    pub battery: BatteryCfg,
    pub noiseBounds: NoiseBounds,
}

#[derive(Clone, Copy, Debug)]
pub struct State {
    pub v: f32,
    pub stamina: f32,
    pub sanity: f32,
    pub R: f32,
    pub O: f32,
    pub battery: f32,
}

#[derive(Clone, Copy, Debug)]
pub struct Invariants {
    pub CIC: f32,
    pub AOS: f32,
    pub DET: f32,
    pub LSG: f32,
    pub HVF_mag: f32,
}

#[derive(Clone, Copy, Debug)]
pub struct Metrics {
    pub UEC: f32,
    pub EMD: f32,
    pub STCI: f32,
    pub CDL: f32,
    pub ARR: f32,
}

#[derive(Clone, Copy, Debug)]
pub struct BciFrame {
    pub arousal: f32,
    pub overload: f32,
}

#[derive(Clone, Copy, Debug)]
pub struct Input {
    pub move_axis: f32,
    pub sprint: f32,
    pub flash: f32,
    pub deadlantern: f32,
}

fn clamp(x: f32, lo: f32, hi: f32) -> f32 {
    x.max(lo).min(hi)
}

impl PlayerEnvelopeCfg {
    pub fn initial_state(&self) -> State {
        State {
            v: 0.0,
            stamina: self.stateBounds.stamina.max,
            sanity: self.stateBounds.sanity.max,
            R: 0.0,
            O: 0.0,
            battery: self.stateBounds.battery.max,
        }
    }
}

pub fn step(
    cfg: &PlayerEnvelopeCfg,
    state: &mut State,
    inv: Invariants,
    met: Metrics,
    bci: BciFrame,
    input: Input,
) {
    let dt = cfg.tickSeconds;

    let target_v = {
        let mut tv = cfg.velocity.vMax *
            (input.move_axis.abs() + cfg.velocity.alphaSprint * input.sprint);
        if tv < 0.0 { tv = 0.0; }
        if tv > cfg.velocity.vMax { tv = cfg.velocity.vMax; }
        tv
    };
    let mut dv = cfg.velocity.kappa * (target_v - state.v);
    dv += cfg.noiseBounds.v;
    state.v += dt * dv;
    state.v = clamp(state.v, cfg.stateBounds.v.min, cfg.stateBounds.v.max);

    let L_move = input.move_axis.abs() * input.sprint;
    let mut S_env = inv.CIC + inv.LSG + inv.HVF_mag;
    if S_env > 3.0 { S_env = 3.0; }
    let mut ds = if L_move > 0.0 {
        -cfg.stamina.lambdaDrain * L_move * (1.0 + cfg.stamina.betaEnv * S_env)
    } else {
        cfg.stamina.lambdaRest * (1.0 - state.stamina)
    };
    ds += cfg.noiseBounds.stamina;
    state.stamina += dt * ds;
    state.stamina = clamp(state.stamina, cfg.stateBounds.stamina.min, cfg.stateBounds.stamina.max);

    let S_horror = {
        let mut s = cfg.sanity.wCIC * inv.CIC
            + cfg.sanity.wDET * inv.DET
            + cfg.sanity.wLSG * inv.LSG
            + cfg.sanity.wHVF * inv.HVF_mag
            + cfg.sanity.wUEC * met.UEC
            + cfg.sanity.wEMD * met.EMD
            + cfg.sanity.wCDL * met.CDL
            + cfg.sanity.wARR * (1.0 - met.ARR);
        if s < 0.0 { s = 0.0; }
        s
    };

    let mut G_bci = 1.0
        + cfg.sanity.gammaArousal * bci.arousal
        + cfg.sanity.gammaOverload * bci.overload;
    let det_cap = 1.0 + cfg.sanity.gammaArousal + cfg.sanity.gammaOverload;
    if G_bci > det_cap { G_bci = det_cap; }

    let m_dead = 1.0 - cfg.sanity.deadlanternMask * input.deadlantern;

    let mut dsa = -cfg.sanity.lambdaDecay * S_horror * G_bci * m_dead
        + cfg.sanity.lambdaRecover * (1.0 - state.sanity);
    dsa += cfg.noiseBounds.sanity;
    state.sanity += dt * dsa;
    state.sanity = clamp(state.sanity, cfg.stateBounds.sanity.min, cfg.stateBounds.sanity.max);

    let Hstim = cfg.horrorExposure.thetaCIC * inv.CIC * input.flash
        + cfg.horrorExposure.thetaAOS * inv.AOS * (1.0 - input.flash)
        + cfg.horrorExposure.thetaLSG * inv.LSG
        + cfg.horrorExposure.thetaHVF * inv.HVF_mag;
    let mut dR = cfg.horrorExposure.lambda * (Hstim - state.R) + cfg.noiseBounds.R;
    state.R += dt * dR;
    state.R = clamp(state.R, cfg.stateBounds.R.min, cfg.stateBounds.R.max);

    let O_target = cfg.opacity.thetaAOS * inv.AOS
        + cfg.opacity.thetaSTCI * (1.0 - met.STCI)
        + cfg.opacity.thetaOverload * bci.overload;
    let mut dO = cfg.opacity.lambda * (O_target - state.O) + cfg.noiseBounds.O;
    state.O += dt * dO;
    state.O = clamp(state.O, cfg.stateBounds.O.min, cfg.stateBounds.O.max);

    let L_bat = input.flash * (1.0 + cfg.battery.phiCIC * inv.CIC);
    let mut dB = -cfg.battery.lambdaDrain * L_bat
        + cfg.battery.lambdaRecover * (1.0 - input.flash) * (1.0 - state.battery);
    dB += cfg.noiseBounds.battery;
    state.battery += dt * dB;
    state.battery = clamp(
        state.battery,
        cfg.stateBounds.battery.min,
        cfg.stateBounds.battery.max,
    );
}

pub fn simulate_worst_case(
    cfg: &PlayerEnvelopeCfg,
    horizon_seconds: f32,
) -> Vec<State> {
    let steps = (horizon_seconds / cfg.tickSeconds).ceil() as usize;
    let mut states = Vec::with_capacity(steps + 1);
    let mut s = cfg.initial_state();
    states.push(s);

    let inv = Invariants {
        CIC: 1.0,
        AOS: 1.0,
        DET: 1.0,
        LSG: 1.0,
        HVF_mag: 1.0,
    };
    let met = Metrics {
        UEC: 1.0,
        EMD: 1.0,
        STCI: 0.0,
        CDL: 1.0,
        ARR: 0.0,
    };
    let bci = BciFrame {
        arousal: 1.0,
        overload: 1.0,
    };
    let input = Input {
        move_axis: 1.0,
        sprint: 1.0,
        flash: 1.0,
        deadlantern: 0.0,
    };

    for _ in 0..steps {
        step(cfg, &mut s, inv, met, bci, input);
        states.push(s);
    }

    states
}
