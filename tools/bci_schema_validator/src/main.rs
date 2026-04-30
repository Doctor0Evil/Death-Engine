// target-repo: Death-Engine
// file: tools/bci_schema_validator/src/main.rs

use clap::Parser;
use serde_json::{Value, from_str};
use jsonschema::JSONSchema;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(author, version, about = "Validate BCI NDJSON files against JSON schemas")]
struct Args {
    /// Path to JSON schema file
    #[arg(short, long)]
    schema: PathBuf,
    
    /// Path to NDJSON input file (one JSON object per line)
    #[arg(short, long)]
    input: PathBuf,
    
    /// Fail on first error (default: report all errors)
    #[arg(short, long, default_value_t = false)]
    fail_fast: bool,
    
    /// Output detailed validation report
    #[arg(short, long, default_value_t = false)]
    verbose: bool,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    
    // Load and compile schema
    let schema_content = std::fs::read_to_string(&args.schema)?;
    let schema: Value = from_str(&schema_content)?;
    let validator = JSONSchema::compile(&schema)
        .map_err(|e| format!("Schema compilation failed: {}", e))?;
    
    // Open input file
    let file = File::open(&args.input)?;
    let reader = BufReader::new(file);
    
    let mut line_num = 0;
    let mut errors = 0;
    let mut warnings = 0;
    
    for line in reader.lines() {
        line_num += 1;
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        
        // Parse JSON object
        let obj: Value = match from_str(&line) {
            Ok(v) => v,
            Err(e) => {
                eprintln!("Line {}: JSON parse error: {}", line_num, e);
                errors += 1;
                if args.fail_fast {
                    std::process::exit(1);
                }
                continue;
            }
        };
        
        // Validate against schema
        if let Err(err_iter) = validator.validate(&obj) {
            for error in err_iter {
                if args.verbose {
                    eprintln!("Line {} validation error: {}", line_num, error);
                } else {
                    eprintln!("Line {}: {}", line_num, error.instance_path);
                }
                errors += 1;
            }
            if args.fail_fast {
                std::process::exit(1);
            }
        } else if args.verbose {
            println!("Line {}: valid", line_num);
        }
        
        // Additional range checks for BCI-specific constraints
        if let Some(metrics) = obj.get("metrics") {
            if let Some(uec) = metrics.get("uecBand").and_then(|v| v.as_f64()) {
                if uec < 0.0 || uec > 1.0 {
                    eprintln!("Line {}: uecBand out of range [0,1]: {}", line_num, uec);
                    errors += 1;
                }
            }
        }
        
        if let Some(det) = obj.get("safety").and_then(|s| s.get("detEstimate")).and_then(|v| v.as_f64()) {
            if det < 0.0 || det > 10.0 {
                eprintln!("Line {}: detEstimate out of range [0,10]: {}", line_num, det);
                errors += 1;
            }
        }
    }
    
    // Summary
    println!("\nValidation complete:");
    println!("  Lines processed: {}", line_num);
    println!("  Errors: {}", errors);
    println!("  Warnings: {}", warnings);
    
    if errors > 0 {
        std::process::exit(1);
    }
    
    Ok(())
}
