*==============================================================================
* makecountrypanel.do
*
* Purpose: Build the country-level panel, 1965-2014, for 25 regions and for the
*          two-country USA/ROW system.
* Reads:   $GSC_INTER/panel_A.dta, pwt110.dta, bilateral_totals.dta
* Writes:  CountryPanel.csv, CountryPanel_2country.csv
*
/* NOTE: makeImpExpSectorPanel.do must run first; this reads its totals. */
*==============================================================================

do "0_setup.do"

*--- PART 1: Penn World Table variables ----------------------------------------

use "$GSC_INTER/pwt110.dta", clear
keep countrycode year emp pop rnna cn pl_c pl_i xr cgdpo
rename countrycode country
rename rnna k_stock
rename pl_c consump_pi
rename pl_i invest_pi
drop if year < 1965 | year > 2014

* Split PWT into the WIOD countries and everything else.
merge m:1 country using "$GSC_INTER/country_num_crosswalk.dta", keep(1 3)

* Build the residual region from the non-WIOD countries: sum the quantities and
* take GDP-weighted geometric means of the price levels.
*
/* NOTE: the residual region's capital jumps 137% in 1990. See the appendix. */
preserve
keep if _merge == 1
bysort year: egen totw_c = total(cond(!missing(consump_pi), cgdpo, .))
bysort year: egen totw_i = total(cond(!missing(invest_pi),  cgdpo, .))
gen wln_consump_pi = cgdpo / totw_c * ln(consump_pi)
gen wln_invest_pi  = cgdpo / totw_i * ln(invest_pi)

collapse (sum) emp pop k_stock cn wln_*, by(year)

gen consump_pi = exp(wln_consump_pi)
gen invest_pi  = exp(wln_invest_pi)
drop wln_*
gen country = "ROW"
tempfile penn_row
save `penn_row'
restore

* Keep the WIOD countries and append the residual region.
keep if _merge == 3
drop _merge country_numcode exporter_numcode importer_numcode cgdpo
append using `penn_row'
tempfile penn
save `penn'

*--- PART 2: splice the country aggregates -------------------------------------

use "$GSC_INTER/panel_A.dta", clear
rename country country_numcode

merge m:1 country_numcode using "$GSC_INTER/country_num_crosswalk.dta", nogen
sort country year

* Chain-link GDP, consumption and investment at 2000.
*
/* NOTE: tot_exp and tot_imp are not spliced here; they come from the matrix. */
local vars "gdp tot_consump tot_invest"
sort country year source
foreach var of local vars {
    bysort country (year): gen `var'_gr = `var'/`var'[_n-1] if source == 1 & year != 2000
}

* Start the spliced series at the Long Run levels.
foreach var of local vars {
    gen `var'_spliced = `var' if source == 0
}

* Keep the Long Run version of the 2000 splice point.
drop if year == 2000 & source == 1

* Extend forward using the WIOD growth rates.
sort country year
foreach var of local vars {
    bysort country (year): replace `var'_spliced = `var'_spliced[_n-1] * `var'_gr if source == 1
}

foreach var of local vars {
    replace `var' = `var'_spliced
}

* Take exports and imports from the spliced bilateral matrix, summed over
* sectors, and form net exports from them.
drop tot_exp tot_imp
preserve
use "$GSC_INTER/bilateral_totals.dta", clear
collapse (sum) tot_exp = xp_mat tot_imp = mp_mat, by(country year)
tempfile trade_marg
save `trade_marg'
restore

merge 1:1 country year using `trade_marg', nogen
gen tot_nx = tot_exp - tot_imp

keep country country_numcode year gdp tot_consump tot_invest tot_exp tot_imp tot_nx

* Merge in the Penn World Table variables.
merge 1:1 country year using `penn', keep(1 3) nogen
drop country_numcode
export delimited "$GSC_PROC/CountryPanel.csv", replace

*--- PART 3: USA vs ROW two country aggregation --------------------------------

preserve
keep if country == "USA"
tempfile usa_country
save `usa_country'
restore

drop if country == "USA"

* Sum the quantities over every non-US region.
*
/* NOTE: summed tot_exp and tot_imp still include intra-ROW trade. tot_nx is fine. */
local vars_sum "gdp tot_consump tot_invest tot_exp tot_imp emp pop k_stock cn"

* Prices are GDP-weighted geometric means over the countries that have one.
bysort year: egen totw_c = total(cond(!missing(consump_pi), gdp, .))
bysort year: egen totw_i = total(cond(!missing(invest_pi),  gdp, .))
gen wln_consump_pi = gdp / totw_c * ln(consump_pi)
gen wln_invest_pi  = gdp / totw_i  * ln(invest_pi)

collapse (sum) `vars_sum' wln_*, by(year)

gen consump_pi = exp(wln_consump_pi)
gen invest_pi  = exp(wln_invest_pi)
drop wln_*

gen tot_nx = tot_exp - tot_imp
gen country = "ROW"

append using `usa_country'

* Check world adding up. In a two-country world one country's surplus is the
* other's deficit, so this must be zero. Anything listed is a bug.
preserve
keep country year tot_nx
reshape wide tot_nx, i(year) j(country) string
gen world_imbalance = tot_nxUSA + tot_nxROW
list year world_imbalance if abs(world_imbalance) > 100
restore

keep country year gdp tot_consump tot_invest tot_exp tot_imp tot_nx emp pop k_stock consump_pi invest_pi
order country year gdp tot_consump tot_invest tot_exp tot_imp tot_nx emp pop k_stock consump_pi invest_pi
sort country year

export delimited "$GSC_PROC/CountryPanel_2country.csv", replace
