// tools/hpc-player-envelope-validate.rs

use std::fs::File;
use std::io::Read;

use serde_json::from_reader;

use hpc_player_envelope_fps::{PlayerEnvelopeCfg};
use hpc_player_envelope_fps::validate::validate_cfg;

fn main() {
    let path = std::env::args().nth(1).unwrap_or_else(|| "player-envelope-fps.json".to_string());
    let horizon: f32 = std::env::args()
        .nth(2)
        .unwrap_or_else(|| "3600".to_string())
        .parse()
        .unwrap_or(3600.0);

    let file = File::open(&path).expect("failed to open cfg");
    let cfg: PlayerEnvelopeCfg = from_reader(file).expect("invalid cfg JSON");

    let report = validate_cfg(&cfg, horizon);
    if !report.ok {
        eprintln!("H.PlayerEnvelope.FPS validation FAILED");
        for v in report.violations {
            eprintln!("{}", v);
        }
        std::process::exit(1);
    }

    println!("H.PlayerEnvelope.FPS validation OK");
}
