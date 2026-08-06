*==============================================================================
* run.do
*
* Purpose: Run the Stata half of data_processing_2 in order.
* Reads:   $GSC_PROC/panel_A-C.csv, the raw xlsx workbooks
* Writes:  the six panels in $GSC_PROC
*
* The MATLAB extractors must have produced panel_A-panel_D first:
*   cd ../matlab && matlab -batch process_raw_data && matlab -batch createpanels
*
* Headless, from stata_code/:
*   printf 'do "run.do"\nexit, clear STATA\n' > _batch.do
*   /Applications/StataNow/StataBE.app/Contents/MacOS/StataBE -b do _batch.do
* The .app binary does not exit on its own, hence the wrapper.
*
/* NOTE: order matters. The bilateral matrix is spliced first, because both */
/* panel builders read their trade quantities off its totals.               */
/* NOTE: a slash then a star in a comment comments out the rest of the file. */
*==============================================================================

* Paths and the experiment's sector definition.
do "0_setup.do"

* Import the raw spreadsheets and panels as .dta files.
do "1_process_raw_data.do"

* Splice the bilateral matrix and write its row and column totals.
do "makeImpExpSectorPanel.do"

* Build the country panel.
do "makecountrypanel.do"

* Build the country-sector panel.
do "MakeCountrySectorPanel.do"

di as txt "run.do complete. Now: cd ../matlab && matlab -batch recover_parameters"
