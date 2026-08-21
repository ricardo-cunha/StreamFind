use std::{
    collections::BTreeSet,
    fs,
    io::Read,
    path::{Path, PathBuf},
};

use crate::reader::{ReaderError, Result};

#[derive(Debug, Clone)]
pub struct ScanBlock {
    pub sample_number: u32,
    pub offset: usize,
    pub bytes: Vec<u8>,
}

#[derive(Debug, Clone)]
pub struct IdxRecord {
    pub sample_number: u32,
    pub scan_offset: u32,
    pub scan_size: u32,
    pub retention_time_minutes: f32,
    pub ms_level_flag: u8,
    pub tic: f64,
    pub grid_field: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ScanPoint {
    pub raw_mz_bin: u32,
    pub raw_intensity: u32,
}

#[derive(Debug, Clone)]
pub struct IndexedFloatRecord {
    pub index: IdxRecord,
    pub fields: Vec<f32>,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CompactMrmPair {
    pub first_intensity: f32,
    pub second_intensity: f32,
}

#[derive(Debug, Clone)]
pub struct MrmExperimentSeries {
    pub experiment_index: usize,
    pub transitions: Vec<Transition>,
    pub retention_times: Vec<Vec<f32>>,
    pub intensities: Vec<Vec<f32>>,
}

#[derive(Debug, Clone)]
pub struct EventRecord {
    pub ordinal: usize,
    pub retention_time_minutes: f32,
    pub fields: Vec<f32>,
}

#[derive(Debug, Clone)]
pub struct IntensityGroup {
    pub field_code: i32,
    pub intensities: Vec<f32>,
}

#[derive(Debug, Clone)]
pub struct Transition {
    pub name: String,
    pub precursor_mz: f32,
    pub product_mz: f32,
    pub start_time: f32,
    pub end_time: f32,
    pub collision_energy: f32,
}

fn read_u32(bytes: &[u8], offset: usize) -> Result<u32> {
    let slice = bytes
        .get(offset..offset + 4)
        .ok_or_else(|| ReaderError::Invalid("Sciex stream contains a truncated uint32".into()))?;
    Ok(u32::from_le_bytes(slice.try_into().unwrap()))
}

fn read_f32(bytes: &[u8], offset: usize) -> Result<f32> {
    Ok(f32::from_bits(read_u32(bytes, offset)?))
}

fn read_f64(bytes: &[u8], offset: usize) -> Result<f64> {
    let slice = bytes
        .get(offset..offset + 8)
        .ok_or_else(|| ReaderError::Invalid("Sciex stream contains a truncated float64".into()))?;
    Ok(f64::from_le_bytes(slice.try_into().unwrap()))
}

fn normalize_stream_path(path: &str) -> String {
    path.trim_start_matches('/')
        .replace('\\', "/")
        .to_ascii_lowercase()
}

fn read_stream(path: &Path, wanted: &str) -> Result<Vec<u8>> {
    let mut file = cfb::open(path)?;
    let wanted = normalize_stream_path(wanted);
    let stream_path = file
        .walk()
        .find(|entry| {
            entry.is_stream()
                && normalize_stream_path(&entry.path().to_string_lossy()) == wanted
        })
        .map(|entry| entry.path().to_string_lossy().to_string())
        .ok_or_else(|| ReaderError::Invalid(format!("Sciex stream not found: {wanted}")))?;
    let mut stream = file.open_stream(format!("/{}", stream_path.trim_start_matches('/')))?;
    let mut bytes = Vec::new();
    stream.read_to_end(&mut bytes)?;
    Ok(bytes)
}

pub fn scan_path_for_wiff(path: &Path) -> PathBuf {
    path.with_extension("wiff.scan")
}

fn sample_block_offset(path: &Path, sample_number: u32) -> Result<usize> {
    let bytes = fs::read(scan_path_for_wiff(path))?;
    for offset in (0..=bytes.len().saturating_sub(12)).step_by(4) {
        if read_u32(&bytes, offset)? == 0x11111111
            && read_u32(&bytes, offset + 8)? == sample_number
        {
            return Ok(offset);
        }
    }
    Err(ReaderError::Invalid("Sciex WIFF sample block is missing".into()))
}

pub fn read_idx_records(path: &Path, source_analysis_number: usize) -> Result<Vec<IdxRecord>>
{
    let bytes = read_stream(path, &format!("SampleSubtree/Sample{source_analysis_number}/Idx"))?;
    const HEADER: usize = 32;
    const RECORD: usize = 54;
    if bytes.len() < HEADER {
        return Err(ReaderError::Invalid("Sciex WIFF Idx stream is too short".into()));
    }
    let mut records = Vec::new();
    for offset in (HEADER..=bytes.len().saturating_sub(RECORD)).step_by(RECORD) {
        let scan_size = read_u32(&bytes, offset + 4)?;
        if scan_size <= 56 { continue; }
        records.push(IdxRecord {
            sample_number: source_analysis_number as u32,
            scan_offset: read_u32(&bytes, offset)?,
            scan_size,
            retention_time_minutes: read_f32(&bytes, offset + 12)?,
            ms_level_flag: bytes[offset + 16],
            tic: read_f64(&bytes, offset + 18)?,
            grid_field: read_f64(&bytes, offset + 26)?,
        });
    }
    if records.is_empty() {
        return Err(ReaderError::Invalid("Sciex WIFF Idx contains no valid records".into()));
    }
    Ok(records)
}

pub fn decode_scan_payload(payload: &[u8]) -> Vec<ScanPoint> {
    let mut points = Vec::new();
    let mut mz_bin = 0u32;
    let mut offset = 0usize;
    while offset < payload.len() {
        let token = payload[offset];
        if token == 0xff && payload.get(offset + 1..offset + 4) == Some(&[0xff, 0xff, 0xff][..]) { break; }
        if token <= 0x7f { mz_bin = mz_bin.wrapping_add(token as u32); offset += 1; continue; }
        let (width, intensity) = match token {
            0x80..=0xfb => (1, (token & 0x7f) as u32),
            0xfc => (2, payload.get(offset + 1).copied().unwrap_or(0) as u32),
            0xfd => (3, u16::from_le_bytes([payload.get(offset + 1).copied().unwrap_or(0), payload.get(offset + 2).copied().unwrap_or(0)]) as u32),
            0xfe => (4, payload.get(offset + 1).copied().unwrap_or(0) as u32 | ((payload.get(offset + 2).copied().unwrap_or(0) as u32) << 8) | ((payload.get(offset + 3).copied().unwrap_or(0) as u32) << 16)),
            _ => (5, payload.get(offset + 1).copied().unwrap_or(0) as u32 | ((payload.get(offset + 2).copied().unwrap_or(0) as u32) << 8) | ((payload.get(offset + 3).copied().unwrap_or(0) as u32) << 16) | ((payload.get(offset + 4).copied().unwrap_or(0) as u32) << 24)),
        };
        if offset + width > payload.len() { break; }
        points.push(ScanPoint { raw_mz_bin: mz_bin, raw_intensity: intensity });
        offset += width;
    }
    points
}

pub fn read_scan_points(path: &Path, record: &IdxRecord, next: Option<&IdxRecord>) -> Result<Vec<ScanPoint>> {
    let bytes = fs::read(scan_path_for_wiff(path))?;
    let sample_base = sample_block_offset(path, record.sample_number)?;
    let payload_start = sample_base + record.scan_offset as usize + 56;
    let next_end = next.map_or(bytes.len(), |r| sample_base + r.scan_offset as usize + 64);
    let own_end = sample_base + record.scan_offset as usize + record.scan_size as usize + 64;
    let end = next_end.min(own_end).min(bytes.len());
    if end <= payload_start { return Ok(Vec::new()); }
    Ok(decode_scan_payload(&bytes[payload_start..end]))
}

pub fn read_idx_float_records(path: &Path, source_analysis_number: usize) -> Result<Vec<IndexedFloatRecord>> {
    let index_bytes = read_stream(path, &format!("SampleSubtree/Sample{source_analysis_number}/Idx"))?;
    let scan_bytes = fs::read(scan_path_for_wiff(path))?;
    const HEADER: usize = 32;
    const RECORD: usize = 54;
    if index_bytes.len() < HEADER {
        return Err(ReaderError::Invalid("Sciex WIFF Idx stream is too short".into()));
    }
    let mut records = Vec::new();
    for offset in (HEADER..=index_bytes.len().saturating_sub(RECORD)).step_by(RECORD) {
        let scan_offset = read_u32(&index_bytes, offset)?;
        let scan_size = read_u32(&index_bytes, offset + 4)?;
        let sample_base = sample_block_offset(path, source_analysis_number as u32)?;
        let global_offset = sample_base + scan_offset as usize;
        let end = global_offset + scan_size as usize;
        if end > scan_bytes.len() || scan_size % 4 != 0 { continue; }
        let index = IdxRecord {
            sample_number: source_analysis_number as u32,
            scan_offset,
            scan_size,
            retention_time_minutes: read_f32(&index_bytes, offset + 12)?,
            ms_level_flag: index_bytes[offset + 16],
            tic: read_f64(&index_bytes, offset + 18)?,
            grid_field: read_f64(&index_bytes, offset + 26)?,
        };
        let fields = (global_offset..end)
            .step_by(4)
            .map(|pos| read_f32(&scan_bytes, pos))
            .collect::<Result<Vec<_>>>()?;
        records.push(IndexedFloatRecord { index, fields });
    }
    if records.is_empty() {
        return Err(ReaderError::Invalid("Sciex WIFF contains no indexed float records".into()));
    }
    Ok(records)
}

pub fn read_idx_event_records(path: &Path, source_analysis_number: usize) -> Result<Vec<EventRecord>> {
    let fragments = read_idx_float_records(path, source_analysis_number)?;
    let mut records = Vec::new();
    for fragment in fragments {
        for value in fragment.fields {
            if (value + 59.01).abs() < 0.001 {
                records.push(EventRecord {
                    ordinal: records.len(),
                    retention_time_minutes: fragment.index.retention_time_minutes,
                    fields: Vec::new(),
                });
            } else if let Some(current) = records.last_mut() {
                current.fields.push(value);
            }
        }
    }
    Ok(records)
}

pub fn read_compact_mrm_pairs(path: &Path, source_analysis_number: usize) -> Result<Vec<CompactMrmPair>> {
    let fragments = read_idx_float_records(path, source_analysis_number)?;
    if fragments.len() < 4 || fragments.iter().any(|fragment| fragment.fields.len() != 2) {
        return Err(ReaderError::Invalid("Sciex compact MRM payload is not a two-channel stream".into()));
    }
    Ok(fragments[3..]
        .iter()
        .map(|fragment| CompactMrmPair { first_intensity: fragment.fields[0], second_intensity: fragment.fields[1] })
        .collect())
}

pub fn build_compact_mrm_series(
    experiment_index: usize,
    transitions: Vec<Transition>,
    pairs: &[CompactMrmPair],
) -> Result<MrmExperimentSeries> {
    if transitions.len() != 2 {
        return Err(ReaderError::Invalid("Compact MRM series requires exactly two transitions".into()));
    }
    let mut first = vec![0.0; 3];
    let mut second = vec![0.0; 3];
    first.extend(pairs.iter().map(|pair| pair.first_intensity));
    second.extend(pairs.iter().map(|pair| pair.second_intensity));
    let intensities = vec![first, second];
    let retention_times = transitions.iter().enumerate().map(|(index, transition)| {
        let count = intensities[index].len();
        (0..count).map(|point| {
            if transition.start_time == transition.end_time {
                point as f32 * (0.110 / 60.0)
            } else {
                let fraction = if count <= 1 { 0.0 } else { point as f32 / (count - 1) as f32 };
                transition.start_time + fraction * (transition.end_time - transition.start_time)
            }
        }).collect()
    }).collect();
    Ok(MrmExperimentSeries { experiment_index, transitions, retention_times, intensities })
}

pub fn read_compact_mrm_experiments(path: &Path, source_analysis_number: usize) -> Result<Vec<MrmExperimentSeries>> {
    let fragments = read_idx_float_records(path, source_analysis_number)?;
    let mut groups: Vec<Vec<IndexedFloatRecord>> = Vec::new();
    for fragment in fragments {
        if let Some(group) = groups.last_mut() {
            if group[0].fields.len() == fragment.fields.len() {
                group.push(fragment);
                continue;
            }
        }
        groups.push(vec![fragment]);
    }
    let mut out = Vec::new();
    for (experiment_index, group) in groups.into_iter().enumerate() {
        let width = group[0].fields.len();
        if width == 0 { continue; }
        let transitions = read_transitions_for_experiment(path, source_analysis_number, experiment_index, 0)?;
        if transitions.len() != width {
            return Err(ReaderError::Invalid(format!("SCIEX experiment {experiment_index} has {width} payload channels but {} transitions", transitions.len())));
        }
        let intensities = (0..width).map(|column| group.iter().map(|record| record.fields[column]).collect()).collect::<Vec<Vec<f32>>>();
        let retention_times = transitions.iter().enumerate().map(|(column, transition)| {
            let count = intensities[column].len();
            (0..count).map(|point| {
                let fraction = if count <= 1 { 0.0 } else { point as f32 / (count - 1) as f32 };
                transition.start_time + fraction * (transition.end_time - transition.start_time)
            }).collect()
        }).collect();
        out.push(MrmExperimentSeries { experiment_index, transitions, retention_times, intensities });
    }
    Ok(out)
}

pub fn read_scan_blocks(path: &Path) -> Result<Vec<ScanBlock>> {
    let bytes = fs::read(scan_path_for_wiff(path))?;
    let mut offsets = Vec::new();
    for offset in (0..bytes.len().saturating_sub(3)).step_by(4) {
        if bytes[offset..offset + 4] == 0x11111111u32.to_le_bytes() {
            offsets.push(offset);
        }
    }
    if offsets.is_empty() {
        return Err(ReaderError::Invalid(
            "Sciex WIFF scan contains no sample blocks".into(),
        ));
    }
    offsets
        .iter()
        .enumerate()
        .map(|(index, &offset)| {
            let end = offsets.get(index + 1).copied().unwrap_or(bytes.len());
            if end <= offset + 12 {
                return Err(ReaderError::Invalid(
                    "Sciex WIFF scan sample block is truncated".into(),
                ));
            }
            Ok(ScanBlock {
                sample_number: read_u32(&bytes, offset + 8)?,
                offset,
                bytes: bytes[offset..end].to_vec(),
            })
        })
        .collect()
}

fn first_utf16_string(bytes: &[u8]) -> String {
    for start in (0..bytes.len().saturating_sub(1)).step_by(2) {
        let mut candidate = String::new();
        for pair in bytes[start..].chunks_exact(2) {
            let c = pair[0];
            let high = pair[1];
            if c == 0 && high == 0 {
                break;
            }
            if high == 0 && (32..=126).contains(&c) {
                candidate.push(c as char);
            } else {
                break;
            }
        }
        if candidate.len() >= 2 {
            return candidate;
        }
    }
    String::new()
}

pub fn read_analysis_catalog(path: &Path) -> Result<Vec<crate::reader::Analysis>> {
    let file = cfb::open(path)?;
    let mut source_numbers = BTreeSet::new();
    for entry in file.walk() {
        if !entry.is_stream() {
            continue;
        }
        let normalized = normalize_stream_path(&entry.path().to_string_lossy());
        let Some(rest) = normalized.strip_prefix("samplesubtree/sample") else {
            continue;
        };
        let Some((number, suffix)) = rest.split_once('/') else {
            continue;
        };
        if suffix == "sampledabe/data" {
            if let Ok(number) = number.parse::<usize>() {
                source_numbers.insert(number);
            }
        }
    }
    drop(file);
    if source_numbers.is_empty() {
        return Err(ReaderError::Invalid(
            "Sciex WIFF contains no sample analysis metadata".into(),
        ));
    }
    let count = source_numbers.len();
    source_numbers
        .into_iter()
        .enumerate()
        .map(|(analysis_index, source_number)| {
            let stream = read_stream(
                path,
                &format!("SampleSubtree/Sample{source_number}/SampleDABE/DATA"),
            )?;
            let mut name = first_utf16_string(&stream);
            if name.is_empty() || name == "none" {
                name = format!("sample_{source_number}");
            }
            Ok(crate::reader::Analysis {
                analysis_index,
                source_analysis_number: Some(source_number),
                name,
                analysis_count: count,
            })
        })
        .collect()
}

pub fn read_event_records(block: &ScanBlock) -> Result<Vec<EventRecord>> {
    let mut markers = Vec::new();
    for offset in (24..block.bytes.len().saturating_sub(3)).step_by(4) {
        if (read_f32(&block.bytes, offset)? + 59.01).abs() < 0.001 {
            markers.push(offset);
        }
    }
    markers
        .iter()
        .enumerate()
        .map(|(ordinal, &offset)| {
            let end = markers
                .get(ordinal + 1)
                .copied()
                .unwrap_or(block.bytes.len());
            let mut fields = Vec::new();
            for pos in (offset + 4..end).step_by(4) {
                fields.push(read_f32(&block.bytes, pos)?);
            }
            Ok(EventRecord {
                ordinal,
                retention_time_minutes: 0.0,
                fields,
            })
        })
        .collect()
}

pub fn decode_intensity_groups(record: &EventRecord) -> Vec<IntensityGroup> {
    let mut groups = Vec::new();
    for &value in &record.fields {
        if value < 0.0 {
            groups.push(IntensityGroup {
                field_code: value.round() as i32,
                intensities: Vec::new(),
            });
        } else if let Some(group) = groups.last_mut() {
            group.intensities.push(value);
        }
    }
    groups.retain(|group| !group.intensities.is_empty());
    groups
}

fn utf16_name_start(bytes: &[u8], offset: usize) -> bool {
    offset >= 2 && bytes.get(offset + 1) == Some(&0) && bytes[offset - 2] < 32
}

fn read_transition_name(bytes: &[u8], offset: usize) -> (String, usize, bool, bool) {
    let mut name = String::new();
    let mut cursor = offset;
    while cursor + 1 < bytes.len() {
        let c = bytes[cursor];
        let high = bytes[cursor + 1];
        if c == 0 && high == 0 {
            break;
        }
        if high != 0 || !(32..=126).contains(&c) {
            break;
        }
        name.push(c as char);
        cursor += 2;
    }
    let quoted = name.starts_with('"');
    let prefixed = name.starts_with('*') || name.starts_with('&');
    while name.starts_with(['"', '*', '&', ' ']) {
        name.remove(0);
    }
    (name, cursor, quoted, prefixed)
}

pub fn read_transitions_for_experiment(path: &Path, source_analysis_number: usize, period: usize, experiment: usize) -> Result<Vec<Transition>> {
    let bytes = read_stream(
        path,
        &format!("MethodSubtree/Method1/DeviceMethod0/Period{period}/Experiment{experiment}/MassRangeEx/MassRangeEx"),
    )?;
    let mut transitions = Vec::new();
    let mut seen = BTreeSet::new();
    for offset in (0..bytes.len().saturating_sub(4)).step_by(2) {
        if !utf16_name_start(&bytes, offset) {
            continue;
        }
        let (name, cursor, quoted, prefixed) = read_transition_name(&bytes, offset);
        if name.len() < 3 || !seen.insert(name.clone()) {
            continue;
        }
        let field_offset = if quoted || prefixed { 20 } else { 22 };
        if offset < field_offset {
            continue;
        }
        let precursor = read_f32(&bytes, offset - field_offset)?.max(0.0);
        let product = read_f32(&bytes, offset - field_offset + 8)?.max(0.0);
        let ce_marker = [b'C', 0, b'E', 0, 0, 0];
        let end = (cursor + 80).min(bytes.len());
        let ce_start = bytes[cursor..end]
            .windows(ce_marker.len())
            .position(|window| window == ce_marker.as_slice())
            .map(|position| cursor + position);
        let Some(ce_start) = ce_start else {
            continue;
        };
        let collision_energy = read_f32(&bytes, ce_start + 8).unwrap_or(0.0);
        transitions.push(Transition {
            name,
            precursor_mz: precursor,
            product_mz: product,
            start_time: 0.0,
            end_time: 0.0,
            collision_energy,
        });
    }
    let times = match read_stream(
        path,
        &format!("SampleSubtree/Sample{source_analysis_number}/SampleDAM/sMRMPro_adw1/sMRMPro_adw_Times"),
    ) {
        Ok(times) => times,
        Err(_) => return Ok(transitions),
    };
    if times.len() >= 16 && (times.len() - 16) / 8 >= transitions.len() {
        for (index, transition) in transitions.iter_mut().enumerate() {
            let offset = 16 + (index + 2) * 8;
            transition.start_time = read_u32(&times, offset)? as f32 / 60000.0;
            transition.end_time = read_u32(&times, offset + 4)? as f32 / 60000.0;
        }
    }
    Ok(transitions)
}

pub fn read_transitions(path: &Path, source_analysis_number: usize) -> Result<Vec<Transition>> {
    read_transitions_for_experiment(path, source_analysis_number, 0, 0)
}
