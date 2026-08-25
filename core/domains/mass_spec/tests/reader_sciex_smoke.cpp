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
        if (catalog.size() != 37 || catalog[3].name != "0.009" || catalog[9].name != "0.9" || catalog[28].name != "0.9") return 4;
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
        const auto traces = mass_spec::reader::sciex::decode_tic_bpc(blocks[3]);
        if (traces.tic.size() != 3421 || traces.bpc.size() != traces.tic.size()) return 13;
        if (traces.tic[0] != 0.0f || traces.tic[1] != 4642.0f || traces.tic[2] != 3583.0f) return 14;

        mass_spec::reader::MASS_SPEC_FILE reader(file);
        if (reader.get_format() != "SciexWIFF") return 13;
        if (reader.get_number_chromatograms() != 62) return 14;

        const auto headers = reader.get_chromatograms_headers({0, 1});
        if (headers.size() != 2) return 15;
        if (headers.chromatogram_id[0] != "TIC" || headers.chromatogram_id[1] != "BPC") return 16;
        if (headers.array_length[0] == 0 || headers.array_length[1] == 0) return 17;
    } catch (const std::exception &error) {
        std::cerr << error.what() << "\n";
        return 10;
    }
}
