*==============================================================================
* 1_process_raw_data.do
*
* Purpose: Convert the raw spreadsheets and MATLAB panels into .dta files.
* Reads:   the raw xlsx workbooks, panel_A-C.csv, the country crosswalk
* Writes:  dta copies of all of them, in processed/intermediate and crosswalks
*
/* NOTE: skipping this leaves panel_A.dta stale and every panel wrong. */
*==============================================================================

* Long Run WIOD socio-economic accounts.
import excel using "../../../data/raw/lr_wiod_sea_final.xlsx", sheet("data") firstrow clear
compress
save "../../../data/processed/intermediate/lr_wiod_sea_final.dta", replace

* WIOD 2016 socio-economic accounts.
import excel using "../../../data/raw/Socio_economic_Accounts.xlsx", sheet("DATA") firstrow clear
compress
save "../../../data/processed/intermediate/Socio_economic_Accounts.dta", replace

* GGDC Productivity Level Database, for the 2005 gross-output PPPs.
import excel using "../../../data/raw/pld2023_dataset.xlsx", sheet("Data") firstrow clear
compress
save "../../../data/processed/intermediate/pld2023_dataset.dta", replace

* Penn World Table.
import excel using "../../../data/raw/pwt110.xlsx", sheet("Data") firstrow clear
save "../../../data/processed/intermediate/pwt110.dta", replace

* Country aggregates from the MATLAB extractors.
import delimited "../../../data/processed/panel_A.csv", clear
save "../../../data/processed/intermediate/panel_A.dta", replace

* Country-sector quantities.
import delimited "../../../data/processed/panel_B.csv", clear
save "../../../data/processed/intermediate/panel_B.dta", replace

* Bilateral trade flows.
import delimited "../../../data/processed/panel_C.csv", clear
save "../../../data/processed/intermediate/panel_C.dta", replace

* Country name to number crosswalk.
import delimited "../../../data/crosswalks/country_num_crosswalk.csv", clear
save "../../../data/crosswalks/country_num_crosswalk.dta", replace
