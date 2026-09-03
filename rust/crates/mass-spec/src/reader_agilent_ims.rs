use std::fs;
use std::path::Path;

#[derive(Debug, Clone, PartialEq)]
pub struct FrameRecord {
    pub frame_id: i16,
    pub frame_method_id: i16,
    pub time_segment_id: i16,
    pub actuals_offset: i64,
    pub cycle_number: i16,
    pub first_nonzero_drift_bin: i16,
    pub frag_class: i16,
    pub frag_energy: f32,
    pub frame_base_abundance: f64,
    pub frame_base_drift_bin: i16,
    pub frame_base_ms_bin: i32,
    pub frame_scan_time_minutes: f64,
    pub frame_spec_abundance_limit: f64,
    pub frame_tic: f64,
    pub ims_field: f64,
    pub ims_pressure: f64,
    pub ims_temperature: f64,
    pub ims_trap_time: f64,
    pub isolation_start_mz: f64,
    pub isolation_mz: f64,
    pub isolation_end_mz: f64,
    pub last_nonzero_drift_bin: i16,
    pub mass_cal_offset: i64,
    pub num_transients: i16,
}

fn u16(bytes: &[u8], offset: usize) -> Result<u16, String> {
    bytes
        .get(offset..offset + 2)
        .and_then(|v| v.try_into().ok())
        .map(u16::from_le_bytes)
        .ok_or_else(|| "Agilent IMS 16-bit field is truncated".into())
}
fn i16(bytes: &[u8], offset: usize) -> Result<i16, String> {
    Ok(u16(bytes, offset)? as i16)
}
fn i32(bytes: &[u8], offset: usize) -> Result<i32, String> {
    bytes
        .get(offset..offset + 4)
        .and_then(|v| v.try_into().ok())
        .map(i32::from_le_bytes)
        .ok_or_else(|| "Agilent IMS 32-bit field is truncated".into())
}
fn i64(bytes: &[u8], offset: usize) -> Result<i64, String> {
    bytes
        .get(offset..offset + 8)
        .and_then(|v| v.try_into().ok())
        .map(i64::from_le_bytes)
        .ok_or_else(|| "Agilent IMS 64-bit field is truncated".into())
}
fn f32(bytes: &[u8], offset: usize) -> Result<f32, String> {
    Ok(f32::from_bits(u32::from_le_bytes(
        bytes
            .get(offset..offset + 4)
            .and_then(|v| v.try_into().ok())
            .ok_or_else(|| "Agilent IMS float field is truncated".to_string())?,
    )))
}
fn f64(bytes: &[u8], offset: usize) -> Result<f64, String> {
    Ok(f64::from_bits(u64::from_le_bytes(
        bytes
            .get(offset..offset + 8)
            .and_then(|v| v.try_into().ok())
            .ok_or_else(|| "Agilent IMS double field is truncated".to_string())?,
    )))
}

pub fn is_agilent_ion_mobility_directory(path: &Path) -> bool {
    path.is_dir()
        && path.join("AcqData/Contents.xml").is_file()
        && path.join("AcqData/MSScan.bin").is_file()
        && path.join("AcqData/MSProfile.bin").is_file()
        && path.join("AcqData/IMSFrame.bin").is_file()
        && path.join("AcqData/IMSFrame.xsd").is_file()
}

pub fn read_frame_records(path: impl AsRef<Path>) -> Result<Vec<FrameRecord>, String> {
    let path = path.as_ref();
    if !is_agilent_ion_mobility_directory(path) {
        return Err(format!(
            "Not an Agilent MassHunter ion-mobility directory: {}",
            path.display()
        ));
    }
    let bytes = fs::read(path.join("AcqData/IMSFrame.bin")).map_err(|error| error.to_string())?;
    const HEADER: usize = 76;
    const RECORD: usize = 130;
    if bytes.len() < HEADER || (bytes.len() - HEADER) % RECORD != 0 {
        return Err("Agilent IMSFrame.bin has an unsupported record layout".into());
    }
    let mut frames = Vec::with_capacity((bytes.len() - HEADER) / RECORD);
    for offset in (HEADER..bytes.len()).step_by(RECORD) {
        let frame = FrameRecord {
            frame_id: i16(&bytes, offset)?,
            frame_method_id: i16(&bytes, offset + 2)?,
            time_segment_id: i16(&bytes, offset + 4)?,
            actuals_offset: i64(&bytes, offset + 6)?,
            cycle_number: i16(&bytes, offset + 14)?,
            first_nonzero_drift_bin: i16(&bytes, offset + 16)?,
            frag_class: i16(&bytes, offset + 18)?,
            frag_energy: f32(&bytes, offset + 20)?,
            frame_base_abundance: f64(&bytes, offset + 24)?,
            frame_base_drift_bin: i16(&bytes, offset + 32)?,
            frame_base_ms_bin: i32(&bytes, offset + 34)?,
            frame_scan_time_minutes: f64(&bytes, offset + 38)?,
            frame_spec_abundance_limit: f64(&bytes, offset + 46)?,
            frame_tic: f64(&bytes, offset + 54)?,
            ims_field: f64(&bytes, offset + 62)?,
            ims_pressure: f64(&bytes, offset + 70)?,
            ims_temperature: f64(&bytes, offset + 78)?,
            ims_trap_time: f64(&bytes, offset + 86)?,
            isolation_start_mz: f64(&bytes, offset + 94)?,
            isolation_mz: f64(&bytes, offset + 102)?,
            isolation_end_mz: f64(&bytes, offset + 110)?,
            last_nonzero_drift_bin: i16(&bytes, offset + 118)?,
            mass_cal_offset: i64(&bytes, offset + 120)?,
            num_transients: i16(&bytes, offset + 128)?,
        };
        if frames
            .last()
            .is_some_and(|previous: &FrameRecord| frame.frame_id <= previous.frame_id)
        {
            return Err("Agilent IMSFrame.bin frame IDs are not increasing".into());
        }
        frames.push(frame);
    }
    Ok(frames)
}

#[derive(Debug, Clone)]
pub struct ScanRecord {
    pub scan_id: u32,
    pub frame_id: i16,
    pub drift_bin: i16,
    pub tic: f64,
    pub base_peak_abundance: f64,
    pub base_peak_mz: f64,
    pub profile_format_id: i16,
    pub profile_byte_count: u32,
    pub profile_offset: u64,
    pub profile_point_count: u32,
    pub scan_time_minutes: f64,
    pub mobility: f64,
}

#[derive(Debug, Clone)]
pub struct ProfileSpectrum {
    pub mz: Vec<f32>,
    pub intensity: Vec<f32>,
}

fn u32_le(bytes: &[u8], offset: usize) -> Result<u32, String> {
    bytes
        .get(offset..offset + 4)
        .and_then(|value| value.try_into().ok())
        .map(u32::from_le_bytes)
        .ok_or_else(|| "Agilent IMS 32-bit field is truncated".into())
}

fn u64_le(bytes: &[u8], offset: usize) -> Result<u64, String> {
    bytes
        .get(offset..offset + 8)
        .and_then(|value| value.try_into().ok())
        .map(u64::from_le_bytes)
        .ok_or_else(|| "Agilent IMS 64-bit field is truncated".into())
}

fn xml_value(xml: &str, tag: &str) -> Result<f64, String> {
    let start_tag = format!("<{tag}>");
    let end_tag = format!("</{tag}>");
    let start = xml
        .find(&start_tag)
        .ok_or_else(|| format!("Agilent IMS XML has no {tag}"))?
        + start_tag.len();
    let end = xml[start..]
        .find(&end_tag)
        .ok_or_else(|| format!("Agilent IMS XML has incomplete {tag}"))?
        + start;
    xml[start..end]
        .trim()
        .parse()
        .map_err(|error| format!("Invalid Agilent IMS {tag}: {error}"))
}

fn calibration(path: &Path) -> Result<(f64, f64, f64, f64, Vec<f64>, u32), String> {
    let xml = fs::read_to_string(path.join("AcqData/DefaultMassCal.xml"))
        .map_err(|error| error.to_string())?;
    let start = xml
        .find(r#"<DefaultCalibration DefaultCalibrationID="1">"#)
        .ok_or_else(|| "Agilent DefaultMassCal.xml has no calibration ID 1".to_string())?;
    let end = xml[start..]
        .find("</DefaultCalibration>")
        .ok_or_else(|| "Agilent DefaultMassCal.xml calibration is incomplete".to_string())?
        + start;
    let section = &xml[start..end];
    let traditional_start = section
        .find("<CalibrationFormula>Traditional</CalibrationFormula>")
        .ok_or_else(|| "Agilent default calibration has no traditional step".to_string())?;
    let step_start = section[..traditional_start]
        .rfind("<Step")
        .ok_or_else(|| "Agilent traditional calibration step is incomplete".to_string())?;
    let step_end = section[traditional_start..]
        .find("</Step>")
        .ok_or_else(|| "Agilent traditional calibration step is incomplete".to_string())?
        + traditional_start;
    let traditional = &section[step_start..step_end];
    let mut values = Vec::new();
    let mut cursor = 0;
    while let Some(value_start) = traditional[cursor..].find("<Value ") {
        let value_start = cursor + value_start;
        let content_start = traditional[value_start..].find('>').unwrap() + value_start + 1;
        let content_end = traditional[content_start..].find("</Value>").unwrap() + content_start;
        values.push(
            traditional[content_start..content_end]
                .trim()
                .parse::<f64>()
                .map_err(|error| error.to_string())?,
        );
        cursor = content_end + 8;
    }
    if values.len() < 2 {
        return Err("Agilent traditional calibration is missing coefficients".into());
    }
    let polynomial_start = section
        .find("<CalibrationFormula>Polynomial</CalibrationFormula>")
        .ok_or_else(|| "Agilent default calibration has no polynomial step".to_string())?;
    let polynomial_step_start = section[..polynomial_start].rfind("<Step").unwrap();
    let polynomial_step_end =
        section[polynomial_start..].find("</Step>").unwrap() + polynomial_start;
    let polynomial = &section[polynomial_step_start..polynomial_step_end];
    let mut coefficients = Vec::new();
    cursor = 0;
    while let Some(value_start) = polynomial[cursor..].find("<Value ") {
        let value_start = cursor + value_start;
        let content_start = polynomial[value_start..].find('>').unwrap() + value_start + 1;
        let content_end = polynomial[content_start..].find("</Value>").unwrap() + content_start;
        coefficients.push(
            polynomial[content_start..content_end]
                .trim()
                .parse::<f64>()
                .map_err(|error| error.to_string())?,
        );
        cursor = content_end + 8;
    }
    let flags_start = polynomial.find("<ValueUseFlags>").unwrap() + 15;
    let flags_end = polynomial[flags_start..].find("</ValueUseFlags>").unwrap() + flags_start;
    let flags = polynomial[flags_start..flags_end]
        .trim()
        .parse::<u32>()
        .map_err(|error| error.to_string())?;
    if coefficients.len() < 2 {
        coefficients.resize(2, 0.0);
    }
    let left = coefficients[0];
    let right = coefficients[1];
    coefficients.drain(0..2);
    coefficients.resize(6, 0.0);
    Ok((values[0], values[1], left, right, coefficients, flags))
}

pub fn read_scan_records(path: impl AsRef<Path>) -> Result<Vec<ScanRecord>, String> {
    let path = path.as_ref();
    let bytes = fs::read(path.join("AcqData/MSScan.bin")).map_err(|error| error.to_string())?;
    let header = u32_le(&bytes, 88)? as usize;
    const STRIDE: usize = 106;
    if header > bytes.len() || (bytes.len() - header) % STRIDE != 0 {
        return Err("Agilent IMS MSScan.bin has an unsupported record layout".into());
    }
    let frames = read_frame_records(path)?;
    let period = xml_value(
        &fs::read_to_string(path.join("AcqData/IMSFrameMeth.xml"))
            .map_err(|error| error.to_string())?,
        "FrameDtPeriod",
    )?;
    Ok((header..bytes.len())
        .step_by(STRIDE)
        .map(|offset| ScanRecord {
            scan_id: u32_le(&bytes, offset).unwrap(),
            frame_id: i16(&bytes, offset + 4).unwrap(),
            drift_bin: i16(&bytes, offset + 16).unwrap(),
            tic: f64(&bytes, offset + 26).unwrap(),
            base_peak_abundance: f64(&bytes, offset + 34).unwrap(),
            base_peak_mz: f64(&bytes, offset + 42).unwrap(),
            profile_format_id: i16(&bytes, offset + 50).unwrap(),
            profile_byte_count: u32_le(&bytes, offset + 52).unwrap(),
            profile_offset: u64_le(&bytes, offset + 56).unwrap(),
            profile_point_count: u32_le(&bytes, offset + 64).unwrap(),
            scan_time_minutes: {
                let frame = i16(&bytes, offset + 4).unwrap();
                if frame > 0 {
                    frames
                        .get(frame as usize - 1)
                        .map(|value| value.frame_scan_time_minutes)
                        .unwrap_or(0.0)
                } else {
                    0.0
                }
            },
            mobility: i16(&bytes, offset + 16).unwrap() as f64 * period,
        })
        .collect())
}

pub fn read_profile_spectrum(
    path: impl AsRef<Path>,
    record: &ScanRecord,
) -> Result<ProfileSpectrum, String> {
    let path = path.as_ref();
    let bytes = fs::read(path.join("AcqData/MSProfile.bin")).map_err(|error| error.to_string())?;
    let start = record.profile_offset as usize;
    let end = start
        .checked_add(record.profile_byte_count as usize)
        .ok_or_else(|| "Agilent IMS profile block overflows".to_string())?;
    let block = bytes
        .get(start..end)
        .ok_or_else(|| "Agilent IMS profile block is truncated".to_string())?;
    if record.profile_format_id != 1 && record.profile_format_id != 2 {
        return Err(format!(
            "Agilent IMS scan has unsupported profile format ID: {}",
            record.profile_format_id
        ));
    }
    if block.len() < 24
        || u32_le(block, 16)? >> 24 != 0x90
        || (u32_le(block, 16)? & 0x00ff_ffff) != record.profile_point_count
    {
        return Err("Agilent IMS profile block is not the validated RLE format".into());
    }
    let mut intensities = vec![0u32; record.profile_point_count as usize];
    let initial = i32(&block, 20)?;
    if initial > 0 {
        return Err("Agilent IMS profile has an invalid leading-zero count".into());
    }
    let mut output = (-initial) as usize;
    let mut input = 24;
    let mut width = 4usize;
    while input < block.len() {
        if input + width > block.len() {
            return Err("Agilent IMS profile RLE token is truncated".into());
        }
        let value = match width {
            1 => block[input] as i8 as i64,
            2 => i16(block, input)? as i64,
            4 => i32(block, input)? as i64,
            _ => return Err("Agilent IMS profile RLE has an invalid width".into()),
        };
        input += width;
        if value >= 0 {
            if output >= intensities.len() {
                return Err("Agilent IMS profile RLE exceeds point count".into());
            }
            intensities[output] = value as u32;
            output += 1;
        } else {
            let encoded = -value;
            output = output
                .checked_add((encoded / 4) as usize)
                .ok_or_else(|| "Agilent IMS profile RLE overflows".to_string())?;
            width = match encoded % 4 {
                1 => 1,
                2 => 2,
                3 => 4,
                _ => return Err("Agilent IMS profile RLE has an invalid width flag".into()),
            };
            if output > intensities.len() {
                return Err("Agilent IMS profile RLE exceeds point count".into());
            }
        }
    }
    let raw_start = f64(&block, 0)?;
    let raw_delta = f64(&block, 8)?;
    let (coeff, base, left, right, polynomial, flags) = calibration(path)?;
    let highest = 31 - flags.leading_zeros();
    let mut mz = Vec::with_capacity(intensities.len());
    for index in 0..intensities.len() {
        let tof = raw_start + (index as f64 - 1.0) * raw_delta;
        let mut value = (coeff * (tof - base)).powi(2);
        if flags != 0 {
            let clipped = tof.clamp(left, right);
            let mut correction = 0.0;
            for order in (0..=highest).rev() {
                let coefficient = if flags & (1 << order) != 0 {
                    polynomial[(0..order)
                        .filter(|candidate| flags & (1 << candidate) != 0)
                        .count()]
                } else {
                    0.0
                };
                correction = correction * clipped + coefficient;
            }
            value -= correction;
        }
        mz.push(value as f32);
    }
    Ok(ProfileSpectrum {
        mz,
        intensity: intensities.into_iter().map(|value| value as f32).collect(),
    })
}
