use std::fs;
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq)]
pub struct ScanRecord {
    pub scan_id: u32,
    pub scan_method_id: u32,
    pub time_segment_id: u32,
    pub scan_time_minutes: f64,
    pub ms_level: i32,
    pub scan_type: i32,
    pub tic: f64,
    pub base_peak_mz: f64,
    pub base_peak_value: f64,
    pub calibration_id: i32,
    pub cycle_number: i32,
    pub spectrum_format_id: u32,
    pub spectrum_offset: u64,
    pub spectrum_byte_count: u32,
    pub spectrum_point_count: u32,
    pub spectrum_uncompressed_byte_count: u32,
    pub spectrum_min_x: f64,
    pub spectrum_max_x: f64,
    pub spectrum_min_y: f64,
    pub spectrum_max_y: f64,
    pub spectrum_measured_noise: f64,
    pub centroid_format_id: u32,
    pub centroid_offset: u64,
    pub centroid_byte_count: u32,
    pub centroid_point_count: u32,
    pub record_index: usize,
    pub precursor_mz: f64,
    pub collision_energy: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ProfileSpectrum {
    pub mz: Vec<f64>,
    pub intensity: Vec<f32>,
}

const SCAN_PREAMBLE_SIZE: usize = 228;
const SCAN_RECORD_SIZES: [usize; 2] = [220, 284];
const PROFILE_BLOCK_PREAMBLE_SIZE: usize = 16;
const MAX_PROFILE_UNCOMPRESSED_SIZE: usize = 512 * 1024 * 1024;

pub fn is_agilent_mass_hunter_directory(path: &Path) -> bool {
    let acq = path.join("AcqData");
    path.is_dir()
        && acq.join("Contents.xml").is_file()
        && acq.join("MSScan.bin").is_file()
        && acq.join("MSProfile.bin").is_file()
}

fn u32_at(bytes: &[u8], offset: usize) -> Result<u32, String> {
    let slice = bytes
        .get(offset..offset + 4)
        .ok_or_else(|| "Agilent binary record is truncated".to_string())?;
    Ok(u32::from_le_bytes(slice.try_into().unwrap()))
}

fn f64_at(bytes: &[u8], offset: usize) -> Result<f64, String> {
    let slice = bytes
        .get(offset..offset + 8)
        .ok_or_else(|| "Agilent binary double field is truncated".to_string())?;
    Ok(f64::from_le_bytes(slice.try_into().unwrap()))
}

fn detect_scan_record_size(bytes: &[u8]) -> Result<usize, String> {
    SCAN_RECORD_SIZES
        .into_iter()
        .find(|size| {
            bytes.len() >= SCAN_PREAMBLE_SIZE && (bytes.len() - SCAN_PREAMBLE_SIZE) % size == 0
        })
        .ok_or_else(|| "Agilent MSScan.bin has an unsupported record layout".to_string())
}

fn decompress_lzf(input: &[u8], maximum_size: usize) -> Result<Vec<u8>, String> {
    if maximum_size > MAX_PROFILE_UNCOMPRESSED_SIZE {
        return Err("Agilent LZF profile block exceeds the decompression safety limit".to_string());
    }
    let mut output = vec![0u8; maximum_size];
    let (mut input_index, mut output_index) = (0usize, 0usize);
    while input_index < input.len() && output_index < output.len() {
        let control = input[input_index] as usize;
        input_index += 1;
        if control < 32 {
            let length = control + 1;
            if input_index + length > input.len() || output_index + length > output.len() {
                return Err("Agilent LZF literal run is outside the profile block".to_string());
            }
            output[output_index..output_index + length]
                .copy_from_slice(&input[input_index..input_index + length]);
            input_index += length;
            output_index += length;
            continue;
        }

        let mut length = control >> 5;
        let mut reference = output_index
            .checked_sub(((control & 31) << 8) + 1)
            .ok_or_else(|| "Agilent LZF back reference precedes profile output".to_string())?;
        if length == 7 {
            let extra = *input
                .get(input_index)
                .ok_or_else(|| "Agilent LZF profile block has a truncated length".to_string())?;
            length += extra as usize;
            input_index += 1;
        }
        let distance = *input
            .get(input_index)
            .ok_or_else(|| "Agilent LZF profile block has a truncated distance".to_string())?;
        input_index += 1;
        reference = reference
            .checked_sub(distance as usize)
            .ok_or_else(|| "Agilent LZF profile block has an invalid distance".to_string())?;
        length += 2;
        if output_index + length > output.len() {
            return Err("Agilent LZF match run exceeds profile output".to_string());
        }
        for _ in 0..length {
            output[output_index] = output[reference];
            output_index += 1;
            reference += 1;
        }
    }
    output.truncate(output_index);
    Ok(output)
}

pub fn read_scan_records(path: impl AsRef<Path>) -> Result<Vec<ScanRecord>, String> {
    let path = path.as_ref();
    if !is_agilent_mass_hunter_directory(path) {
        return Err(format!(
            "Not an Agilent MassHunter .d directory: {}",
            path.display()
        ));
    }
    let bytes = fs::read(PathBuf::from(path).join("AcqData/MSScan.bin"))
        .map_err(|error| error.to_string())?;
    let scan_record_size = detect_scan_record_size(&bytes)?;
    let mut records = Vec::with_capacity((bytes.len() - SCAN_PREAMBLE_SIZE) / scan_record_size);
    for offset in (SCAN_PREAMBLE_SIZE..bytes.len()).step_by(scan_record_size) {
        records.push(ScanRecord {
            scan_id: u32_at(&bytes, offset)?,
            scan_method_id: u32_at(&bytes, offset + 4)?,
            time_segment_id: u32_at(&bytes, offset + 8)?,
            scan_time_minutes: f64_at(&bytes, offset + 12)?,
            ms_level: u32_at(&bytes, offset + 20)? as i32,
            scan_type: u32_at(&bytes, offset + 24)? as i32,
            tic: f64_at(&bytes, offset + 28)?,
            base_peak_mz: f64_at(&bytes, offset + 36)?,
            base_peak_value: f64_at(&bytes, offset + 44)?,
            calibration_id: u32_at(&bytes, offset + 52)? as i32,
            cycle_number: u32_at(&bytes, offset + 56)? as i32,
            spectrum_format_id: u32_at(&bytes, offset + 156)?,
            spectrum_offset: u64::from_le_bytes(
                bytes[offset + 160..offset + 168].try_into().unwrap(),
            ),
            spectrum_byte_count: u32_at(&bytes, offset + 168)?,
            spectrum_point_count: u32_at(&bytes, offset + 172)?,
            spectrum_uncompressed_byte_count: u32_at(&bytes, offset + 176)?,
            spectrum_min_x: f64_at(&bytes, offset + 180)?,
            spectrum_max_x: f64_at(&bytes, offset + 188)?,
            spectrum_min_y: f64_at(&bytes, offset + 196)?,
            spectrum_max_y: f64_at(&bytes, offset + 204)?,
            spectrum_measured_noise: f64_at(&bytes, offset + 212)?,
            centroid_format_id: if scan_record_size >= 284 {
                u32_at(&bytes, offset + 220)?
            } else {
                0
            },
            centroid_offset: if scan_record_size >= 284 {
                u64::from_le_bytes(bytes[offset + 224..offset + 232].try_into().unwrap())
            } else {
                0
            },
            centroid_byte_count: if scan_record_size >= 284 {
                u32_at(&bytes, offset + 232)?
            } else {
                0
            },
            centroid_point_count: if scan_record_size >= 284 {
                u32_at(&bytes, offset + 236)?
            } else {
                0
            },
            record_index: (offset - SCAN_PREAMBLE_SIZE) / scan_record_size,
            precursor_mz: if scan_record_size >= 284 && u32_at(&bytes, offset + 20)? >= 2 {
                f64_at(&bytes, offset + 84)?
            } else {
                0.0
            },
            collision_energy: if scan_record_size >= 284 && u32_at(&bytes, offset + 20)? >= 2 {
                f64_at(&bytes, offset + 76)?
            } else {
                0.0
            },
        });
    }
    Ok(records)
}

pub fn read_profile_spectrum(
    path: impl AsRef<Path>,
    record: &ScanRecord,
) -> Result<ProfileSpectrum, String> {
    if record.spectrum_format_id != 1 {
        return Err("Agilent scan does not contain a SpectrumFormatID=1 profile block".to_string());
    }
    if record.spectrum_byte_count < PROFILE_BLOCK_PREAMBLE_SIZE as u32 {
        return Err("Agilent profile block is shorter than its preamble".to_string());
    }
    if record.spectrum_point_count == 0 {
        return Ok(ProfileSpectrum {
            mz: Vec::new(),
            intensity: Vec::new(),
        });
    }
    let point_bytes = record.spectrum_point_count as usize * std::mem::size_of::<u32>();
    if (record.spectrum_uncompressed_byte_count as usize) < point_bytes {
        return Err(
            "Agilent profile uncompressed byte count is smaller than its point array".to_string(),
        );
    }

    let profile_path = path.as_ref().join("AcqData/MSProfile.bin");
    let profile_size = fs::metadata(&profile_path)
        .map_err(|error| error.to_string())?
        .len();
    let block_end = record
        .spectrum_offset
        .checked_add(record.spectrum_byte_count as u64)
        .ok_or_else(|| "Agilent profile block offset overflow".to_string())?;
    if block_end > profile_size {
        return Err("Agilent profile block is outside MSProfile.bin".to_string());
    }
    let mut profile_file = fs::File::open(profile_path).map_err(|error| error.to_string())?;
    profile_file
        .seek(SeekFrom::Start(record.spectrum_offset))
        .map_err(|error| error.to_string())?;
    let mut block = vec![0u8; record.spectrum_byte_count as usize];
    profile_file
        .read_exact(&mut block)
        .map_err(|error| error.to_string())?;
    let decoded = decompress_lzf(&block, record.spectrum_uncompressed_byte_count as usize)
        .or_else(|_| {
            decompress_lzf(
                &block[PROFILE_BLOCK_PREAMBLE_SIZE..],
                record.spectrum_uncompressed_byte_count as usize,
            )
        })?;
    let data_offset = if decoded.len() == point_bytes {
        0
    } else {
        PROFILE_BLOCK_PREAMBLE_SIZE
    };
    if decoded.len() < data_offset + point_bytes {
        return Err(
            "Agilent LZF profile block is shorter than its declared point count".to_string(),
        );
    }

    let step = if record.spectrum_point_count > 1 {
        (record.spectrum_max_x - record.spectrum_min_x) / (record.spectrum_point_count as f64 - 1.0)
    } else {
        0.0
    };
    let mut mz = Vec::with_capacity(record.spectrum_point_count as usize);
    let mut intensity = Vec::with_capacity(record.spectrum_point_count as usize);
    for index in 0..record.spectrum_point_count as usize {
        mz.push(record.spectrum_min_x + index as f64 * step);
        intensity.push(u32_at(&decoded, data_offset + index * 4)? as f32);
    }
    Ok(ProfileSpectrum { mz, intensity })
}

pub fn has_centroid(record: &ScanRecord) -> bool {
    if record.centroid_point_count == 0 || record.centroid_byte_count == 0 {
        return false;
    }
    let bytes_per_peak = record.centroid_byte_count / record.centroid_point_count;
    record.centroid_byte_count % record.centroid_point_count == 0
        && matches!(bytes_per_peak, 8 | 12 | 16)
}

fn read_centroid_calibration(
    path: &Path,
    record: &ScanRecord,
) -> Result<Option<([f64; 10], u32)>, String> {
    let mass_path = path.join("AcqData/MSMassCal.bin");
    if !mass_path.is_file() {
        return Ok(None);
    }
    let bytes = fs::read(mass_path).map_err(|error| error.to_string())?;
    let offset = 76usize
        .checked_add(
            record
                .record_index
                .checked_mul(84)
                .ok_or_else(|| "Agilent mass calibration offset overflow".to_string())?,
        )
        .ok_or_else(|| "Agilent mass calibration offset overflow".to_string())?;
    if offset + 80 > bytes.len() {
        return Ok(None);
    }
    let mut values = [0.0; 10];
    for (index, value) in values.iter_mut().enumerate() {
        *value = f64_at(&bytes, offset + index * 8)?;
    }
    let xml = fs::read_to_string(path.join("AcqData/DefaultMassCal.xml")).unwrap_or_default();
    let marker = format!(
        "<DefaultCalibration DefaultCalibrationID=\"{}\">",
        record.calibration_id
    );
    let start = xml.find(&marker).unwrap_or(0);
    let polynomial = xml[start..]
        .find("<CalibrationFormula>Polynomial")
        .map(|offset| start + offset);
    let flags = polynomial
        .and_then(|offset| xml[offset..].find("<ValueUseFlags>"))
        .and_then(|offset| {
            let begin = polynomial.unwrap() + offset + 15;
            xml[begin..]
                .find("</ValueUseFlags>")
                .map(|end| xml[begin..begin + end].trim().parse().unwrap_or(0))
        })
        .unwrap_or(0);
    Ok(Some((values, flags)))
}

pub fn read_centroid_spectrum(
    path: impl AsRef<Path>,
    record: &ScanRecord,
) -> Result<ProfileSpectrum, String> {
    if !has_centroid(record) {
        return Err("Agilent scan does not contain a valid MSPeak.bin centroid block".into());
    }
    let path = path.as_ref();
    let bytes = fs::read(path.join("AcqData/MSPeak.bin")).map_err(|error| error.to_string())?;
    let start = record.centroid_offset as usize;
    let end = start
        .checked_add(record.centroid_byte_count as usize)
        .ok_or_else(|| "Agilent centroid block offset overflow".to_string())?;
    let block = bytes
        .get(start..end)
        .ok_or_else(|| "Agilent MSPeak.bin centroid block is truncated".to_string())?;
    let count = record.centroid_point_count as usize;
    let bytes_per_peak = record.centroid_byte_count as usize / count;
    let calibration = read_centroid_calibration(path, record)?;
    let mut mz = Vec::with_capacity(count);
    let mut intensity = Vec::with_capacity(count);
    for index in 0..count {
        let raw_mz = if bytes_per_peak == 8 {
            f32::from_le_bytes(block[index * 4..index * 4 + 4].try_into().unwrap()) as f64
        } else {
            f64_at(block, index * 8)?
        };
        let intensity_offset = if bytes_per_peak == 8 {
            count * 4 + index * 4
        } else {
            count * 8 + index * if bytes_per_peak == 16 { 8 } else { 4 }
        };
        let raw_intensity = if bytes_per_peak == 16 {
            f64_at(block, intensity_offset)?
        } else {
            f32::from_le_bytes(
                block[intensity_offset..intensity_offset + 4]
                    .try_into()
                    .unwrap(),
            ) as f64
        };
        let calibrated = if let Some((values, flags)) = calibration {
            let tof = raw_mz;
            let mut value = (values[0] * (tof - values[1])).powi(2);
            if flags != 0 {
                let clipped = tof.clamp(values[2], values[3]);
                let mut polynomial = [0.0; 32];
                let mut coefficient = 4;
                let mut highest = 0;
                for order in 0..32 {
                    if flags & (1 << order) != 0 && coefficient < 10 {
                        polynomial[order] = values[coefficient];
                        coefficient += 1;
                        highest = order;
                    }
                }
                let mut correction = 0.0;
                for order in (0..=highest).rev() {
                    correction = correction * clipped + polynomial[order];
                }
                value -= correction;
            }
            value
        } else {
            raw_mz
        };
        mz.push(calibrated);
        intensity.push(raw_intensity as u64 as f32);
    }
    Ok(ProfileSpectrum { mz, intensity })
}

#[derive(Debug)]
struct DadSignal {
    letter: String,
    description: String,
    units: String,
    offset: u32,
    point_count: u32,
}

fn pascal(bytes: &[u8], offset: usize) -> Option<(String, usize)> {
    let length = *bytes.get(offset)? as usize;
    let end = offset.checked_add(1 + length)?;
    Some((
        String::from_utf8_lossy(bytes.get(offset + 1..end)?).into_owned(),
        end,
    ))
}

fn dad_candidate(bytes: &[u8], offset: usize, data_size: u64) -> bool {
    let Some((letter, after_letter)) = pascal(bytes, offset) else {
        return false;
    };
    if letter.chars().count() != 1
        || !letter
            .chars()
            .next()
            .is_some_and(|c| c.is_ascii_alphanumeric())
    {
        return false;
    }
    let Some((description, after_description)) = pascal(bytes, after_letter) else {
        return false;
    };
    if description.is_empty() || after_description + 16 > bytes.len() {
        return false;
    }
    let kind = u32_at(bytes, after_description).unwrap_or(0);
    let offset = u32_at(bytes, after_description + 4).unwrap_or(0);
    let count = u32_at(bytes, after_description + 12).unwrap_or(0);
    (kind == 1 || kind == 2)
        && offset >= 68
        && count > 0
        && offset as u64 + 16 + count as u64 * 8 <= data_size
}

fn read_dad_signals(bytes: &[u8], data_size: u64) -> Vec<DadSignal> {
    if bytes.len() < 80 || u16::from_le_bytes(bytes[0..2].try_into().unwrap()) != 0x0200 {
        return Vec::new();
    }
    let count = u32_at(bytes, 76).unwrap_or(0);
    let mut position = 80usize;
    let mut signals = Vec::new();
    for _ in 0..count {
        let Some((letter, after_letter)) = pascal(bytes, position) else {
            break;
        };
        let Some((description, after_description)) = pascal(bytes, after_letter) else {
            break;
        };
        if after_description + 16 > bytes.len() {
            break;
        }
        let kind = u32_at(bytes, after_description).unwrap_or(0);
        let offset = u32_at(bytes, after_description + 4).unwrap_or(0);
        let point_count = u32_at(bytes, after_description + 12).unwrap_or(0);
        if (kind != 1 && kind != 2)
            || offset < 68
            || point_count == 0
            || offset as u64 + 16 + point_count as u64 * 8 > data_size
        {
            break;
        }
        let fields_end = after_description + 16;
        let mut next = bytes.len();
        for probe in fields_end..bytes.len().saturating_sub(2) {
            if dad_candidate(bytes, probe, data_size) {
                next = probe;
                break;
            }
        }
        let mut units = String::new();
        for probe in fields_end..next {
            if let Some((text, end)) = pascal(bytes, probe) {
                if end <= next
                    && (1..=8).contains(&text.len())
                    && !text.trim().is_empty()
                    && text.bytes().all(|value| value >= 32 && value != 127)
                {
                    units = text.trim().to_string();
                }
            }
        }
        signals.push(DadSignal {
            letter,
            description,
            units,
            offset,
            point_count,
        });
        position = next;
        if position == bytes.len() {
            break;
        }
    }
    signals
}

pub fn read_dad_chromatograms(
    path: impl AsRef<Path>,
) -> Result<Vec<crate::reader::Chromatogram>, String> {
    let acq = path.as_ref().join("AcqData");
    let mut output = Vec::new();
    let mut entries: Vec<_> = fs::read_dir(&acq)
        .map_err(|error| error.to_string())?
        .flatten()
        .collect();
    entries.sort_by_key(|entry| entry.file_name());
    for entry in entries {
        if !entry
            .file_type()
            .map_err(|error| error.to_string())?
            .is_file()
            || entry
                .path()
                .extension()
                .and_then(|value| value.to_str())
                .map(|value| value.to_ascii_lowercase())
                != Some("cd".into())
        {
            continue;
        }
        let mut data_path = entry.path();
        data_path.set_extension("cg");
        if !data_path.is_file() {
            continue;
        }
        let descriptor = fs::read(entry.path()).map_err(|error| error.to_string())?;
        let data = fs::read(&data_path).map_err(|error| error.to_string())?;
        for signal in read_dad_signals(&descriptor, data.len() as u64) {
            let start = signal.offset as usize;
            let count = signal.point_count as usize;
            if start + 16 + count * 8 > data.len() {
                continue;
            }
            let first_time = f64_at(&data, start)?;
            let interval = f64_at(&data, start + 8)?;
            let absorbance = signal.units == "mAU" || signal.description.contains("Sig=");
            output.push(crate::reader::Chromatogram {
                id: format!(
                    "{}{}",
                    entry
                        .path()
                        .file_stem()
                        .unwrap_or_default()
                        .to_string_lossy(),
                    signal.letter
                ),
                signal_type: if absorbance { "UV" } else { "AUX" }.into(),
                chromatogram_type: if absorbance { "DAD" } else { "AUX" }.into(),
                detector: entry
                    .path()
                    .file_stem()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .into_owned(),
                channel: signal.letter,
                units: signal.units,
                wavelength_nm: signal
                    .description
                    .split_once("Sig=")
                    .and_then(|(_, value)| value.trim().parse().ok())
                    .unwrap_or(0.0),
                polarity: 0,
                interval_ms: (interval * 60000.0) as f32,
                time: (0..count)
                    .map(|index| (first_time + index as f64 * interval) as f32)
                    .collect(),
                intensity: (0..count)
                    .map(|index| f64_at(&data, start + 16 + index * 8).unwrap_or(0.0) as f32)
                    .collect(),
                start_time: Some(first_time as f32),
                end_time: Some((first_time + (count.saturating_sub(1)) as f64 * interval) as f32),
                ..Default::default()
            });
        }
    }
    Ok(output)
}
