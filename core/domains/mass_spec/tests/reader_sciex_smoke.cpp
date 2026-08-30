#include <cmath>
#include <iostream>
#include <stdexcept>

#include "streamfind/mass_spec/reader.hpp"
#include "streamfind/mass_spec/reader_sciex.hpp"

#ifndef STREAMFIND_SCIEX_WIFF_FIXTURE
#error STREAMFIND_SCIEX_WIFF_FIXTURE is required
#endif

int main() {
    try {
        const std::string file = STREAMFIND_SCIEX_WIFF_FIXTURE;
        if (mass_spec::reader::detect_format(file) != "SciexWIFF") return 1;

        const auto blocks = mass_spec::reader::sciex::read_scan_blocks(file);
        if (blocks.size() != 37) return 2;
        if (blocks[3].sample_number != 4 || blocks[3].bytes.empty()) return 3;
        const auto catalog = mass_spec::reader::sciex::read_analysis_catalog(file);
        if (catalog.size() != 37 || catalog[3].analysis_index != 3 || catalog[3].source_analysis_number != 4 || catalog[3].analysis_count != 37) return 4;
        const auto transitions = mass_spec::reader::sciex::read_transitions(file);
        if (transitions.size() != 59) return 5;
        if (transitions[0].name != "1H-Benzotriazol_1" || transitions[0].precursor_mz != 120.109f || transitions[0].product_mz != 65.2f) return 6;
        const auto scheduled = mass_spec::reader::sciex::read_transitions(file, 4);
        if (scheduled.size() != 59 || std::fabs(scheduled[0].start_time - 1.54082f) > 0.0001f || std::fabs(scheduled[0].end_time - 2.54402f) > 0.0001f || std::fabs(scheduled[0].collision_energy - 31.0f) > 0.001f) return 7;
        const auto events = mass_spec::reader::sciex::read_event_records(blocks[3]);
        if (events.size() != 3427 || events[2].fields.size() != 3) return 8;
        if (events[2].fields[0] != -38.01f || events[2].fields[1] != 4642.0f || events[2].fields[2] != -20.01f) return 9;
        if (events[149].fields.size() != 7 || events[149].fields[0] != -22.01f || events[149].fields[3] != -14.01f) return 10;
        const auto groups = mass_spec::reader::sciex::decode_intensity_groups(events[149]);
        if (groups.size() != 2 || groups[0].field_code != -22 || groups[1].field_code != -14) return 11;
        if (groups[0].intensities != std::vector<float>{68.0f, 1155.0f} || groups[1].intensities != std::vector<float>{3245.0f, 113.0f}) return 12;
        const auto fragments = mass_spec::reader::sciex::read_idx_float_records(file, 4);
        if (std::fabs(fragments[0].index.retention_time_minutes - 0.7005f) > 0.00001f) return 13;
        const auto idx = mass_spec::reader::sciex::read_idx_records(file, 4);
        if (idx.size() != 3421 || std::fabs(idx[0].retention_time_minutes - 0.7005f) > 0.00001f) return 14;
        const auto sparse = mass_spec::reader::sciex::read_sparse_tagged_mrm_series(file, 4, -59.01f, 59);
        if (sparse.intensities.size() != 59 || sparse.intensities[38].size() != 3421 || std::fabs(sparse.retention_times[38][8] - 0.708483f) > 0.00001f) return 15;
        if (sparse.intensities[38][8] != 3943.0f || sparse.intensities[39][8] != 203.0f) return 16;

        mass_spec::reader::MASS_SPEC_FILE reader(file);
        if (reader.get_format() != "SciexWIFF") return 17;
        if (reader.get_number_chromatograms() != 61) return 18;

        const auto headers = reader.get_chromatograms_headers();
        if (headers.size() != 61) return 15;
        if (headers.chromatogram_id[0] != "TIC" || headers.chromatogram_id[1] != "BPC") return 16;
        if (headers.array_length[0] != -1 || headers.array_length[1] != -1 || headers.array_length[40] != -1) return 17;
        const auto initial = reader.get_chromatograms({0, 1, 40, 41});
        if (initial.size() != 4 || initial[0][1].empty() || initial[2][1].size() != 392) return 18;
        reader.select_analysis(3);
        const auto selected = reader.get_chromatograms();
        if (selected.size() != 61 || selected[0][1][9] != 4822.0f || selected[1][1][9] != 4574.0f || selected[40][1].size() != 392 || selected[41][1].size() != 392 || std::fabs(selected[40][0][0] - 0.708483f) > 0.00001f || selected[40][1][0] != 3943.0f || selected[41][1][0] != 203.0f) return 18;
        const auto selected_headers = reader.get_chromatograms_headers({40});
        if (selected_headers.size() != 1 || !std::isfinite(selected_headers.start_time[0]) || !std::isfinite(selected_headers.end_time[0]) || std::fabs(selected_headers.start_time[0] - scheduled[38].start_time) > 0.00001f || std::fabs(selected_headers.end_time[0] - scheduled[38].end_time) > 0.00001f) return 19;
        reader.select_analysis(0);
        const auto restored = reader.get_chromatograms();
        if (restored.size() != 61 || restored[0][1][9] != initial[0][1][9]) return 20;
    } catch (const std::exception &error) {
        std::cerr << error.what() << "\n";
        return 10;
    }
}
