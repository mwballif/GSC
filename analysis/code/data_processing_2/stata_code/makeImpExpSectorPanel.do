*==============================================================================
* makeImpExpSectorPanel.do
*
* Purpose: Splice the bilateral trade matrix at 2000 and write its totals.
* Reads:   $GSC_INTER/panel_C.dta, the country crosswalk
* Writes:  ImpExpSectorPanel.csv, ImpExpSectorPanel_2country.csv,
*          $GSC_INTER/bilateral_totals.dta
*
/* NOTE: runs first. Every trade quantity is read off this one spliced matrix. */
*==============================================================================

do "0_setup.do"

*--- PART 1: splice the bilateral flows and import shares ----------------------

use "$GSC_INTER/panel_C.dta", clear

* Compute WIOD growth rates.
/* NOTE: source must be in the sort, or the 2000 rows tie. */
local vars "imp_sh trade_flow"
sort exporter importer sector year source
foreach var of local vars {
    by exporter importer sector: gen `var'_gr = `var'/`var'[_n-1] if source == 1 & year != 2000
}

* Start the spliced series at the Long Run levels.
foreach var of local vars {
    gen `var'_spliced = `var' if source == 0
}

* Keep the Long Run version of the 2000 splice point.
drop if year == 2000 & source == 1

* Extend forward using the WIOD growth rates.
sort exporter importer sector year
foreach var of local vars {
    bysort exporter importer sector (year): replace `var'_spliced = `var'_spliced[_n-1] * `var'_gr if source == 1
}

foreach var of local vars {
    replace `var' = `var'_spliced
}

* Attach country names to the exporter and importer codes.
rename exporter exporter_numcode
rename importer importer_numcode

merge m:1 exporter_numcode using "$GSC_INTER/country_num_crosswalk.dta", keepusing(country) nogen
rename country exporter

merge m:1 importer_numcode using "$GSC_INTER/country_num_crosswalk.dta", keepusing(country) nogen
rename country importer
drop importer_numcode exporter_numcode

* Label the three sectors.
rename sector sector_num
gen sector = "AGR" if sector_num == 1
replace sector = "MAN" if sector_num == 2
replace sector = "SER" if sector_num == 3

sort importer exporter sector year
keep exporter importer year sector `vars'

export delimited "$GSC_PROC/ImpExpSectorPanel.csv", replace

*--- PART 1b: row and column totals of the spliced matrix ----------------------
*
* go_mat   gross output = flows FROM this region, summed over importers
* exp_mat  total expend = flows TO   this region, summed over exporters
* xp_mat   exports      = go_mat  minus the own (diagonal) flow
* mp_mat   imports      = exp_mat minus the own (diagonal) flow
* nx_mat   net exports  = xp_mat - mp_mat, identically go_mat - exp_mat
*
/* NOTE: derived from one matrix, so world net exports sum to zero exactly. */

tempfile bilat marg_out

preserve

* Isolate the diagonal so exports and imports can net it out.
gen double own = trade_flow if exporter == importer
save `bilat'

* Gross output and exports, by producing region.
collapse (sum) go_mat = trade_flow own_o = own, by(exporter sector year)
rename exporter country
gen double xp_mat = go_mat - own_o
drop own_o
save `marg_out'

* Total expenditure and imports, by buying region.
use `bilat', clear
collapse (sum) exp_mat = trade_flow own_i = own, by(importer sector year)
rename importer country
gen double mp_mat = exp_mat - own_i
drop own_i

* Combine the two sides and form net exports.
merge 1:1 country sector year using `marg_out', nogen
gen double nx_mat = xp_mat - mp_mat

label var go_mat  "gross output, row sum of the spliced bilateral matrix"
label var exp_mat "total expenditure, column sum of the spliced bilateral matrix"
label var xp_mat  "exports, off-diagonal row sum"
label var mp_mat  "imports, off-diagonal column sum"
label var nx_mat  "net exports, xp_mat - mp_mat"

sort country sector year
save "$GSC_INTER/bilateral_totals.dta", replace

restore

*--- PART 2: USA vs ROW two country aggregation --------------------------------
*
/* NOTE: intra-ROW trade becomes domestic in the ROW-to-ROW cell. */

gen byte exp_usa = exporter == "USA"
gen byte imp_usa = importer == "USA"

collapse (sum) trade_flow, by(sector year exp_usa imp_usa)

gen exporter = cond(exp_usa, "USA", "ROW")
gen importer = cond(imp_usa, "USA", "ROW")
drop exp_usa imp_usa

* Import shares: the importer's spending by origin, summing to one over origins.
bysort importer sector year: egen total_spend = total(trade_flow)
gen imp_sh = trade_flow / total_spend
drop total_spend

* Export shares: the exporter's sales by destination.
bysort exporter sector year: egen total_sales = total(trade_flow)
gen exp_sh = trade_flow / total_sales
drop total_sales

order exporter importer sector year imp_sh exp_sh trade_flow
sort exporter importer sector year

export delimited "$GSC_PROC/ImpExpSectorPanel_2country.csv", replace
