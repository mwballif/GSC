*==============================================================================
* run.do
*
* Purpose: Run the Stata half of the pipeline in order.
* Reads:   data/processed/panel_A-D.csv, the raw xlsx workbooks
* Writes:  the six panels in data/processed/
*
/* NOTE: order matters. The bilateral matrix is spliced first. */
/* NOTE: a slash then a star in a comment comments out the rest of the file. */
*==============================================================================

* Import the raw spreadsheets and panels as .dta files.
do "1_process_raw_data.do"

* Splice the bilateral matrix and write its row and column totals.
do "makeImpExpSectorPanel.do"

* Build the country panel.
do "makecountrypanel.do"

* Build the country-sector panel.
do "MakeCountrySectorPanel.do"
