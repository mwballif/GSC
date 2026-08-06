*==============================================================================
* 1_process_raw_data.do
*
* Purpose: Convert the raw spreadsheets and MATLAB panels into .dta files.
* Reads:   the raw xlsx workbooks, panel_A-C.csv, the country crosswalk
* Writes:  dta copies of all of them, in $GSC_INTER
*
/* NOTE: skipping this leaves panel_A.dta stale and every panel wrong. */
/* NOTE: unlike the baseline, the crosswalk .dta is written to this arm's  */
/* intermediate folder rather than data/crosswalks/, so nothing here writes */
/* outside $GSC_PROC. The .csv it comes from is shared and unmodified.      */
*==============================================================================

do "0_setup.do"

* Long Run WIOD socio-economic accounts.
import excel using "$GSC_RAW/lr_wiod_sea_final.xlsx", sheet("data") firstrow clear
compress
save "$GSC_INTER/lr_wiod_sea_final.dta", replace

* WIOD 2016 socio-economic accounts.
import excel using "$GSC_RAW/Socio_economic_Accounts.xlsx", sheet("DATA") firstrow clear
compress
save "$GSC_INTER/Socio_economic_Accounts.dta", replace

* GGDC Productivity Level Database, for the 2005 gross-output PPPs.
import excel using "$GSC_RAW/pld2023_dataset.xlsx", sheet("Data") firstrow clear
compress
save "$GSC_INTER/pld2023_dataset.dta", replace

* Penn World Table.
import excel using "$GSC_RAW/pwt110.xlsx", sheet("Data") firstrow clear
save "$GSC_INTER/pwt110.dta", replace

* Country aggregates from the MATLAB extractors.
capture confirm file "$GSC_PROC/panel_A.csv"
if _rc {
    di as error "panel_A.csv not found in $GSC_PROC."
    di as error "Run the MATLAB extractors first: cd ../matlab; process_raw_data; createpanels"
    exit 601
}
import delimited "$GSC_PROC/panel_A.csv", clear
save "$GSC_INTER/panel_A.dta", replace

* Country-sector quantities.
import delimited "$GSC_PROC/panel_B.csv", clear
save "$GSC_INTER/panel_B.dta", replace

* Bilateral trade flows.
import delimited "$GSC_PROC/panel_C.csv", clear
save "$GSC_INTER/panel_C.dta", replace

* Country name to number crosswalk.
*
/* NOTE: panel_D.csv is not converted. Nothing in the Stata half reads it; */
/* recover_parameters.m reads the csv directly.                            */
import delimited "$GSC_CROSS/country_num_crosswalk.csv", clear
save "$GSC_INTER/country_num_crosswalk.dta", replace
