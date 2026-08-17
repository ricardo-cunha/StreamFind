use regex::Regex;
use serde_json::{json, Value};
use streamfind_rust_core::{Error, ErrorCode, Project, Result};

use crate::reader;

const TABLE: &str = "CREATE TABLE IF NOT EXISTS MASS_SPEC_CHROMATOGRAMS (project_id TEXT NOT NULL, analysis TEXT NOT NULL, chromatogram_id TEXT NOT NULL, rt DOUBLE NOT NULL, raw_intensity DOUBLE NOT NULL, baseline DOUBLE NOT NULL DEFAULT 0, intensity DOUBLE NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, analysis, chromatogram_id, rt))";

#[derive(Debug, Clone, Default)]
pub struct LoadChromatogramsRequest {
    pub analyses: Vec<String>,
    pub chromatogram_id_regex: Vec<String>,
    pub ignore_case: bool,
    pub invert: bool,
}

#[derive(Debug, Clone, Default)]
pub struct FilterChromatogramsRetentionTimeRequest {
    pub analyses: Vec<String>,
    pub rtmin: f64,
    pub rtmax: f64,
}

fn invalid(message: impl Into<String>) -> Error {
    Error::new(ErrorCode::InvalidArgument, message)
}

fn sql(value: &str) -> String {
    format!("'{}'", value.replace('\'', "''"))
}

fn analyses(project: &Project, wanted: &[String]) -> Result<Vec<(String, String)>> {
    let rows = project.query_json(&format!(
        "SELECT analysis, file_path FROM MASS_SPEC_ANALYSES WHERE project_id = {} ORDER BY analysis",
        sql(project.get_project_id())
    ))?;
    let rows = rows.as_array().cloned().unwrap_or_default();
    let selected = rows
        .into_iter()
        .filter_map(|row| {
            let name = row["analysis"].as_str()?.to_owned();
            (wanted.is_empty() || wanted.iter().any(|value| value == &name)).then(|| {
                (
                    name,
                    row["file_path"].as_str().unwrap_or_default().to_owned(),
                )
            })
        })
        .collect::<Vec<_>>();
    if selected.is_empty() {
        return Err(invalid("No analyses available for loading chromatograms."));
    }
    Ok(selected)
}

fn matches(id: &str, patterns: &[Regex]) -> bool {
    patterns.iter().any(|pattern| pattern.is_match(id))
}

pub fn load_chromatograms(
    project: &mut Project,
    request: &LoadChromatogramsRequest,
) -> Result<bool> {
    project.execute_sql(TABLE)?;
    let patterns = request
        .chromatogram_id_regex
        .iter()
        .filter_map(|pattern| {
            let pattern = if request.ignore_case {
                format!("(?i){pattern}")
            } else {
                pattern.clone()
            };
            Regex::new(&pattern).ok()
        })
        .collect::<Vec<_>>();
    for (analysis, path) in analyses(project, &request.analyses)? {
        let file = reader::Reader::open(path).map_err(|error| invalid(error.to_string()))?;
        for chromatogram in file
            .chromatograms()
            .iter()
            .filter(|chromatogram| matches(&chromatogram.id, &patterns) ^ request.invert)
        {
            let count = chromatogram.time.len().min(chromatogram.intensity.len());
            if count == 0 {
                continue;
            }
            let mut statements = format!(
                "DELETE FROM MASS_SPEC_CHROMATOGRAMS WHERE project_id = {} AND analysis = {} AND chromatogram_id = {}",
                sql(project.get_project_id()), sql(&analysis), sql(&chromatogram.id)
            );
            statements.push(';');
            for (rt, intensity) in chromatogram
                .time
                .iter()
                .zip(&chromatogram.intensity)
                .take(count)
            {
                statements.push_str(&format!(
                    "INSERT INTO MASS_SPEC_CHROMATOGRAMS (project_id, analysis, chromatogram_id, rt, raw_intensity, baseline, intensity) VALUES ({},{},{},{},{},0,{})",
                    sql(project.get_project_id()), sql(&analysis), sql(&chromatogram.id), *rt as f64, *intensity as f64, *intensity as f64
                ));
                statements.push(';');
            }
            project.execute_sql(&statements)?;
        }
    }
    Ok(true)
}

pub fn filter_chromatograms_retention_time(
    project: &mut Project,
    request: &FilterChromatogramsRetentionTimeRequest,
) -> Result<bool> {
    if request.rtmin >= request.rtmax {
        return Err(invalid("rtmin must be less than rtmax."));
    }
    project.execute_sql(TABLE)?;
    let analysis_filter = if request.analyses.is_empty() {
        String::new()
    } else {
        format!(
            " AND analysis IN ({})",
            request
                .analyses
                .iter()
                .map(|value| sql(value))
                .collect::<Vec<_>>()
                .join(",")
        )
    };
    let rows = project.query_json(&format!(
        "SELECT analysis, chromatogram_id, rt, raw_intensity, baseline, intensity FROM MASS_SPEC_CHROMATOGRAMS WHERE project_id = {}{} AND rt >= {} AND rt <= {} ORDER BY chromatogram_id, rt",
        sql(project.get_project_id()), analysis_filter, request.rtmin, request.rtmax
    ))?;
    let mut grouped = std::collections::BTreeMap::<(String, String), Vec<&Value>>::new();
    for row in rows.as_array().into_iter().flatten() {
        grouped
            .entry((
                row["analysis"].as_str().unwrap_or_default().into(),
                row["chromatogram_id"].as_str().unwrap_or_default().into(),
            ))
            .or_default()
            .push(row);
    }
    for ((analysis, id), selected) in grouped {
        let mut statements = format!("DELETE FROM MASS_SPEC_CHROMATOGRAMS WHERE project_id = {} AND analysis = {} AND chromatogram_id = {};", sql(project.get_project_id()), sql(&analysis), sql(&id));
        for row in selected {
            statements.push_str(&format!("INSERT INTO MASS_SPEC_CHROMATOGRAMS (project_id, analysis, chromatogram_id, rt, raw_intensity, baseline, intensity) VALUES ({},{},{},{},{},{},{}) ;", sql(project.get_project_id()), sql(&analysis), sql(&id), row["rt"], row["raw_intensity"], row["baseline"], row["intensity"]));
        }
        project.execute_sql(&statements)?;
    }
    Ok(true)
}

pub fn get_chromatograms(project: &mut Project, parameters: &Value) -> Result<Value> {
    project.execute_sql(TABLE)?;
    let wanted = parameters
        .get("analysis_names")
        .and_then(Value::as_array)
        .map(|values| {
            values
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_owned)
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    let filter = if wanted.is_empty() {
        String::new()
    } else {
        format!(
            " AND analysis IN ({})",
            wanted
                .iter()
                .map(|value| sql(value))
                .collect::<Vec<_>>()
                .join(",")
        )
    };
    project.query_json(&format!(
        "SELECT project_id, analysis, chromatogram_id, rt, raw_intensity, baseline, intensity FROM MASS_SPEC_CHROMATOGRAMS WHERE project_id = {}{} ORDER BY analysis, chromatogram_id, rt",
        sql(project.get_project_id()), filter
    ))
}

pub fn get_raw_chromatograms(project: &mut Project, parameters: &Value) -> Result<Value> {
    let wanted = parameters
        .get("analysis_names")
        .and_then(Value::as_array)
        .map(|values| {
            values
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_owned)
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    let indices = parameters
        .get("indices")
        .and_then(Value::as_array)
        .map(|values| {
            values
                .iter()
                .filter_map(Value::as_u64)
                .map(|value| value as usize)
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    let mut output = Vec::new();
    for (analysis, path) in analyses(project, &wanted)? {
        let file = reader::Reader::open(path).map_err(|error| invalid(error.to_string()))?;
        let selected = if indices.is_empty() {
            (0..file.chromatograms().len()).collect::<Vec<_>>()
        } else {
            indices
                .iter()
                .copied()
                .filter(|index| *index < file.chromatograms().len())
                .collect()
        };
        for index in selected {
            let chromatogram = &file.chromatograms()[index];
            for (rt, intensity) in chromatogram.time.iter().zip(&chromatogram.intensity) {
                output.push(json!({
                    "project_id": project.get_project_id(),
                    "analysis": analysis,
                    "chromatogram_id": chromatogram.id,
                    "rt": *rt as f64,
                    "raw_intensity": *intensity as f64,
                    "baseline": 0.0,
                    "intensity": *intensity as f64,
                }));
            }
        }
    }
    Ok(Value::Array(output))
}
