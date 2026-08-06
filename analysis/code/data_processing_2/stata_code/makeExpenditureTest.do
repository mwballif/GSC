*==============================================================================
* makeExpenditureTest.do
*
* Purpose: Build expenditure, import and export aggregates from the bilateral
*          panel, as a cross-check on the country-sector panel.
* Reads:   $GSC_PROC/ImpExpSectorPanel.csv
* Writes:  $GSC_INTER/expenditure_test.dta
*
/* NOTE: diagnostic only, not called by run.do. */
*==============================================================================

do "0_setup.do"

* From the bilateral trade flow data, for country i and sector j:
*   expenditure(i,j) = sum over h            of trade_flow(h -> i, j)
*   imports(i,j)     = sum over h != i       of trade_flow(h -> i, j)
*   exports(i,j)     = sum over h != i       of trade_flow(i -> h, j)

import delimited "$GSC_PROC/ImpExpSectorPanel.csv", clear

preserve
collapse (sum) expenditure = trade_flow, by(importer sector year)
rename importer country
tempfile expenditure_tot
save `expenditure_tot'
restore

preserve
drop if exporter == importer
collapse (sum) imports = trade_flow, by(importer sector year)
rename importer country
tempfile imports_tot
save `imports_tot'
restore

preserve
drop if exporter == importer
collapse (sum) exports = trade_flow, by(exporter sector year)
rename exporter country
tempfile exports_tot
save `exports_tot'
restore

use `expenditure_tot', clear
merge 1:1 country sector year using `imports_tot', nogen
merge 1:1 country sector year using `exports_tot', nogen

save "$GSC_INTER/expenditure_test.dta", replace

* EOF
