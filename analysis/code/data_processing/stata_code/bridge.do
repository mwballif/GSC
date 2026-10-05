import excel "../data/PCEBridge_Summary.xlsx", sheet("1997") cellrange(A5) firstrow clear

tempfile combined
save `combined'

forvalues y = 1998/2024 {
    import excel "../data/PCEBridge_Summary.xlsx", sheet("`y'") cellrange(A5) firstrow clear
    append using `combined'
    save `combined', replace
}

use `combined', clear

rename E producer_val
rename F trans_cost
rename I purchase_val
rename Year year

drop if inlist(CommodityCode, "Used", "Noncomp")
drop if strpos(PCECategory, "Less:") == 1
drop if producer_val <= 0 | purchase_val <= 0

drop if purchase_val == producer_val
gen markup = log(purchase_val/ producer_val)

egen id = group(PCECategory CommodityCode)

keep NIPALine  PCECategory  CommodityCode  producer_val  trans_cost  Wholesale  Retail  purchase_val year year markup id

sort id year



twoway line markup year, connect(ascending) ///
    lcolor(navy%15) lwidth(vthin)
	


