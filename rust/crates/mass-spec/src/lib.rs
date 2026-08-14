use std::path::Path;

use serde_json::{json, Value};
use streamfind_rust_core::{
    Error, ErrorCode, Operation, OperationRegistry, ParameterDefinition, ParameterSchema,
    ParameterType, Project, Result, TypeDescriptor,
};

pub mod reader;

const ANALYSES_SCHEMA: &str = "CREATE TABLE IF NOT EXISTS MASS_SPEC_ANALYSES (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, replicate VARCHAR, blank VARCHAR, file_name VARCHAR, file_path VARCHAR NOT NULL, file_dir VARCHAR, file_extension VARCHAR, format VARCHAR, number_spectra INTEGER, number_chromatograms INTEGER, number_spectra_binary_arrays INTEGER, min_mz DOUBLE, max_mz DOUBLE, start_rt DOUBLE, end_rt DOUBLE, has_ion_mobility BOOLEAN, PRIMARY KEY(project_id, analysis))";
const SPECTRA_HEADERS_SCHEMA: &str = "CREATE TABLE IF NOT EXISTS MASS_SPEC_SPECTRA_HEADERS (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, index INTEGER NOT NULL, scan INTEGER, array_length INTEGER, level INTEGER, mode INTEGER, polarity INTEGER, configuration INTEGER, lowmz DOUBLE, highmz DOUBLE, bpmz DOUBLE, bpint DOUBLE, tic DOUBLE, rt DOUBLE, mobility DOUBLE, window_mz DOUBLE, window_mzlow DOUBLE, window_mzhigh DOUBLE, precursor_mz DOUBLE, precursor_intensity DOUBLE, precursor_charge INTEGER, activation_ce DOUBLE, PRIMARY KEY(project_id, analysis, index))";
const CHROMATOGRAMS_HEADERS_SCHEMA: &str = "CREATE TABLE IF NOT EXISTS MASS_SPEC_CHROMATOGRAMS_HEADERS (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, index INTEGER NOT NULL, chromatogram_id VARCHAR, array_length INTEGER, polarity INTEGER, precursor_mz DOUBLE, activation_ce DOUBLE, product_mz DOUBLE, signal_type VARCHAR, chromatogram_type VARCHAR, detector VARCHAR, channel VARCHAR, units VARCHAR, wavelength_nm DOUBLE, interval_ms DOUBLE, start_time DOUBLE, end_time DOUBLE, intensity_multiplier DOUBLE, PRIMARY KEY(project_id, analysis, index))";

fn sql(value: &str) -> String {
    format!("'{}'", value.replace('\'', "''"))
}

fn ensure_schema(project: &Project) -> Result<()> {
    project.execute_sql(ANALYSES_SCHEMA)?;
    project.execute_sql(SPECTRA_HEADERS_SCHEMA)?;
    project.execute_sql(CHROMATOGRAMS_HEADERS_SCHEMA)?;
    Ok(())
}

fn invalid(message: impl Into<String>) -> Error {
    Error::new(ErrorCode::InvalidArgument, message)
}

fn format_name(format: reader::Format) -> &'static str {
    match format {
        reader::Format::MzMl => "mzML",
        reader::Format::MzXml => "mzXML",
        reader::Format::Asc => "ASC",
        reader::Format::ShimadzuLcd => "ShimadzuLCD",
    }
}

fn add_analyses(project: &mut Project, parameters: &Value) -> Result<Value> {
    ensure_schema(project)?;
    let analyses = parameters
        .get("analyses")
        .and_then(Value::as_array)
        .ok_or_else(|| invalid("analyses must be an array"))?;
    let mut added = Vec::new();
    for item in analyses {
        let path_string = item
            .get("path")
            .and_then(Value::as_str)
            .ok_or_else(|| invalid("analysis.path is required"))?;
        let path = Path::new(path_string);
        let reader = reader::Reader::open(path)
            .map_err(|error| Error::new(ErrorCode::InvalidArgument, error.to_string()))?;
        let summary = reader.summary();
        let analysis = path
            .file_stem()
            .and_then(|value| value.to_str())
            .unwrap_or_default();
        if analysis.is_empty() {
            return Err(invalid("analysis path has no file stem"));
        }
        let replicate = item
            .get("replicate_name")
            .and_then(Value::as_str)
            .unwrap_or_default();
        let blank = item
            .get("blank_name")
            .and_then(Value::as_str)
            .unwrap_or_default();
        let file_name = path
            .file_name()
            .and_then(|value| value.to_str())
            .unwrap_or_default();
        let file_dir = path
            .parent()
            .map(|value| value.to_string_lossy())
            .unwrap_or_default();
        let extension = path
            .extension()
            .and_then(|value| value.to_str())
            .unwrap_or_default();
        let query = format!("INSERT OR REPLACE INTO MASS_SPEC_ANALYSES VALUES ({},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{})", sql(project.get_project_id()), sql(analysis), sql(replicate), sql(blank), sql(file_name), sql(path_string), sql(file_dir.as_ref()), sql(extension), sql(format_name(summary.format)), summary.number_spectra, summary.number_chromatograms, summary.number_spectra_binary_arrays, summary.min_mz, summary.max_mz, summary.start_rt, summary.end_rt, summary.has_ion_mobility);
        project.execute_sql(&query)?;
        added.push(json!({"analysis": analysis, "file_path": path_string, "replicate_name": replicate, "blank_name": blank}));
    }
    Ok(Value::Array(added))
}

fn remove_analyses(project: &mut Project, parameters: &Value) -> Result<Value> {
    ensure_schema(project)?;
    let names = parameters
        .get("analysis_names")
        .and_then(Value::as_array)
        .ok_or_else(|| invalid("analysis_names must be an array"))?;
    let mut removed = Vec::new();
    for name in names {
        let name = name
            .as_str()
            .ok_or_else(|| invalid("analysis_names must contain strings"))?;
        project.execute_sql(&format!(
            "DELETE FROM MASS_SPEC_ANALYSES WHERE project_id = {} AND analysis = {}",
            sql(project.get_project_id()),
            sql(name)
        ))?;
        removed.push(name);
    }
    Ok(json!(removed))
}

fn get_analyses_info(project: &Project) -> Result<Value> {
    ensure_schema(project)?;
    project.query_json(&format!("SELECT analysis, replicate, blank, file_path, format, number_spectra, number_chromatograms FROM MASS_SPEC_ANALYSES WHERE project_id = {} ORDER BY analysis", sql(project.get_project_id())))
}

pub fn register_operations(registry: &mut OperationRegistry) -> Result<()> {
    registry.register(Operation::new(
        "mass_spec.add_analyses",
        "mass_spec.add_analyses",
        "Mass spectrometry project operation",
        "mass_spec",
        ParameterSchema {
            definitions: vec![ParameterDefinition {
                name: "analyses".into(),
                description: "Analysis file records or names".into(),
                kind: TypeDescriptor::array(TypeDescriptor::scalar(ParameterType::Object)),
                default: None,
                required: true,
            }],
        },
        Box::new(add_analyses),
    ))?;
    registry.register(Operation::new(
        "mass_spec.remove_analyses",
        "mass_spec.remove_analyses",
        "Mass spectrometry project operation",
        "mass_spec",
        ParameterSchema {
            definitions: vec![ParameterDefinition {
                name: "analysis_names".into(),
                description: "Analysis names".into(),
                kind: TypeDescriptor::array(TypeDescriptor::scalar(ParameterType::String)),
                default: None,
                required: true,
            }],
        },
        Box::new(remove_analyses),
    ))?;
    registry.register(Operation::new(
        "mass_spec.get_analyses_info",
        "mass_spec.get_analyses_info",
        "Mass spectrometry project operation",
        "mass_spec",
        ParameterSchema {
            definitions: vec![],
        },
        Box::new(|project, _| get_analyses_info(project)),
    ))?;
    Ok(())
}
